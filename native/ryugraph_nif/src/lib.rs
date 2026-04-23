use parking_lot::Mutex;
use rustler::{Encoder, Env, Error, NifResult, OwnedBinary, ResourceArc, Term};
use ryugraph::{Connection, Database, SystemConfig, Value};
use std::sync::Arc;
use thiserror::Error;

mod atoms {
    rustler::atoms! {
        ok,
        error,
        nil,
        true_ = "true",
        false_ = "false",

        // Error types
        database_error,
        connection_error,
        query_error,
        type_conversion_error,

        // Graph types
        node,
        rel,
        recursive_rel,

        // Node/Rel fields
        id,
        label,
        properties,
        src,
        dst,
        nodes,
        rels,
    }
}

#[derive(Error, Debug)]
pub enum RyugraphError {
    #[error("Database error: {0}")]
    Database(String),

    #[error("Connection error: {0}")]
    Connection(String),

    #[error("Query error: {0}")]
    Query(String),

    #[error("Type conversion error: {0}")]
    TypeConversion(String),
}

impl Encoder for RyugraphError {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let error_atom = match self {
            RyugraphError::Database(_) => atoms::database_error(),
            RyugraphError::Connection(_) => atoms::connection_error(),
            RyugraphError::Query(_) => atoms::query_error(),
            RyugraphError::TypeConversion(_) => atoms::type_conversion_error(),
        };
        (error_atom, self.to_string()).encode(env)
    }
}

// Resource wrapper for Database
struct DatabaseResource {
    db: Arc<Mutex<Database>>,
}

// Resource wrapper for Connection
struct ConnectionResource {
    conn: Arc<Mutex<Connection<'static>>>,
}

// Simple wrapper for prepared statement ID - we'll manage statements differently
struct PreparedStatementResource {
    id: Arc<Mutex<u64>>,
}

// Helper function to convert SystemConfig from Elixir keyword list
fn parse_system_config(config_term: Term) -> NifResult<SystemConfig> {
    let mut config = SystemConfig::default();

    if let Ok(opts) = config_term.decode::<Vec<(String, Term)>>() {
        for (key, value) in opts {
            match key.as_str() {
                "buffer_pool_size" => {
                    if let Ok(size) = value.decode::<u64>() {
                        config = config.buffer_pool_size(size);
                    }
                }
                "max_num_threads" => {
                    if let Ok(threads) = value.decode::<u64>() {
                        config = config.max_num_threads(threads);
                    }
                }
                "enable_compression" => {
                    if let Ok(enabled) = value.decode::<bool>() {
                        config = config.enable_compression(enabled);
                    }
                }
                "read_only" => {
                    if let Ok(read_only) = value.decode::<bool>() {
                        config = config.read_only(read_only);
                    }
                }
                "max_db_size" => {
                    if let Ok(size) = value.decode::<u64>() {
                        config = config.max_db_size(size);
                    }
                }
                _ => {} // Ignore unknown options
            }
        }
    }

    Ok(config)
}

// Convert Rust Value to Elixir Term
fn value_to_term<'a>(env: Env<'a>, value: &Value) -> NifResult<Term<'a>> {
    match value {
        Value::Null(_) => Ok(atoms::nil().encode(env)),
        Value::Bool(b) => Ok(b.encode(env)),
        Value::Int8(i) => Ok((*i as i64).encode(env)),
        Value::Int16(i) => Ok((*i as i64).encode(env)),
        Value::Int32(i) => Ok((*i as i64).encode(env)),
        Value::Int64(i) => Ok(i.encode(env)),
        Value::UInt8(i) => Ok((*i as u64).encode(env)),
        Value::UInt16(i) => Ok((*i as u64).encode(env)),
        Value::UInt32(i) => Ok((*i as u64).encode(env)),
        Value::UInt64(i) => Ok(i.encode(env)),
        Value::Int128(i) => Ok(i.to_string().encode(env)),
        Value::Float(f) => Ok(f.encode(env)),
        Value::Double(d) => Ok(d.encode(env)),
        Value::String(s) => Ok(s.encode(env)),
        Value::Blob(data) => {
            let mut owned = OwnedBinary::new(data.len()).unwrap();
            owned.as_mut_slice().copy_from_slice(&data);
            Ok(owned.release(env).encode(env))
        }
        Value::Date(d) => Ok(d.to_string().encode(env)),
        Value::Timestamp(t) => Ok(t.to_string().encode(env)),
        Value::TimestampTz(t) => Ok(t.to_string().encode(env)),
        Value::TimestampNs(t) => Ok(t.to_string().encode(env)),
        Value::TimestampMs(t) => Ok(t.to_string().encode(env)),
        Value::TimestampSec(t) => Ok(t.to_string().encode(env)),
        Value::Interval(i) => Ok(i.to_string().encode(env)),
        Value::UUID(u) => Ok(u.to_string().encode(env)),
        Value::List(_, items) => {
            let mut elixir_list = Vec::new();
            for item in items {
                elixir_list.push(value_to_term(env, item)?);
            }
            Ok(elixir_list.encode(env))
        }
        Value::Array(_, items) => {
            let mut elixir_list = Vec::new();
            for item in items {
                elixir_list.push(value_to_term(env, item)?);
            }
            Ok(elixir_list.encode(env))
        }
        Value::Map(_, map) => {
            let mut elixir_map = Vec::new();
            for (k, v) in map {
                elixir_map.push((value_to_term(env, k)?, value_to_term(env, v)?));
            }
            Ok(elixir_map.encode(env))
        }
        Value::Struct(fields) => {
            let mut elixir_map = Vec::new();
            for (name, value) in fields {
                elixir_map.push((name.encode(env), value_to_term(env, value)?));
            }
            Ok(elixir_map.encode(env))
        }
        Value::Node(node) => {
            // Convert InternalID to string
            let id_term = node.get_node_id().to_string().encode(env);
            let label_term = node.get_label_name().encode(env);
            let props = node.get_properties();
            let mut prop_list = Vec::new();
            for (k, v) in props {
                prop_list.push((k.encode(env), value_to_term(env, &v)?));
            }

            // Create a map using tuples
            let map_entries = vec![
                (atoms::node().encode(env), atoms::true_().encode(env)),
                (atoms::id().encode(env), id_term),
                (atoms::label().encode(env), label_term),
                (atoms::properties().encode(env), prop_list.encode(env)),
            ];
            Ok(map_entries.encode(env))
        }
        Value::Rel(rel) => {
            // RelVal might not have get_id, let's use what's available
            let label_term = rel.get_label_name().encode(env);
            // Convert InternalIDs to strings
            let src_term = rel.get_src_node().to_string().encode(env);
            let dst_term = rel.get_dst_node().to_string().encode(env);
            let props = rel.get_properties();
            let mut prop_list = Vec::new();
            for (k, v) in props {
                prop_list.push((k.encode(env), value_to_term(env, &v)?));
            }

            let map_entries = vec![
                (atoms::rel().encode(env), atoms::true_().encode(env)),
                (atoms::label().encode(env), label_term),
                (atoms::src().encode(env), src_term),
                (atoms::dst().encode(env), dst_term),
                (atoms::properties().encode(env), prop_list.encode(env)),
            ];
            Ok(map_entries.encode(env))
        }
        Value::RecursiveRel { nodes, rels } => {
            let nodes_list: Vec<Term> = nodes
                .iter()
                .map(|n| {
                    // Wrap NodeVal in Value::Node
                    value_to_term(env, &Value::Node(n.clone()))
                })
                .collect::<NifResult<Vec<_>>>()?;
            let rels_list: Vec<Term> = rels
                .iter()
                .map(|r| {
                    // Wrap RelVal in Value::Rel
                    value_to_term(env, &Value::Rel(r.clone()))
                })
                .collect::<NifResult<Vec<_>>>()?;

            let map_entries = vec![
                (atoms::recursive_rel().encode(env), atoms::true_().encode(env)),
                (atoms::nodes().encode(env), nodes_list.encode(env)),
                (atoms::rels().encode(env), rels_list.encode(env)),
            ];
            Ok(map_entries.encode(env))
        }
        Value::InternalID(id) => Ok(id.to_string().encode(env)),
        Value::Decimal(d) => Ok(d.to_string().encode(env)),
        Value::Union { types: _, value } => {
            // Just encode the inner value for now
            value_to_term(env, value)
        }
    }
}

// NIF Functions

#[rustler::nif]
fn open_database<'a>(env: Env<'a>, path: String, config: Term<'a>) -> NifResult<Term<'a>> {
    let system_config = parse_system_config(config)?;

    match Database::new(&path, system_config) {
        Ok(db) => {
            let resource = ResourceArc::new(DatabaseResource {
                db: Arc::new(Mutex::new(db)),
            });
            Ok((atoms::ok(), resource).encode(env))
        }
        Err(e) => Ok((atoms::error(), e.to_string()).encode(env)),
    }
}

#[rustler::nif]
fn in_memory_database<'a>(env: Env<'a>, config: Term<'a>) -> NifResult<Term<'a>> {
    let system_config = parse_system_config(config)?;

    match Database::new(":memory:", system_config) {
        Ok(db) => {
            let resource = ResourceArc::new(DatabaseResource {
                db: Arc::new(Mutex::new(db)),
            });
            Ok((atoms::ok(), resource).encode(env))
        }
        Err(e) => Ok((atoms::error(), e.to_string()).encode(env)),
    }
}

#[rustler::nif]
fn new_connection<'a>(
    env: Env<'a>,
    _database: ResourceArc<DatabaseResource>,
) -> NifResult<Term<'a>> {
    // This is a simplified version - in production, we'd need to handle the lifetime more carefully
    // One approach is to store the Database in a global registry with proper lifetime management
    Err(Error::Term(Box::new(
        "Connection creation needs lifetime management implementation",
    )))
}

#[rustler::nif]
fn query<'a>(
    env: Env<'a>,
    _connection: ResourceArc<ConnectionResource>,
    _query_str: String,
) -> NifResult<Term<'a>> {
    // Simplified query implementation
    Err(Error::Term(Box::new("Query execution not yet implemented")))
}

#[rustler::nif]
fn prepare<'a>(
    env: Env<'a>,
    _connection: ResourceArc<ConnectionResource>,
    _query_str: String,
) -> NifResult<Term<'a>> {
    // Simplified prepare implementation
    Err(Error::Term(Box::new("Prepare not yet implemented")))
}

#[rustler::nif]
fn execute<'a>(
    env: Env<'a>,
    _connection: ResourceArc<ConnectionResource>,
    _prepared: ResourceArc<PreparedStatementResource>,
    _params: Vec<(String, Term<'a>)>,
) -> NifResult<Term<'a>> {
    // Simplified execute implementation
    Err(Error::Term(Box::new("Execute not yet implemented")))
}

// Define the NIF module
rustler::init!(
    "Elixir.RyugraphEx.Native",
    [
        open_database,
        in_memory_database,
        new_connection,
        query,
        prepare,
        execute
    ]
);

fn on_load(env: Env, _info: Term) -> bool {
    rustler::resource!(DatabaseResource, env);
    rustler::resource!(ConnectionResource, env);
    rustler::resource!(PreparedStatementResource, env);
    true
}
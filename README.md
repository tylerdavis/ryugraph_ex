# RyugraphEx

[![GitHub](https://img.shields.io/github/stars/tylerdavis/ryugraph_ex?style=social)](https://github.com/tylerdavis/ryugraph_ex)
[![Elixir CI](https://github.com/tylerdavis/ryugraph_ex/actions/workflows/elixir.yml/badge.svg)](https://github.com/tylerdavis/ryugraph_ex/actions)

Elixir bindings for RyuGraph - a high-performance embedded property graph database with Cypher query support.

**[Documentation](https://hexdocs.pm/ryugraph_ex)** | **[GitHub](https://github.com/tylerdavis/ryugraph_ex)**

## Features

- 🚀 **High Performance**: Built on RyuGraph's optimized C++ engine
- 📊 **Property Graph Model**: Full support for nodes, relationships, and properties
- 🔍 **Cypher Query Language**: Industry-standard graph query language
- 🔄 **Thread-Safe**: Concurrent operations with multiple connections
- 💾 **Flexible Storage**: Both persistent and in-memory database modes
- 🎯 **Prepared Statements**: Efficient repeated query execution
- 🔐 **Transactions**: ACID compliance with transaction support

## Installation

The package can be installed from GitHub. Add `ryugraph_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ryugraph_ex, github: "tylerdavis/ryugraph_ex"}
  ]
end
```

Once available on Hex, the package can be installed with:

```elixir
def deps do
  [
    {:ryugraph_ex, "~> 0.1.0"}
  ]
end
```

## Requirements

- Elixir ~> 1.19
- Rust (latest stable version)
- C++ compiler (for building RyuGraph)

The RyuGraph C++ library will be automatically compiled during the build process.

## Quick Start

### Basic Usage

```elixir
# Create an in-memory database
{:ok, db} = RyugraphEx.Database.in_memory()

# Create a connection
{:ok, conn} = RyugraphEx.Connection.new(db)

# Create schema
RyugraphEx.Schema.create_node_table(conn, "Person", [
  {:id, :int64, primary_key: true},
  {:name, :string},
  {:age, :int64}
])

# Insert data using Cypher
RyugraphEx.Connection.query!(conn, """
  CREATE (:Person {id: 1, name: 'Alice', age: 30})
""")

# Query data
results = RyugraphEx.Connection.query!(conn, """
  MATCH (p:Person)
  WHERE p.age >= 30
  RETURN p.name AS name, p.age AS age
""")
# => [%{name: "Alice", age: 30}]
```

### Using the Graph Module

```elixir
alias RyugraphEx.Graph

# Create nodes
{:ok, alice} = Graph.create_node(conn, "Person",
  name: "Alice",
  age: 30
)

{:ok, bob} = Graph.create_node(conn, "Person",
  name: "Bob",
  age: 25
)

# Create relationships
{:ok, rel} = Graph.create_relationship(conn,
  alice.id, bob.id, "KNOWS",
  since: 2020
)

# Find nodes
{:ok, people} = Graph.find_nodes(conn, "Person", %{age: 25})

# Find shortest path
{:ok, path} = Graph.shortest_path(conn, alice.id, bob.id)
```

### Prepared Statements

```elixir
# Prepare once
{:ok, stmt} = RyugraphEx.Connection.prepare(conn, """
  CREATE (:Person {id: $id, name: $name, age: $age})
""")

# Execute multiple times
RyugraphEx.Connection.execute!(conn, stmt,
  id: 2,
  name: "Charlie",
  age: 35
)

RyugraphEx.Connection.execute!(conn, stmt,
  id: 3,
  name: "Diana",
  age: 28
)
```

### Transactions

```elixir
RyugraphEx.Connection.transaction(conn, fn conn ->
  with {:ok, _} <- Graph.create_node(conn, "Account", balance: 1000),
       {:ok, _} <- Graph.create_node(conn, "Account", balance: 500) do
    {:ok, :success}
  end
end)
```

## Configuration Options

When opening a database, you can specify various configuration options:

```elixir
RyugraphEx.Database.open("/path/to/db",
  buffer_pool_size: 1024 * 1024 * 256,  # 256MB buffer pool
  max_num_threads: 8,                    # Max threads for query execution
  enable_compression: true,              # Enable data compression
  read_only: false,                      # Read-write mode
  max_db_size: 1024 * 1024 * 1024 * 10  # 10GB max size
)
```

## Architecture

The library consists of several layers:

1. **Rust NIF Layer**: Low-level bindings to RyuGraph C++ library
2. **Native Module**: Elixir interface to the Rust NIFs
3. **API Modules**: Idiomatic Elixir APIs for different aspects:
   - `Database`: Database lifecycle management
   - `Connection`: Query execution and connection management
   - `Schema`: DDL operations for tables and indexes
   - `Graph`: High-level graph operations
   - `PreparedStatement`: Parameterized query support

## Performance Considerations

- Use prepared statements for repeated queries with different parameters
- Create indexes on frequently queried properties
- Configure appropriate buffer pool size based on your dataset
- Use connection pooling for concurrent operations
- Batch operations within transactions when possible

## Development Status

This is the initial implementation of the Rustler NIF for RyuGraph. The following components are functional:

✅ Project structure and dependencies
✅ Elixir API modules (Database, Connection, Graph, Schema)
✅ Basic Rust NIF structure

The following components need further implementation:

⚠️ Database/Connection resource lifetime management
⚠️ Complete type conversion between Rust and Elixir
⚠️ Query execution implementation
⚠️ Prepared statement execution
⚠️ Full test coverage

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
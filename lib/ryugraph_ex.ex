defmodule RyugraphEx do
  @moduledoc """
  RyugraphEx - Elixir bindings for RyuGraph embedded graph database.

  RyuGraph is a high-performance embedded property graph database that supports
  the Cypher query language. This library provides idiomatic Elixir bindings
  for working with RyuGraph databases.

  ## Features

    * Full Cypher query language support
    * Property graph data model (nodes and relationships with properties)
    * Thread-safe connections for concurrent operations
    * Prepared statements for efficient repeated queries
    * Transaction support
    * Full-text and vector search capabilities
    * In-memory and persistent database modes

  ## Quick Start

  ### Creating a Database

      # Persistent database
      {:ok, db} = RyugraphEx.Database.open("/path/to/database")

      # In-memory database (great for testing)
      {:ok, db} = RyugraphEx.Database.in_memory()

  ### Establishing a Connection

      {:ok, conn} = RyugraphEx.Connection.new(db)

  ### Creating Schema

      alias RyugraphEx.{Connection, Schema}

      # Create node table
      Schema.create_node_table(conn, "Person", [
        {:id, :int64, primary_key: true},
        {:name, :string},
        {:age, :int64}
      ])

      # Create relationship table
      Schema.create_rel_table(conn, "KNOWS", "Person", "Person", [
        {:since, :date}
      ])

  ### Working with Graphs

  #### Using Cypher Queries

      # Create nodes
      Connection.query!(conn, \"\"\"
        CREATE (:Person {id: 1, name: 'Alice', age: 30})
      \"\"\")

      # Query nodes
      results = Connection.query!(conn, \"\"\"
        MATCH (p:Person)
        WHERE p.age > 25
        RETURN p.name AS name, p.age AS age
      \"\"\")

  #### Using the Graph Module

      alias RyugraphEx.Graph

      # Create a node
      {:ok, node} = Graph.create_node(conn, "Person",
        name: "Bob",
        age: 25
      )

      # Find nodes
      {:ok, people} = Graph.find_nodes(conn, "Person", %{age: 25})

      # Create relationships
      {:ok, rel} = Graph.create_relationship(conn,
        node1_id, node2_id, "KNOWS",
        since: ~D[2020-01-01]
      )

      # Find shortest path
      {:ok, path} = Graph.shortest_path(conn, alice_id, bob_id)

  ### Prepared Statements

      # Prepare a statement
      {:ok, stmt} = Connection.prepare(conn, \"\"\"
        CREATE (:Person {id: $id, name: $name, age: $age})
      \"\"\")

      # Execute with different parameters
      Connection.execute!(conn, stmt, id: 2, name: "Charlie", age: 35)
      Connection.execute!(conn, stmt, id: 3, name: "Diana", age: 28)

  ### Transactions

      Connection.transaction(conn, fn conn ->
        with {:ok, _} <- Connection.query(conn, "CREATE (:Person {name: 'Eve'})"),
             {:ok, _} <- Connection.query(conn, "CREATE (:Person {name: 'Frank'})") do
          {:ok, :success}
        end
      end)

  ## Modules

    * `RyugraphEx.Database` - Database management
    * `RyugraphEx.Connection` - Connection and query execution
    * `RyugraphEx.Graph` - High-level graph operations
    * `RyugraphEx.Schema` - Schema management
    * `RyugraphEx.PreparedStatement` - Prepared statement support

  ## Configuration

  Database configuration options can be passed when opening:

      RyugraphEx.Database.open("/path/to/db",
        buffer_pool_size: 1024 * 1024 * 256,  # 256MB
        max_num_threads: 8,
        enable_compression: true
      )

  ## Performance Tips

    1. Use prepared statements for repeated queries
    2. Create indexes on frequently queried properties
    3. Use connection pooling for concurrent operations
    4. Batch operations within transactions when possible
    5. Configure appropriate buffer pool size for your workload

  """

  @doc """
  Returns the version of the RyugraphEx library.
  """
  def version, do: "0.1.0"
end

alias RyugraphEx.{Database, Connection, Graph, Schema}

{:ok, db} = Database.in_memory()
{:ok, conn} = Connection.new(db)

# Create test schema
Schema.create_node_table(conn, "TestPerson", [
  {:id, :int64, primary_key: true},
  {:name, :string}
])

# Create a node
{:ok, node} = Graph.create_node(conn, "TestPerson", id: 1, name: "Test")

IO.puts("Node created:")
IO.inspect(node, pretty: true, limit: :infinity)
IO.puts("\nNode ID: #{inspect(node.id)}")
IO.puts("Node ID type: #{inspect(is_binary(node.id))}")

# Try to create another node
{:ok, node2} = Graph.create_node(conn, "TestPerson", id: 2, name: "Test2")
IO.puts("\nNode 2 ID: #{inspect(node2.id)}")

# Create relationship table
Schema.create_rel_table(conn, "TESTREL", "TestPerson", "TestPerson", [])

# Try to create relationship
IO.puts("\nAttempting to create relationship with IDs: #{inspect(node.id)} and #{inspect(node2.id)}")
result = Graph.create_relationship(conn, node.id, node2.id, "TESTREL")
IO.inspect(result, pretty: true, limit: :infinity)
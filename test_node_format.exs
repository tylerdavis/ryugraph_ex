alias RyugraphEx.{Database, Connection}

{:ok, db} = Database.in_memory()
{:ok, conn} = Connection.new(db)

# Create a test table and node
Connection.query!(conn, """
  CREATE NODE TABLE TestNode(
    id INT64,
    name STRING,
    age INT32,
    PRIMARY KEY(id)
  );
""")

# Create a node
Connection.query!(conn, """
  CREATE (n:TestNode {id: 1, name: 'Alice', age: 25});
""")

# Query the node and see what format it returns
{:ok, results} = Connection.query(conn, """
  MATCH (n:TestNode)
  WHERE n.id = 1
  RETURN n;
""")

IO.puts("Query result format:")
IO.inspect(results, pretty: true, limit: :infinity)

# Extract the node
[%{"n" => node}] = results
IO.puts("\nNode structure:")
IO.inspect(node, pretty: true, limit: :infinity)

# Check if properties exist
cond do
  Map.has_key?(node, :properties) ->
    IO.puts("\n:properties key exists")
    IO.inspect(node[:properties], label: "Properties")

  Map.has_key?(node, "properties") ->
    IO.puts("\n\"properties\" key exists")
    IO.inspect(node["properties"], label: "Properties")

  true ->
    IO.puts("\nNo properties key found")
    IO.puts("Available keys: #{inspect(Map.keys(node))}")
end

# Now test an update
{:ok, update_results} = Connection.query(conn, """
  MATCH (n:TestNode)
  WHERE n.id = 1
  SET n.age = 26
  RETURN n;
""")

IO.puts("\nAfter update:")
[%{"n" => updated_node}] = update_results
IO.inspect(updated_node, pretty: true, limit: :infinity)

# Check what the update_node function returns
IO.puts("\n\nNow testing Graph.update_node function:")
alias RyugraphEx.Graph

{:ok, graph_node} = Graph.update_node(conn, 1, age: 27, email: "alice@test.com")
IO.puts("Graph.update_node result:")
IO.inspect(graph_node, pretty: true, limit: :infinity)
#!/usr/bin/env elixir

# Test script to verify node format with atomized keys works

alias RyugraphEx.{Database, Connection, Graph}

IO.puts("Testing Atomized Keys in Graph Module")
IO.puts("=" |> String.duplicate(40))

# Create an in-memory database
{:ok, db} = Database.in_memory()
{:ok, conn} = Connection.new(db)

# Setup schema
{:ok, _} = Connection.query(conn, """
  CREATE NODE TABLE Person(
    id INT64,
    name STRING,
    age INT64,
    PRIMARY KEY(id)
  )
""")

# Test create_node with Graph module
IO.puts("\n1. Testing Graph.create_node...")
{:ok, node} = Graph.create_node(conn, "Person", id: 1, name: "Alice", age: 30)

IO.puts("Created node:")
IO.inspect(node, pretty: true)

# Test dot notation access
IO.puts("\n2. Testing dot notation access...")
try do
  IO.puts("  node.id = #{inspect(node.id)}")
  IO.puts("  node.label = #{inspect(node.label)}")
  IO.puts("  node.properties.name = #{inspect(node.properties.name)}")
  IO.puts("  ✓ Dot notation works!")
rescue
  e ->
    IO.puts("  ✗ Error with dot notation: #{inspect(e)}")
    IO.puts("  Node keys: #{inspect(Map.keys(node))}")
end

# Test find_nodes
IO.puts("\n3. Testing Graph.find_nodes...")
{:ok, nodes} = Graph.find_nodes(conn, "Person", %{id: 1})
IO.puts("Found #{length(nodes)} node(s)")

case nodes do
  [found_node] ->
    IO.inspect(found_node, pretty: true, label: "Found node")
    try do
      IO.puts("  Found node.id = #{inspect(found_node.id)}")
      IO.puts("  ✓ find_nodes returns atomized keys!")
    rescue
      _ ->
        IO.puts("  ✗ find_nodes doesn't have atomized keys")
    end

  _ ->
    IO.puts("  Unexpected result: #{inspect(nodes)}")
end

# Test create_relationship
IO.puts("\n4. Testing relationships...")
{:ok, node2} = Graph.create_node(conn, "Person", id: 2, name: "Bob", age: 25)

# Use the node IDs for relationship
result = Graph.create_relationship(conn, node.id, node2.id, "KNOWS", since: 2020)

case result do
  {:ok, rel} ->
    IO.puts("  ✓ Relationship created")
    IO.inspect(rel, pretty: true, label: "  Relationship")

  {:error, reason} ->
    IO.puts("  ✗ Failed to create relationship: #{reason}")
end
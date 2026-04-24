#!/usr/bin/env elixir

# Summary test script to verify the current status

alias RyugraphEx.{Database, Connection, Graph, Schema}

IO.puts("RyugraphEx Status Check")
IO.puts("=" |> String.duplicate(40))

{:ok, db} = Database.in_memory()
{:ok, conn} = Connection.new(db)

tests_passed = 0
tests_failed = 0

# Test 1: Basic DDL
IO.write("1. Basic DDL (CREATE TABLE)... ")
try do
  {:ok, _} = Connection.query(conn, """
    CREATE NODE TABLE Person(
      id INT64,
      name STRING,
      age INT64,
      PRIMARY KEY(id)
    )
  """)
  IO.puts("✓")
  tests_passed = tests_passed + 1
rescue
  _ ->
    IO.puts("✗")
    tests_failed = tests_failed + 1
end

# Test 2: Basic DML (INSERT)
IO.write("2. Basic DML (INSERT)... ")
try do
  {:ok, _} = Connection.query(conn, "CREATE (:Person {id: 1, name: 'Alice', age: 30})")
  IO.puts("✓")
  tests_passed = tests_passed + 1
rescue
  _ ->
    IO.puts("✗")
    tests_failed = tests_failed + 1
end

# Test 3: Basic Query
IO.write("3. Basic Query (MATCH)... ")
try do
  {:ok, results} = Connection.query(conn, "MATCH (p:Person) RETURN p.name AS name, p.age AS age")
  if results == [%{"age" => 30, "name" => "Alice"}] do
    IO.puts("✓")
    tests_passed = tests_passed + 1
  else
    IO.puts("✗ (wrong format)")
    tests_failed = tests_failed + 1
  end
rescue
  _ ->
    IO.puts("✗")
    tests_failed = tests_failed + 1
end

# Test 4: Graph.create_node
IO.write("4. Graph.create_node... ")
try do
  {:ok, node} = Graph.create_node(conn, "Person", id: 2, name: "Bob", age: 25)
  if node.id && node.label == "Person" && node.properties.name == "Bob" do
    IO.puts("✓")
    tests_passed = tests_passed + 1
  else
    IO.puts("✗ (wrong format)")
    tests_failed = tests_failed + 1
  end
rescue
  _ ->
    IO.puts("✗")
    tests_failed = tests_failed + 1
end

# Test 5: Graph.find_nodes
IO.write("5. Graph.find_nodes... ")
try do
  {:ok, nodes} = Graph.find_nodes(conn, "Person", %{id: 1})
  if length(nodes) == 1 && hd(nodes).properties.name == "Alice" do
    IO.puts("✓")
    tests_passed = tests_passed + 1
  else
    IO.puts("✗ (wrong result)")
    tests_failed = tests_failed + 1
  end
rescue
  _ ->
    IO.puts("✗")
    tests_failed = tests_failed + 1
end

# Test 6: Prepared statements
IO.write("6. Prepared statements... ")
try do
  {:ok, prepared} = Connection.prepare(conn, "CREATE (:Person {id: $id, name: $name, age: $age})")
  {:ok, _} = Connection.execute(conn, prepared, id: 3, name: "Charlie", age: 35)
  IO.puts("✓")
  tests_passed = tests_passed + 1
rescue
  _ ->
    IO.puts("✗")
    tests_failed = tests_failed + 1
end

# Test 7: Transactions
IO.write("7. Transactions... ")
try do
  {:ok, _} = Connection.query(conn, "BEGIN TRANSACTION")
  {:ok, _} = Connection.query(conn, "CREATE (:Person {id: 4, name: 'Dave', age: 40})")
  {:ok, _} = Connection.query(conn, "COMMIT")
  IO.puts("✓")
  tests_passed = tests_passed + 1
rescue
  _ ->
    IO.puts("✗")
    tests_failed = tests_failed + 1
end

# Test 8: Relationship tables
IO.write("8. Relationship tables... ")
try do
  {:ok, _} = Connection.query(conn, """
    CREATE REL TABLE KNOWS(
      FROM Person TO Person,
      since INT64
    )
  """)
  IO.puts("✓")
  tests_passed = tests_passed + 1
rescue
  _ ->
    IO.puts("✗")
    tests_failed = tests_failed + 1
end

# Test 9: Creating relationships (raw query)
IO.write("9. Creating relationships... ")
try do
  {:ok, _} = Connection.query(conn, """
    MATCH (a:Person), (b:Person)
    WHERE a.id = 1 AND b.id = 2
    CREATE (a)-[:KNOWS {since: 2020}]->(b)
  """)
  IO.puts("✓")
  tests_passed = tests_passed + 1
rescue
  _ ->
    IO.puts("✗")
    tests_failed = tests_failed + 1
end

# Test 10: Result format (nodes)
IO.write("10. Node result format... ")
try do
  {:ok, [result]} = Connection.query(conn, "MATCH (p:Person {id: 1}) RETURN p")
  node = result["p"]
  if is_map(node) && node["id"] && node["properties"]["name"] == "Alice" do
    IO.puts("✓")
    tests_passed = tests_passed + 1
  else
    IO.puts("✗")
    tests_failed = tests_failed + 1
  end
rescue
  _ ->
    IO.puts("✗")
    tests_failed = tests_failed + 1
end

IO.puts("\n" <> String.duplicate("=", 40))
IO.puts("Results: #{tests_passed} passed, #{tests_failed} failed")
IO.puts("Success rate: #{round(tests_passed * 100 / (tests_passed + tests_failed))}%")
#!/usr/bin/env elixir

# Basic test script to verify RyugraphEx functionality

alias RyugraphEx.{Database, Connection}

IO.puts("Testing RyugraphEx Basic Functionality")
IO.puts("=" |> String.duplicate(40))

# Create an in-memory database
IO.puts("\n1. Creating in-memory database...")
{:ok, db} = Database.in_memory()
IO.puts("   ✓ Database created")

# Create a connection
IO.puts("\n2. Creating connection...")
{:ok, conn} = Connection.new(db)
IO.puts("   ✓ Connection created")

# Create a node table
IO.puts("\n3. Creating Person node table...")
{:ok, _} = Connection.query(conn, """
  CREATE NODE TABLE Person(
    name STRING,
    age INT64,
    PRIMARY KEY(name)
  )
""")
IO.puts("   ✓ Person table created")

# Insert some data
IO.puts("\n4. Inserting data...")
{:ok, _} = Connection.query(conn, "CREATE (:Person {name: 'Alice', age: 30})")
{:ok, _} = Connection.query(conn, "CREATE (:Person {name: 'Bob', age: 25})")
IO.puts("   ✓ Data inserted")

# Query the data
IO.puts("\n5. Querying data...")
{:ok, results} = Connection.query(conn, "MATCH (p:Person) RETURN p.name AS name, p.age AS age ORDER BY p.age")
IO.puts("   Results: #{inspect(results)}")

# Verify results format
IO.puts("\n6. Verifying result format...")
case results do
  [%{"age" => 25, "name" => "Bob"}, %{"age" => 30, "name" => "Alice"}] ->
    IO.puts("   ✓ Results are properly formatted as maps!")

  _ ->
    IO.puts("   ✗ Results format issue: #{inspect(results)}")
end

IO.puts("\n" <> String.duplicate("=", 40))
IO.puts("Test completed successfully!")
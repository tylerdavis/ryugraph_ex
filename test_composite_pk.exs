alias RyugraphEx.{Database, Connection}

{:ok, db} = Database.in_memory()
{:ok, conn} = Connection.new(db)

# Try to create table with composite primary key syntax
IO.puts("Testing composite primary key syntax...")
result = Connection.query(conn, """
  CREATE NODE TABLE CompositeTest(
    key1 INT64,
    key2 STRING,
    data STRING,
    PRIMARY KEY(key1, key2)
  );
""")

case result do
  {:ok, _} ->
    IO.puts("Success! Composite primary key syntax is supported")

    # Check what table_info returns
    {:ok, info} = Connection.query(conn, "CALL table_info('CompositeTest') RETURN *;")
    IO.puts("\nTable info results:")
    Enum.each(info, fn row ->
      IO.inspect(row, pretty: true, limit: :infinity)
    end)

  {:error, msg} ->
    IO.puts("Error: #{msg}")
    IO.puts("\nTrying single primary key syntax...")

    # Try with just one primary key
    result2 = Connection.query(conn, """
      CREATE NODE TABLE SingleTest(
        key1 INT64,
        key2 STRING,
        data STRING,
        PRIMARY KEY(key1)
      );
    """)

    case result2 do
      {:ok, _} -> IO.puts("Single primary key works")
      {:error, msg2} -> IO.puts("Single primary key error: #{msg2}")
    end
end
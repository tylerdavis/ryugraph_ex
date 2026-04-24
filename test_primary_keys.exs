alias RyugraphEx.{Database, Connection, Schema}

{:ok, db} = Database.in_memory()
{:ok, conn} = Connection.new(db)

# Create a table with composite primary key
Schema.create_node_table!(conn, "Composite", [
  {:key1, :int64},
  {:key2, :string},
  {:data, :string}
], primary_key: [:key1, :key2])

# Check what table_info returns
{:ok, info} = Connection.query(conn, "CALL table_info('Composite') RETURN *;")
IO.puts("Table info results:")
Enum.each(info, fn row ->
  IO.inspect(row, pretty: true, limit: :infinity)
end)

# Try show_tables to see what info is available
{:ok, tables} = Connection.query(conn, "CALL show_tables() RETURN *;")
IO.puts("\nShow tables results for Composite:")
tables
|> Enum.filter(fn t -> Map.get(t, "name") == "Composite" end)
|> Enum.each(&IO.inspect(&1, pretty: true, limit: :infinity))

# Create another table with single primary key
Schema.create_node_table!(conn, "Simple", [
  {:id, :int64, primary_key: true},
  {:name, :string}
])

{:ok, info2} = Connection.query(conn, "CALL table_info('Simple') RETURN *;")
IO.puts("\nSimple table info:")
Enum.each(info2, fn row ->
  IO.inspect(row, pretty: true, limit: :infinity)
end)
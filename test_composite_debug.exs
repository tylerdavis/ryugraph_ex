alias RyugraphEx.{Database, Connection, Schema}

{:ok, db} = Database.in_memory()
{:ok, conn} = Connection.new(db)

IO.puts("Creating Composite table with primary_key: [:key1, :key2]...")
Schema.create_node_table!(conn, "Composite", [
  {:key1, :int64},
  {:key2, :string},
  {:data, :string}
], primary_key: [:key1, :key2])

IO.puts("\nChecking Process dictionary:")
stored = Process.get({:primary_keys, "Composite"})
IO.puts("Stored primary keys: #{inspect(stored)}")

IO.puts("\nDescribing table:")
{:ok, info} = Schema.describe_table(conn, "Composite")

IO.puts("Table info returned:")
IO.inspect(info, pretty: true, limit: :infinity)

IO.puts("\nPrimary columns:")
primary_columns = Enum.filter(info[:columns], & &1[:is_primary])
IO.inspect(primary_columns, pretty: true, limit: :infinity)
IO.puts("Count: #{length(primary_columns)}")
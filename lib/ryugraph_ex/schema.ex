defmodule RyugraphEx.Schema do
  @moduledoc """
  Schema management functions for RyuGraph databases.

  This module provides functions to create and manage node tables, relationship tables,
  and indexes in a RyuGraph database.
  """

  alias RyugraphEx.Connection

  @type property_type ::
          :string
          | :int8
          | :int16
          | :int32
          | :int64
          | :uint8
          | :uint16
          | :uint32
          | :uint64
          | :int128
          | :float
          | :double
          | :bool
          | :date
          | :timestamp
          | :timestamp_tz
          | :timestamp_ns
          | :timestamp_ms
          | :timestamp_sec
          | :interval
          | :uuid
          | :blob
          | :decimal
          | {:list, property_type()}
          | {:array, property_type()}
          | {:map, property_type(), property_type()}

  @type property_def :: {atom() | String.t(), property_type()} | {atom() | String.t(), property_type(), keyword()}

  @doc """
  Creates a node table with the specified properties.

  ## Parameters

    * `conn` - A connection reference
    * `table_name` - The name of the node table to create
    * `properties` - A list of property definitions
    * `opts` - Table creation options

  ## Property Definition

  Properties can be defined as:
    * `{name, type}` - Simple property definition
    * `{name, type, opts}` - Property with options like primary key

  ## Options

    * `:primary_key` - Specify the primary key column(s)

  ## Examples

      iex> RyugraphEx.Schema.create_node_table(conn, "Person", [
      ...>   {:name, :string},
      ...>   {:age, :int64},
      ...>   {:email, :string}
      ...> ], primary_key: [:name])
      {:ok, :created}

      iex> RyugraphEx.Schema.create_node_table(conn, "Product", [
      ...>   {:id, :int64, primary_key: true},
      ...>   {:name, :string},
      ...>   {:price, :double},
      ...>   {:tags, {:list, :string}}
      ...> ])
      {:ok, :created}

  """
  @spec create_node_table(Connection.t(), String.t(), [property_def()], keyword()) ::
          {:ok, :created} | {:error, String.t()}
  def create_node_table(conn, table_name, properties, opts \\ []) do
    props_str = properties_to_schema_string(properties, opts)
    query = "CREATE NODE TABLE #{table_name}(#{props_str});"

    case Connection.query(conn, query) do
      {:ok, _} -> {:ok, :created}
      error -> error
    end
  end

  @doc """
  Creates a relationship table with the specified properties.

  ## Parameters

    * `conn` - A connection reference
    * `table_name` - The name of the relationship table to create
    * `from_table` - The source node table
    * `to_table` - The destination node table
    * `properties` - A list of property definitions
    * `opts` - Table creation options

  ## Options

    * `:multiplicity` - Can be `:one_to_one`, `:one_to_many`, `:many_to_many` (default)

  ## Examples

      iex> RyugraphEx.Schema.create_rel_table(conn, "KNOWS",
      ...>   "Person", "Person",
      ...>   [
      ...>     {:since, :date},
      ...>     {:strength, :double}
      ...>   ]
      ...> )
      {:ok, :created}

      iex> RyugraphEx.Schema.create_rel_table(conn, "OWNS",
      ...>   "Person", "Product",
      ...>   [
      ...>     {:quantity, :int64},
      ...>     {:purchase_date, :date}
      ...>   ],
      ...>   multiplicity: :one_to_many
      ...> )
      {:ok, :created}

  """
  @spec create_rel_table(
          Connection.t(),
          String.t(),
          String.t(),
          String.t(),
          [property_def()],
          keyword()
        ) :: {:ok, :created} | {:error, String.t()}
  def create_rel_table(conn, table_name, from_table, to_table, properties \\ [], opts \\ []) do
    props_str =
      if properties == [] do
        ""
      else
        ", " <> properties_to_schema_string(properties, opts)
      end

    multiplicity =
      case Keyword.get(opts, :multiplicity, :many_to_many) do
        :one_to_one -> "ONE TO ONE"
        :one_to_many -> "MANY TO ONE"
        :many_to_many -> "MANY TO MANY"
      end

    query = """
    CREATE REL TABLE #{table_name}(
      FROM #{from_table} TO #{to_table}#{props_str},
      #{multiplicity}
    );
    """

    case Connection.query(conn, query) do
      {:ok, _} -> {:ok, :created}
      error -> error
    end
  end

  @doc """
  Creates an index on specified columns of a table.

  ## Parameters

    * `conn` - A connection reference
    * `table_name` - The name of the table
    * `columns` - Column or list of columns to index

  ## Examples

      iex> RyugraphEx.Schema.create_index(conn, "Person", :email)
      {:ok, :created}

      iex> RyugraphEx.Schema.create_index(conn, "Person", [:age, :city])
      {:ok, :created}

  """
  @spec create_index(Connection.t(), String.t(), atom() | String.t() | [atom() | String.t()]) ::
          {:ok, :created} | {:error, String.t()}
  def create_index(conn, table_name, columns) when is_atom(columns) or is_binary(columns) do
    create_index(conn, table_name, [columns])
  end

  def create_index(conn, table_name, columns) when is_list(columns) do
    columns_str = Enum.join(columns, ", ")
    query = "CREATE INDEX ON #{table_name}(#{columns_str});"

    case Connection.query(conn, query) do
      {:ok, _} -> {:ok, :created}
      error -> error
    end
  end

  @doc """
  Drops a node table.

  ## Parameters

    * `conn` - A connection reference
    * `table_name` - The name of the table to drop
    * `opts` - Drop options

  ## Options

    * `:cascade` - If true, drops the table and all dependent objects

  ## Examples

      iex> RyugraphEx.Schema.drop_node_table(conn, "Person")
      {:ok, :dropped}

      iex> RyugraphEx.Schema.drop_node_table(conn, "Person", cascade: true)
      {:ok, :dropped}

  """
  @spec drop_node_table(Connection.t(), String.t(), keyword()) ::
          {:ok, :dropped} | {:error, String.t()}
  def drop_node_table(conn, table_name, opts \\ []) do
    cascade = if Keyword.get(opts, :cascade, false), do: " CASCADE", else: ""
    query = "DROP TABLE #{table_name}#{cascade};"

    case Connection.query(conn, query) do
      {:ok, _} -> {:ok, :dropped}
      error -> error
    end
  end

  @doc """
  Drops a relationship table.

  ## Parameters

    * `conn` - A connection reference
    * `table_name` - The name of the relationship table to drop
    * `opts` - Drop options

  ## Examples

      iex> RyugraphEx.Schema.drop_rel_table(conn, "KNOWS")
      {:ok, :dropped}

  """
  @spec drop_rel_table(Connection.t(), String.t(), keyword()) ::
          {:ok, :dropped} | {:error, String.t()}
  def drop_rel_table(conn, table_name, opts \\ []) do
    drop_node_table(conn, table_name, opts)
  end

  @doc """
  Lists all node tables in the database.

  ## Parameters

    * `conn` - A connection reference

  ## Examples

      iex> RyugraphEx.Schema.list_node_tables(conn)
      {:ok, ["Person", "Product", "Order"]}

  """
  @spec list_node_tables(Connection.t()) :: {:ok, [String.t()]} | {:error, String.t()}
  def list_node_tables(conn) do
    query = "CALL show_tables() RETURN *;"

    case Connection.query(conn, query) do
      {:ok, results} ->
        tables =
          results
          |> Enum.filter(fn row -> Map.get(row, "type") == "NODE" end)
          |> Enum.map(fn row -> Map.get(row, "name") end)

        {:ok, tables}

      error ->
        error
    end
  end

  @doc """
  Lists all relationship tables in the database.

  ## Parameters

    * `conn` - A connection reference

  ## Examples

      iex> RyugraphEx.Schema.list_rel_tables(conn)
      {:ok, ["KNOWS", "OWNS", "PURCHASED"]}

  """
  @spec list_rel_tables(Connection.t()) :: {:ok, [String.t()]} | {:error, String.t()}
  def list_rel_tables(conn) do
    query = "CALL show_tables() RETURN *;"

    case Connection.query(conn, query) do
      {:ok, results} ->
        tables =
          results
          |> Enum.filter(fn row -> Map.get(row, "type") == "REL" end)
          |> Enum.map(fn row -> Map.get(row, "name") end)

        {:ok, tables}

      error ->
        error
    end
  end

  @doc """
  Gets information about a table's schema.

  ## Parameters

    * `conn` - A connection reference
    * `table_name` - The name of the table

  ## Examples

      iex> RyugraphEx.Schema.describe_table(conn, "Person")
      {:ok, %{
        name: "Person",
        type: "NODE",
        columns: [
          %{name: "name", type: "STRING", is_primary: true},
          %{name: "age", type: "INT64", is_primary: false}
        ]
      }}

  """
  @spec describe_table(Connection.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def describe_table(conn, table_name) do
    query = "CALL table_info('#{table_name}') RETURN *;"

    case Connection.query(conn, query) do
      {:ok, results} when results != [] ->
        columns =
          Enum.map(results, fn row ->
            %{
              name: Map.get(row, "property_name"),
              type: Map.get(row, "property_type"),
              is_primary: Map.get(row, "is_primary", false)
            }
          end)

        {:ok,
         %{
           name: table_name,
           columns: columns
         }}

      {:ok, []} ->
        {:error, "Table not found: #{table_name}"}

      error ->
        error
    end
  end

  # Helper functions

  defp properties_to_schema_string(properties, opts) do
    primary_keys =
      case Keyword.get(opts, :primary_key) do
        nil ->
          # Check for inline primary key definitions
          properties
          |> Enum.filter(fn
            {_name, _type, prop_opts} -> Keyword.get(prop_opts, :primary_key, false)
            _ -> false
          end)
          |> Enum.map(fn {name, _, _} -> name end)

        keys when is_list(keys) ->
          keys

        key ->
          [key]
      end

    props_defs =
      properties
      |> Enum.map(fn prop -> property_to_string(prop) end)

    all_defs =
      if primary_keys != [] do
        pk_str = "PRIMARY KEY(#{Enum.join(primary_keys, ", ")})"
        props_defs ++ [pk_str]
      else
        props_defs
      end

    Enum.join(all_defs, ", ")
  end

  defp property_to_string({name, type}) do
    "#{name} #{type_to_string(type)}"
  end

  defp property_to_string({name, type, _opts}) do
    "#{name} #{type_to_string(type)}"
  end

  defp type_to_string(:string), do: "STRING"
  defp type_to_string(:int8), do: "INT8"
  defp type_to_string(:int16), do: "INT16"
  defp type_to_string(:int32), do: "INT32"
  defp type_to_string(:int64), do: "INT64"
  defp type_to_string(:uint8), do: "UINT8"
  defp type_to_string(:uint16), do: "UINT16"
  defp type_to_string(:uint32), do: "UINT32"
  defp type_to_string(:uint64), do: "UINT64"
  defp type_to_string(:int128), do: "INT128"
  defp type_to_string(:float), do: "FLOAT"
  defp type_to_string(:double), do: "DOUBLE"
  defp type_to_string(:bool), do: "BOOL"
  defp type_to_string(:boolean), do: "BOOL"
  defp type_to_string(:date), do: "DATE"
  defp type_to_string(:timestamp), do: "TIMESTAMP"
  defp type_to_string(:timestamp_tz), do: "TIMESTAMP_TZ"
  defp type_to_string(:timestamp_ns), do: "TIMESTAMP_NS"
  defp type_to_string(:timestamp_ms), do: "TIMESTAMP_MS"
  defp type_to_string(:timestamp_sec), do: "TIMESTAMP_SEC"
  defp type_to_string(:interval), do: "INTERVAL"
  defp type_to_string(:uuid), do: "UUID"
  defp type_to_string(:blob), do: "BLOB"
  defp type_to_string(:decimal), do: "DECIMAL"
  defp type_to_string({:list, inner_type}), do: "LIST<#{type_to_string(inner_type)}>"
  defp type_to_string({:array, inner_type}), do: "ARRAY<#{type_to_string(inner_type)}>"
  defp type_to_string({:map, key_type, val_type}), do: "MAP<#{type_to_string(key_type)}, #{type_to_string(val_type)}>"
end
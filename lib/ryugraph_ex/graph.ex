defmodule RyugraphEx.Graph do
  @moduledoc """
  High-level graph operations for RyuGraph.

  This module provides Elixir-friendly functions for common graph operations,
  abstracting away the Cypher query language for simple use cases.
  """

  alias RyugraphEx.Connection

  @doc """
  Creates a node with the given label and properties.

  ## Parameters

    * `conn` - A connection reference
    * `label` - The node label
    * `properties` - A map or keyword list of properties

  ## Examples

      iex> RyugraphEx.Graph.create_node(conn, "Person", name: "Alice", age: 25)
      {:ok, %{node: true, id: ..., label: "Person", properties: %{name: "Alice", age: 25}}}

  """
  @spec create_node(Connection.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, String.t()}
  def create_node(conn, label, properties \\ %{}) when is_binary(label) do
    props_string = properties_to_cypher(properties)
    query = "CREATE (n:#{label} #{props_string}) RETURN n;"

    case Connection.query(conn, query) do
      {:ok, [%{"n" => node}]} -> {:ok, node}
      {:ok, _} -> {:error, "Unexpected result format"}
      error -> error
    end
  end

  @doc """
  Creates a relationship between two nodes.

  ## Parameters

    * `conn` - A connection reference
    * `from_node_id` - The ID of the source node
    * `to_node_id` - The ID of the destination node
    * `rel_label` - The relationship label
    * `properties` - Optional properties for the relationship

  ## Examples

      iex> RyugraphEx.Graph.create_relationship(conn, node1_id, node2_id, "KNOWS",
      ...>   since: 2020
      ...> )
      {:ok, %{rel: true, id: ..., label: "KNOWS", src: ..., dst: ..., properties: %{since: 2020}}}

  """
  @spec create_relationship(
          Connection.t(),
          String.t() | integer(),
          String.t() | integer(),
          String.t(),
          keyword() | map()
        ) :: {:ok, map()} | {:error, String.t()}
  def create_relationship(conn, from_node_id, to_node_id, rel_label, properties \\ %{}) do
    props_string = properties_to_cypher(properties)

    query = """
    MATCH (a), (b)
    WHERE id(a) = $from_id AND id(b) = $to_id
    CREATE (a)-[r:#{rel_label} #{props_string}]->(b)
    RETURN r;
    """

    case Connection.prepare(conn, query) do
      {:ok, prepared} ->
        case Connection.execute(conn, prepared,
               from_id: from_node_id,
               to_id: to_node_id
             ) do
          {:ok, [%{"r" => rel}]} -> {:ok, rel}
          {:ok, _} -> {:error, "Unexpected result format"}
          error -> error
        end

      error ->
        error
    end
  end

  @doc """
  Finds nodes matching the given criteria.

  ## Parameters

    * `conn` - A connection reference
    * `label` - The node label to search for
    * `where_clause` - Optional WHERE clause conditions as a map or string
    * `opts` - Query options

  ## Options

    * `:limit` - Maximum number of results to return
    * `:order_by` - Property to order results by
    * `:desc` - If true, order results in descending order (default: false)

  ## Examples

      iex> RyugraphEx.Graph.find_nodes(conn, "Person")
      {:ok, [%{node: true, label: "Person", properties: %{...}}, ...]}

      iex> RyugraphEx.Graph.find_nodes(conn, "Person", %{age: 25})
      {:ok, [%{node: true, label: "Person", properties: %{name: "Alice", age: 25}}]}

      iex> RyugraphEx.Graph.find_nodes(conn, "Person", "n.age > 20", limit: 10)
      {:ok, [...]}

  """
  @spec find_nodes(Connection.t(), String.t(), map() | String.t() | nil, keyword()) ::
          {:ok, list(map())} | {:error, String.t()}
  def find_nodes(conn, label, where_clause \\ nil, opts \\ []) do
    query = build_find_query(label, where_clause, opts)
    Connection.query(conn, query)
  end

  @doc """
  Finds the shortest path between two nodes.

  ## Parameters

    * `conn` - A connection reference
    * `from_node_id` - The ID of the start node
    * `to_node_id` - The ID of the end node
    * `opts` - Path finding options

  ## Options

    * `:rel_label` - Only follow relationships with this label
    * `:max_length` - Maximum path length (default: no limit)

  ## Examples

      iex> RyugraphEx.Graph.shortest_path(conn, node1_id, node2_id)
      {:ok, %{nodes: [...], rels: [...]}}

      iex> RyugraphEx.Graph.shortest_path(conn, node1_id, node2_id,
      ...>   rel_label: "KNOWS",
      ...>   max_length: 3
      ...> )
      {:ok, %{nodes: [...], rels: [...]}}

  """
  @spec shortest_path(Connection.t(), String.t() | integer(), String.t() | integer(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def shortest_path(conn, from_node_id, to_node_id, opts \\ []) do
    rel_pattern =
      case Keyword.get(opts, :rel_label) do
        nil -> ""
        label -> ":#{label}"
      end

    length_constraint =
      case Keyword.get(opts, :max_length) do
        nil -> "*"
        n when is_integer(n) -> "*1..#{n}"
      end

    query = """
    MATCH p = shortestPath((a)-[#{rel_pattern}#{length_constraint}]->(b))
    WHERE id(a) = $from_id AND id(b) = $to_id
    RETURN p;
    """

    case Connection.prepare(conn, query) do
      {:ok, prepared} ->
        case Connection.execute(conn, prepared,
               from_id: from_node_id,
               to_id: to_node_id
             ) do
          {:ok, [%{"p" => path}]} -> {:ok, path}
          {:ok, []} -> {:error, "No path found"}
          {:ok, _} -> {:error, "Unexpected result format"}
          error -> error
        end

      error ->
        error
    end
  end

  @doc """
  Gets all neighbors of a node.

  ## Parameters

    * `conn` - A connection reference
    * `node_id` - The ID of the node
    * `opts` - Options for the query

  ## Options

    * `:direction` - `:out` (default), `:in`, or `:both`
    * `:rel_label` - Only follow relationships with this label
    * `:depth` - How many hops to traverse (default: 1)

  ## Examples

      iex> RyugraphEx.Graph.get_neighbors(conn, node_id)
      {:ok, [%{node: true, ...}, ...]}

      iex> RyugraphEx.Graph.get_neighbors(conn, node_id,
      ...>   direction: :both,
      ...>   rel_label: "KNOWS"
      ...> )
      {:ok, [...]}

  """
  @spec get_neighbors(Connection.t(), String.t() | integer(), keyword()) ::
          {:ok, list(map())} | {:error, String.t()}
  def get_neighbors(conn, node_id, opts \\ []) do
    direction = Keyword.get(opts, :direction, :out)
    rel_label = Keyword.get(opts, :rel_label)
    depth = Keyword.get(opts, :depth, 1)

    rel_pattern = build_relationship_pattern(direction, rel_label, depth)

    query = """
    MATCH (a)#{rel_pattern}(b)
    WHERE id(a) = $node_id
    RETURN DISTINCT b;
    """

    case Connection.prepare(conn, query) do
      {:ok, prepared} ->
        case Connection.execute(conn, prepared, node_id: node_id) do
          {:ok, results} ->
            neighbors = Enum.map(results, fn %{"b" => node} -> node end)
            {:ok, neighbors}

          error ->
            error
        end

      error ->
        error
    end
  end

  @doc """
  Updates properties of a node.

  ## Parameters

    * `conn` - A connection reference
    * `node_id` - The ID of the node to update
    * `properties` - Properties to set or update

  ## Examples

      iex> RyugraphEx.Graph.update_node(conn, node_id, age: 26, city: "New York")
      {:ok, %{node: true, properties: %{age: 26, city: "New York", ...}}}

  """
  @spec update_node(Connection.t(), String.t() | integer(), keyword() | map()) ::
          {:ok, map()} | {:error, String.t()}
  def update_node(conn, node_id, properties) do
    set_clause = properties_to_set_clause(properties, "n")

    query = """
    MATCH (n)
    WHERE id(n) = $node_id
    SET #{set_clause}
    RETURN n;
    """

    case Connection.prepare(conn, query) do
      {:ok, prepared} ->
        case Connection.execute(conn, prepared, node_id: node_id) do
          {:ok, [%{"n" => node}]} -> {:ok, node}
          {:ok, []} -> {:error, "Node not found"}
          {:ok, _} -> {:error, "Unexpected result format"}
          error -> error
        end

      error ->
        error
    end
  end

  @doc """
  Deletes a node and optionally its relationships.

  ## Parameters

    * `conn` - A connection reference
    * `node_id` - The ID of the node to delete
    * `opts` - Deletion options

  ## Options

    * `:detach` - If true, deletes the node and all its relationships (default: false)

  ## Examples

      iex> RyugraphEx.Graph.delete_node(conn, node_id)
      {:ok, :deleted}

      iex> RyugraphEx.Graph.delete_node(conn, node_id, detach: true)
      {:ok, :deleted}

  """
  @spec delete_node(Connection.t(), String.t() | integer(), keyword()) ::
          {:ok, :deleted} | {:error, String.t()}
  def delete_node(conn, node_id, opts \\ []) do
    delete_cmd = if Keyword.get(opts, :detach, false), do: "DETACH DELETE", else: "DELETE"

    query = """
    MATCH (n)
    WHERE id(n) = $node_id
    #{delete_cmd} n;
    """

    case Connection.prepare(conn, query) do
      {:ok, prepared} ->
        case Connection.execute(conn, prepared, node_id: node_id) do
          {:ok, _} -> {:ok, :deleted}
          error -> error
        end

      error ->
        error
    end
  end

  # Helper functions

  defp properties_to_cypher(properties) when properties == %{} or properties == [], do: ""

  defp properties_to_cypher(properties) do
    props =
      properties
      |> Enum.map(fn {k, v} -> "#{k}: #{value_to_cypher(v)}" end)
      |> Enum.join(", ")

    "{#{props}}"
  end

  defp properties_to_set_clause(properties, variable) do
    properties
    |> Enum.map(fn {k, v} -> "#{variable}.#{k} = #{value_to_cypher(v)}" end)
    |> Enum.join(", ")
  end

  defp value_to_cypher(v) when is_binary(v), do: "'#{escape_string(v)}'"
  defp value_to_cypher(v) when is_integer(v), do: Integer.to_string(v)
  defp value_to_cypher(v) when is_float(v), do: Float.to_string(v)
  defp value_to_cypher(true), do: "true"
  defp value_to_cypher(false), do: "false"
  defp value_to_cypher(nil), do: "null"
  defp value_to_cypher(v) when is_list(v), do: "[#{Enum.map_join(v, ", ", &value_to_cypher/1)}]"

  defp escape_string(s), do: String.replace(s, "'", "\\'")

  defp build_find_query(label, where_clause, opts) do
    base_query = "MATCH (n:#{label})"

    where_part =
      case where_clause do
        nil ->
          ""

        clause when is_binary(clause) ->
          " WHERE #{clause}"

        conditions when is_map(conditions) ->
          cond_str =
            conditions
            |> Enum.map(fn {k, v} -> "n.#{k} = #{value_to_cypher(v)}" end)
            |> Enum.join(" AND ")

          " WHERE #{cond_str}"
      end

    order_part =
      case Keyword.get(opts, :order_by) do
        nil ->
          ""

        prop ->
          direction = if Keyword.get(opts, :desc, false), do: " DESC", else: ""
          " ORDER BY n.#{prop}#{direction}"
      end

    limit_part =
      case Keyword.get(opts, :limit) do
        nil -> ""
        n -> " LIMIT #{n}"
      end

    "#{base_query}#{where_part} RETURN n#{order_part}#{limit_part};"
  end

  defp build_relationship_pattern(direction, label, depth) do
    rel_label = if label, do: ":#{label}", else: ""
    depth_pattern = if depth == 1, do: "", else: "*#{depth}"

    case direction do
      :out -> "-[#{rel_label}#{depth_pattern}]->"
      :in -> "<-[#{rel_label}#{depth_pattern}]-"
      :both -> "-[#{rel_label}#{depth_pattern}]-"
    end
  end
end
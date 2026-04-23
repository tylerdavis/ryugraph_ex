defmodule RyugraphEx.PreparedStatement do
  @moduledoc """
  Module representing a prepared statement in RyuGraph.

  Prepared statements allow you to execute the same query multiple times
  with different parameters efficiently, as the query is parsed and planned only once.
  """

  @type t :: reference()
end
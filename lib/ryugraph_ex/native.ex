defmodule RyugraphEx.Native do
  @moduledoc """
  NIF module for RyuGraph database operations.
  This module provides the low-level interface to the Rust implementation.
  """

  use Rustler, otp_app: :ryugraph_ex, crate: "ryugraph_nif"

  # Database operations
  def open_database(_path, _config), do: :erlang.nif_error(:nif_not_loaded)
  def in_memory_database(_config), do: :erlang.nif_error(:nif_not_loaded)

  # Connection operations
  def new_connection(_database), do: :erlang.nif_error(:nif_not_loaded)

  # Query operations
  def query(_connection, _query_string), do: :erlang.nif_error(:nif_not_loaded)
  def prepare(_connection, _query_string), do: :erlang.nif_error(:nif_not_loaded)
  def execute(_connection, _prepared, _params), do: :erlang.nif_error(:nif_not_loaded)
end

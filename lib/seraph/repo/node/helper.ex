defmodule Seraph.Repo.Node.Helper do
  @moduledoc false

  @doc """
  Return node schema identifier key if it exists.
  """
  @spec identifier_field(Queryable.t()) :: atom
  def identifier_field(queryable) do
    case queryable.__schema__(:identifier) do
      {field, _, _} ->
        field

      _ ->
        raise ArgumentError, "No identifier for #{inspect(queryable)}."
    end
  end

  @doc """
  Build a node schema from a Bolt.Sips.Node
  """
  @spec build_node(Seraph.Repo.Queryable.t(), map) :: Seraph.Schema.Node.t()
  def build_node(queryable, node_data) do
    props =
      node_data.properties
      |> atom_map()
      |> Map.put(:__id__, node_data.id)
      |> Map.put(:additionalLabels, node_data.labels -- [queryable.__schema__(:primary_label)])

    struct(queryable, props)
  end

  @doc """
  Convert a %{String.t => value} map to an %{atom: value} map
  """
  @spec atom_map(map) :: map
  def atom_map(string_map) do
    string_map
    |> Enum.map(fn {k, v} ->
      {String.to_atom(k), v}
    end)
    |> Enum.into(%{})
  end
end

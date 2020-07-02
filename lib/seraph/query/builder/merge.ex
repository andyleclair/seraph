defmodule Seraph.Query.Builder.Merge do
  @moduledoc false

  @behaviour Seraph.Query.Operation

  alias Seraph.Query.Builder.{Entity, Helper, Merge}

  defstruct [:entities, :raw_entities]

  @type t :: %__MODULE__{
          raw_entities: nil | Entity.t(),
          entities: nil | Entity.t()
        }

  @doc """
  Build Merge data from ast.
  """
  @impl true
  @spec build(Macro.t(), Macro.Env.t()) :: %{
          merge: Merge.t(),
          identifiers: map,
          params: Keyword.t()
        }
  def build(ast, env) do
    %{entity: new_entity, params: params} =
      ast
      |> build_entity(env)
      |> Entity.extract_params([], "merge__")

    %{
      merge: %Merge{raw_entities: new_entity},
      identifiers: Helper.build_identifiers(new_entity, %{}, :merge),
      params: params
    }
  end

  @doc """
  Check Merge data validity.

  - See `Seraph.Query.Builder.Match.check/2`
  """
  @impl true
  @spec check(nil | Merge.t(), Seraph.Query.t()) :: :ok | {:error, String.t()}
  def check(%Merge{} = merge_data, %Seraph.Query{} = query) do
    Seraph.Query.Builder.Match.check(
      %Seraph.Query.Builder.Match{entities: [merge_data.raw_entities]},
      query
    )
  end

  @doc """
  Prepare final Merge data.
  - Fill node data for relationship entity
  """
  @impl true
  @spec prepare(Merge.t(), Seraph.Query.t(), Keyword.t()) :: %{
          merge: Merge.t(),
          new_identifiers: map
        }
  def prepare(%Merge{raw_entities: raw_entity} = merge, %Seraph.Query{} = query, _opts) do
    %{entities: new_entities, new_identifiers: new_identifiers} =
      case raw_entity do
        %Entity.Relationship{} = relationship ->
          new_relationship =
            relationship
            |> Map.put(:start, Map.fetch!(query.identifiers, relationship.start.identifier))
            |> Map.put(:end, Map.fetch!(query.identifiers, relationship.end.identifier))

          %{
            entities: new_relationship,
            new_identifiers: Map.put(%{}, relationship.identifier, new_relationship)
          }

        entity ->
          %{entities: entity, new_identifiers: %{}}
      end

    %{merge: Map.put(merge, :entities, new_entities), new_identifiers: new_identifiers}
  end

  @spec build_entity(Macro.t(), Macro.Env.t()) :: Entity.t()
  # Empty node
  # {}
  defp build_entity({:{}, _, []}, _env) do
    raise ArgumentError, "[MERGE] Empty nodes are not allowed in :merge."
  end

  defp build_entity([start_ast, relationship_ast, end_ast], env) do
    start_node = Entity.Node.from_ast(start_ast, env)
    end_node = Entity.Node.from_ast(end_ast, env)

    relationship =
      Entity.Relationship.from_ast(relationship_ast, env)
      |> Map.put(:start, start_node)
      |> Map.put(:end, end_node)

    if relationship.queryable == Seraph.Relationship do
      raise ArgumentError, "[CREATE] Relationships without a queryable are not allowed."
    end

    check_related_node(relationship.start)
    check_related_node(relationship.end)
    relationship
  end

  defp build_entity(ast, env) do
    Entity.Node.from_ast(ast, env)
  end

  defp check_related_node(%Entity.Node{
         identifier: identifier,
         queryable: Seraph.Node,
         properties: properties
       })
       when length(properties) > 0 do
    raise ArgumentError, "[CREATE] Already matched node `#{identifier}` can't be re-matched."
  end

  defp check_related_node(_) do
    :ok
  end

  defimpl Seraph.Query.Cypher, for: Merge do
    @spec encode(Merge.t(), Keyword.t()) :: String.t()
    def encode(%Merge{raw_entities: raw_entities}, _) do
      merge_str = Seraph.Query.Cypher.encode(raw_entities, operation: :merge)

      if String.length(merge_str) > 0 do
        """
        MERGE
          #{merge_str}
        """
      end
    end
  end
end

defmodule Seraph.Repo do
  @moduledoc """
  See `Seraph.Example.Repo` for common functions.

  See `Seraph.Example.Repo.Node` for node-specific functions.

  See `Seraph.Example.Repo.Relationship` for relationship-specific functions.
  """
  @type t :: module
  @type queryable :: module
  # other values :no_nodes, :full

  alias Seraph.Query.Builder

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @otp_app opts[:otp_app]

      alias Seraph.{Condition, Query}

      @module __MODULE__
      @relationship_result :contextual
      @default_opts [relationship_result: @relationship_result]

      @doc false
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      @doc false
      def start_link(opts \\ []) do
        Seraph.Repo.Supervisor.start_link(__MODULE__, @otp_app, opts)
      end

      @doc false
      def stop(timeout \\ 5000) do
        Supervisor.stop(__MODULE__, :normal, timeout)
      end

      # Planner
      @doc """
      Execute the given statement with the given params.
      Return the query result or an error.

      Options:
        * `with_stats` - If set to `true`, also returns the query stats
        (number of created nodes, created properties, etc.)

      ## Example

          # Without params
          iex> MyRepo.query("CREATE (p:Person {name: 'Collin Chou', role: 'Seraph'}) RETURN p")
          {:ok,
          [
            %{
              "p" => %Bolt.Sips.Types.Node{
                id: 1813,
                labels: ["Person"],
                properties: %{"name" => "Collin Chou", "role" => "Seraph"}
              }
            }
          ]}

          # With params
          iex(15)> MyRepo.query("MATCH (p:Person {name: $name}) RETURN p.role", %{name: "Collin Chou"})
          {:ok, [%{"p.role" => "Seraph"}]}

          # With :with_stats option
          iex(16)> MyRepo.query("MATCH (p:Person {name: $name}) DETACH DELETE p", %{name: "Collin Chou"}, with_stats: true)
          {:ok, %{results: [], stats: %{"nodes-deleted" => 1}}}
      """
      @spec query(String.t(), map, Keyword.t()) ::
              {:ok, [map] | %{results: [map], stats: map}} | {:error, any}
      def query(statement, params \\ %{}, opts \\ []) do
        Seraph.Query.Planner.query(__MODULE__, statement, params, opts)
      end

      @doc """
      Same as `query/3` but raise i ncase of error.
      """
      @spec query!(String.t(), map, Keyword.t()) :: [map] | %{results: [map], stats: map}
      def query!(statement, params \\ %{}, opts \\ []) do
        Seraph.Query.Planner.query!(__MODULE__, statement, params, opts)
      end

      @doc false
      def raw_query(statement, params \\ %{}, opts \\ []) do
        Seraph.Query.Planner.raw_query(__MODULE__, statement, params, opts)
      end

      @doc false
      def raw_query!(statement, params \\ %{}, opts \\ []) do
        Seraph.Query.Planner.raw_query!(__MODULE__, statement, params, opts)
      end

      def all(query, opts \\ []) do
        do_all(query, manage_opts(opts))
      end

      defp do_all(query, {:error, error}) do
        raise ArgumentError, error
      end

      defp do_all(query, opts) do
        query = Seraph.Query.prepare(query, opts)

        statement = Seraph.Query.to_string(query, opts)

        Seraph.Query.Planner.query!(__MODULE__, statement, Enum.into(query.params, %{}))
        |> format_results(query, opts)
      end

      defp format_results(results, query, opts, formated \\ [])

      defp format_results([], _, _, formated) do
        formated
      end

      defp format_results([result | t], query, opts, formated) do
        formated_res =
          Enum.map(result, &format_result(&1, query, result, opts))
          |> Enum.reduce(%{}, &Map.merge/2)
          |> remove_internal_results(query, Keyword.fetch!(opts, :relationship_result))

        format_results(t, query, opts, formated ++ [formated_res])
      end

      defp format_result({result_alias, result}, query, results, opts) do
        formated =
          case result_queryable(String.to_atom(result_alias), query) do
            {:ok, {nil, %Seraph.Query.Builder.NodeExpr{} = node_data}} ->
              Seraph.Node.map(result)

            {:ok, {queryable, %Seraph.Query.Builder.NodeExpr{}}} ->
              Seraph.Repo.Helper.build_node(queryable, result)

            {:ok, {queryable, %Seraph.Query.Builder.RelationshipExpr{} = rel_data}} ->
              %Builder.NodeExpr{variable: start_var, alias: start_alias} = rel_data.start
              %Builder.NodeExpr{variable: end_var, alias: end_alias} = rel_data.end

              relationship_result = Keyword.get(opts, :relationship_result, @relationship_result)

              {start_node, end_node} =
                case relationship_result do
                  :no_nodes ->
                    {nil, nil}

                  _ ->
                    {results[start_alias] || results[start_var],
                     results[end_alias] || results[end_var]}
                end

              Seraph.Repo.Helper.build_relationship(queryable, result, start_node, end_node)

            :error ->
              result
          end

        Map.put(%{}, result_alias, formated)
      end

      defp result_queryable(result_alias, query) do
        case Keyword.fetch(query.result_aliases, result_alias) do
          {:ok, entity_alias} ->
            Keyword.fetch(query.aliases, entity_alias)

          :error ->
            Keyword.fetch(query.aliases, result_alias)
        end
      end

      defp remove_internal_results(results, query, :full) do
        to_exclude =
          query.result_aliases
          |> Keyword.keys()
          |> Enum.map(&Atom.to_string/1)
          |> Enum.filter(fn str_key -> String.starts_with?(str_key, "__seraph_") end)

        Map.drop(results, to_exclude)
      end

      defp remove_internal_results(results, query, _) do
        results
      end

      defp manage_opts(opts, final_opts \\ @default_opts)

      defp manage_opts([], final_opts) do
        final_opts
      end

      defp manage_opts([{:relationship_result, relationship_result} | t], final_opts) do
        valid_values = [:full, :no_nodes, :contextual]

        if relationship_result in valid_values do
          Keyword.put(final_opts, :relationship_result, relationship_result)
        else
          {:error,
           "Invalid value for options :relationshp_result. Valid values: #{inspect(valid_values)}."}
        end
      end

      defp manage_opts([{invalid_opt, _} | _], _opts) do
        {:error, "#{inspect(invalid_opt)} is not a valid option."}
      end

      use Seraph.Repo.Node.Repo, __MODULE__
      use Seraph.Repo.Relationship.Repo, __MODULE__
    end
  end
end

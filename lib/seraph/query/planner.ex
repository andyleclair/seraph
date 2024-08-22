defmodule Seraph.Query.Planner do
  @moduledoc false

  @doc """
  Launch query agains Neo4j database and return the result.

  Options:
    * `:with_stats` - Wether to return the `stats` part of the result. (Possible values: `true`, `false` default: `false`)
  """
  @spec query(Seraph.Repo.t(), String.t(), map, Keyword.t()) :: {:ok, list | map} | {:error, any}
  def query(repo, statement, params \\ %{}, opts \\ [])
      when is_bitstring(statement) and is_map(params) do
    case raw_query(repo, statement, params, opts) do
      {:ok, results} ->
        {:ok, format_results(results, Keyword.get(opts, :with_stats))}

      error ->
        error
    end
  end

  @doc """
  Same as query/4 but raises in case of error.
  """
  @spec query!(Seraph.Repo.t(), String.t(), map, Keyword.t()) :: list | map
  def query!(repo, statement, params \\ %{}, opts \\ [])
      when is_bitstring(statement) and is_map(params) do
    raw_query!(repo, statement, params, opts)
    |> format_results(Keyword.get(opts, :with_stats))
  end

  @doc """
  Launch query agains Neo4j database and return the unformatted result.
  """
  @spec raw_query(Seraph.Repo.t(), String.t(), map, Keyword.t()) ::
          {:ok, Boltx.Response.t() | [Boltx.Response.t()]} | {:error, Boltx.Error.t()}
  def raw_query(repo, statement, params \\ %{}, opts \\ []) do
    Boltx.query(repo, statement, params, opts)
  end

  @doc """
  Same as raw_query/4 but raises in case of error.
  """
  @spec raw_query!(Seraph.Repo.t(), String.t(), map, Keyword.t()) ::
          Boltx.Response.t() | [Boltx.Response.t()] | Boltx.Exception.t()
  def raw_query!(repo, statement, params \\ %{}, opts \\ []) do
    Boltx.query!(repo, statement, params, opts)
  end

  defp format_results(results, true) do
    %{
      results: results.results,
      stats: results.stats
    }
  end

  defp format_results(results, _opts) do
    results.results
  end
end

defmodule SymphonyElixir.Tracker do
  @moduledoc """
  Adapter boundary for issue tracker reads and writes.
  """

  alias SymphonyElixir.Config

  @builtin_adapters %{
    "linear" => SymphonyElixir.Linear.Adapter,
    "memory" => SymphonyElixir.Tracker.Memory
  }

  @callback fetch_candidate_issues() :: {:ok, [term()]} | {:error, term()}
  @callback fetch_issues_by_states([String.t()]) :: {:ok, [term()]} | {:error, term()}
  @callback fetch_issue_states_by_ids([String.t()]) :: {:ok, [term()]} | {:error, term()}
  @callback create_comment(String.t(), String.t()) :: :ok | {:error, term()}
  @callback update_issue_state(String.t(), String.t()) :: :ok | {:error, term()}

  @spec fetch_candidate_issues() :: {:ok, [term()]} | {:error, term()}
  def fetch_candidate_issues do
    adapter!().fetch_candidate_issues()
  end

  @spec fetch_issues_by_states([String.t()]) :: {:ok, [term()]} | {:error, term()}
  def fetch_issues_by_states(states) do
    adapter!().fetch_issues_by_states(states)
  end

  @spec fetch_issue_states_by_ids([String.t()]) :: {:ok, [term()]} | {:error, term()}
  def fetch_issue_states_by_ids(issue_ids) do
    adapter!().fetch_issue_states_by_ids(issue_ids)
  end

  @spec create_comment(String.t(), String.t()) :: :ok | {:error, term()}
  def create_comment(issue_id, body) do
    adapter!().create_comment(issue_id, body)
  end

  @spec update_issue_state(String.t(), String.t()) :: :ok | {:error, term()}
  def update_issue_state(issue_id, state_name) do
    adapter!().update_issue_state(issue_id, state_name)
  end

  @spec adapter() :: module() | {:error, term()}
  def adapter do
    case adapter(Config.settings!().tracker.kind) do
      {:ok, module} -> module
      {:error, reason} -> {:error, reason}
    end
  end

  @spec adapter(String.t() | nil) :: {:ok, module()} | {:error, term()}
  def adapter(kind) when is_binary(kind) do
    normalized_kind = normalize_kind(kind)

    case Map.fetch(adapter_modules(), normalized_kind) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, {:unsupported_tracker_kind, kind}}
    end
  end

  def adapter(kind), do: {:error, {:unsupported_tracker_kind, kind}}

  @spec adapter!() :: module()
  def adapter! do
    case adapter() do
      module when is_atom(module) ->
        module

      {:error, reason} ->
        raise ArgumentError, "Invalid tracker adapter: #{inspect(reason)}"
    end
  end

  @spec supported_tracker_kinds() :: [String.t()]
  def supported_tracker_kinds do
    adapter_modules()
    |> Map.keys()
    |> Enum.sort()
  end

  defp adapter_modules do
    configured =
      :symphony_elixir
      |> Application.get_env(:tracker_adapter_modules, %{})
      |> Enum.reduce(%{}, fn {kind, module}, acc ->
        Map.put(acc, normalize_kind(kind), module)
      end)

    Map.merge(@builtin_adapters, configured)
  end

  defp normalize_kind(kind) when is_atom(kind), do: kind |> Atom.to_string() |> normalize_kind()

  defp normalize_kind(kind) when is_binary(kind) do
    kind
    |> String.trim()
    |> String.downcase()
  end
end

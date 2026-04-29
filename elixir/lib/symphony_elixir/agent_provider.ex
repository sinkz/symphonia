defmodule SymphonyElixir.AgentProvider do
  @moduledoc """
  Adapter boundary for coding-agent runtimes.

  Providers implement the session lifecycle used by `AgentRunner`. The built-in
  default provider is Codex App Server; other runtimes can be registered by
  adding entries to the `:agent_provider_modules` application environment.
  """

  alias SymphonyElixir.Config

  @callback start_session(Path.t(), keyword()) :: {:ok, term()} | {:error, term()}
  @callback run_turn(term(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  @callback stop_session(term()) :: :ok

  @builtin_providers %{
    "codex" => SymphonyElixir.Codex.AppServer,
    "opencode" => SymphonyElixir.OpenCode.Runner
  }

  @spec provider() :: {:ok, module()} | {:error, term()}
  def provider do
    provider(Config.settings!().agent.provider)
  end

  @spec provider(String.t() | nil) :: {:ok, module()} | {:error, term()}
  def provider(kind) when is_binary(kind) do
    normalized_kind = normalize_kind(kind)

    case Map.fetch(provider_modules(), normalized_kind) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, {:unsupported_agent_provider, kind}}
    end
  end

  def provider(kind), do: {:error, {:unsupported_agent_provider, kind}}

  @spec provider!() :: module()
  def provider! do
    case provider() do
      {:ok, module} ->
        module

      {:error, reason} ->
        raise ArgumentError, "Invalid agent provider: #{inspect(reason)}"
    end
  end

  @spec supported_provider_names() :: [String.t()]
  def supported_provider_names do
    provider_modules()
    |> Map.keys()
    |> Enum.sort()
  end

  defp provider_modules do
    configured =
      :symphony_elixir
      |> Application.get_env(:agent_provider_modules, %{})
      |> Enum.reduce(%{}, fn {kind, module}, acc ->
        Map.put(acc, normalize_kind(kind), module)
      end)

    Map.merge(@builtin_providers, configured)
  end

  defp normalize_kind(kind) when is_atom(kind), do: kind |> Atom.to_string() |> normalize_kind()

  defp normalize_kind(kind) when is_binary(kind) do
    kind
    |> String.trim()
    |> String.downcase()
  end
end

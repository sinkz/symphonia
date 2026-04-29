defmodule SymphonyElixir.OpenCode.Runner do
  @moduledoc """
  OpenCode provider implementation for `SymphonyElixir.AgentProvider`.

  V1 uses `opencode run` as a one-shot turn execution model.
  """

  @behaviour SymphonyElixir.AgentProvider

  require Logger
  alias SymphonyElixir.{Config, PathSafety}

  @type session :: %{
          workspace: Path.t(),
          worker_host: String.t() | nil,
          command: String.t(),
          model: String.t() | nil,
          agent: String.t() | nil,
          run_timeout_ms: pos_integer(),
          format: String.t(),
          dangerously_skip_permissions: boolean()
        }

  @spec start_session(Path.t(), keyword()) :: {:ok, session()} | {:error, term()}
  def start_session(workspace, opts \\ []) do
    worker_host = Keyword.get(opts, :worker_host)

    with {:ok, canonical_workspace} <- validate_workspace_cwd(workspace, worker_host) do
      settings = Config.settings!().opencode

      {:ok,
       %{
         workspace: canonical_workspace,
         worker_host: worker_host,
         command: settings.command,
         model: settings.model,
         agent: settings.agent,
         run_timeout_ms: settings.run_timeout_ms,
         format: settings.format,
         dangerously_skip_permissions: settings.dangerously_skip_permissions
       }}
    end
  end

  @spec run_turn(session(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def run_turn(session, prompt, issue, opts \\ []) do
    on_message = Keyword.get(opts, :on_message, fn _message -> :ok end)
    executor = Keyword.get(opts, :executor, &default_executor/3)

    session_id = build_session_id(issue)
    title = build_title(issue)
    {command, args, exec_opts} = build_command(session, title, prompt)

    emit_message(on_message, :session_started, %{session_id: session_id, provider: "opencode"})

    try do
      case executor.(command, args, exec_opts) do
        {output, 0} ->
          parsed = parse_json_lines(output)

          Enum.each(parsed.events, fn payload ->
            emit_message(on_message, :notification, %{payload: payload, provider: "opencode"})
          end)

          emit_message(on_message, :turn_completed, %{session_id: session_id, provider: "opencode"})

          {:ok, %{session_id: session_id, provider: :opencode, result: parsed.final_payload || output}}

        {output, status} ->
          emit_message(on_message, :turn_failed, %{session_id: session_id, status: status, provider: "opencode"})
          {:error, {:opencode_run_failed, status, output}}
      end
    rescue
      error in ErlangError ->
        case error.original do
          :enoent -> {:error, :opencode_not_found}
          :timeout -> {:error, :opencode_run_timeout}
          _ -> {:error, {:opencode_exec_error, error.original}}
        end
    end
  end

  @spec stop_session(session()) :: :ok
  def stop_session(_session), do: :ok

  defp default_executor(command, args, exec_opts), do: System.cmd(command, args, exec_opts)

  defp build_command(session, title, prompt) do
    base_args =
      ["run", "--format", session.format, "--title", title]
      |> maybe_append_option("--model", session.model)
      |> maybe_append_option("--agent", session.agent)
      |> maybe_append_flag("--dangerously-skip-permissions", session.dangerously_skip_permissions)

    exec_opts = [
      cd: session.workspace,
      stderr_to_stdout: true,
      timeout: session.run_timeout_ms
    ]

    {session.command, base_args ++ [prompt], exec_opts}
  end

  defp maybe_append_option(args, _flag, nil), do: args
  defp maybe_append_option(args, _flag, ""), do: args
  defp maybe_append_option(args, flag, value), do: args ++ [flag, value]

  defp maybe_append_flag(args, _flag, false), do: args
  defp maybe_append_flag(args, flag, true), do: args ++ [flag]

  defp parse_json_lines(output) when is_binary(output) do
    events =
      output
      |> String.split("\n", trim: true)
      |> Enum.reduce([], fn line, acc ->
        case Jason.decode(line) do
          {:ok, payload} when is_map(payload) -> [payload | acc]
          _ -> acc
        end
      end)
      |> Enum.reverse()

    %{events: events, final_payload: List.last(events)}
  end

  defp validate_workspace_cwd(workspace, nil) when is_binary(workspace) do
    expanded_workspace = Path.expand(workspace)
    expanded_root = Path.expand(Config.settings!().workspace.root)

    with {:ok, canonical_workspace} <- PathSafety.canonicalize(expanded_workspace),
         {:ok, canonical_root} <- PathSafety.canonicalize(expanded_root) do
      canonical_root_prefix = canonical_root <> "/"

      cond do
        canonical_workspace == canonical_root ->
          {:error, {:invalid_workspace_cwd, :workspace_root, canonical_workspace}}

        String.starts_with?(canonical_workspace <> "/", canonical_root_prefix) ->
          {:ok, canonical_workspace}

        true ->
          {:error, {:invalid_workspace_cwd, :outside_workspace_root, canonical_workspace, canonical_root}}
      end
    else
      {:error, {:path_canonicalize_failed, path, reason}} ->
        {:error, {:invalid_workspace_cwd, :path_unreadable, path, reason}}
    end
  end

  defp validate_workspace_cwd(workspace, worker_host)
       when is_binary(workspace) and is_binary(worker_host) do
    cond do
      String.trim(workspace) == "" ->
        {:error, {:invalid_workspace_cwd, :empty_remote_workspace, worker_host}}

      String.contains?(workspace, ["\n", "\r", <<0>>]) ->
        {:error, {:invalid_workspace_cwd, :invalid_remote_workspace, worker_host, workspace}}

      true ->
        {:ok, workspace}
    end
  end

  defp build_title(%{identifier: identifier, title: title})
       when is_binary(identifier) and is_binary(title) and title != "" do
    "#{identifier}: #{title}"
  end

  defp build_title(%{identifier: identifier}) when is_binary(identifier), do: identifier
  defp build_title(_issue), do: "Symphonia OpenCode Run"

  defp build_session_id(%{identifier: identifier}) when is_binary(identifier) do
    "opencode-#{identifier}-#{System.unique_integer([:positive])}"
  end

  defp build_session_id(_issue), do: "opencode-#{System.unique_integer([:positive])}"

  defp emit_message(on_message, event, details) when is_function(on_message, 1) do
    on_message.(Map.put(details, :event, event))
  end
end

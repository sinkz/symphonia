defmodule SymphonyElixir.OpenCodeRunnerTest do
  use SymphonyElixir.TestSupport

  alias SymphonyElixir.OpenCode.Runner

  test "agent provider resolves built-in opencode provider" do
    assert {:ok, Runner} = SymphonyElixir.AgentProvider.provider("opencode")
  end

  test "start_session uses opencode config defaults" do
    workspace_root =
      Path.join(System.tmp_dir!(), "symphony-opencode-workspaces-#{System.unique_integer([:positive])}")

    issue_workspace = Path.join(workspace_root, "OP-1")
    File.mkdir_p!(issue_workspace)

    on_exit(fn -> File.rm_rf(workspace_root) end)

    write_workflow_file!(Workflow.workflow_file_path(), workspace_root: workspace_root)

    assert {:ok, session} = Runner.start_session(issue_workspace)
    assert session.command == "opencode"
    assert session.run_timeout_ms == 3_600_000
    assert session.format == "json"
    assert session.dangerously_skip_permissions == false
  end

  test "run_turn executes opencode command with configured flags and emits events" do
    workspace_root =
      Path.join(System.tmp_dir!(), "symphony-opencode-cmd-#{System.unique_integer([:positive])}")

    issue_workspace = Path.join(workspace_root, "OP-2")
    File.mkdir_p!(issue_workspace)
    on_exit(fn -> File.rm_rf(workspace_root) end)

    write_workflow_file!(Workflow.workflow_file_path(),
      workspace_root: workspace_root,
      opencode_model: "anthropic/claude-sonnet-4",
      opencode_agent: "build",
      opencode_dangerously_skip_permissions: true
    )

    assert {:ok, session} = Runner.start_session(issue_workspace)

    issue = %{identifier: "OP-2", title: "Implement opencode provider"}
    parent = self()

    executor = fn command, args, opts ->
      send(parent, {:executor_called, command, args, opts})
      {"{\"type\":\"message\",\"text\":\"working\"}\n{\"type\":\"done\",\"status\":\"ok\"}\n", 0}
    end

    on_message = fn message -> send(parent, {:runner_message, message}) end

    assert {:ok, %{provider: :opencode, session_id: session_id}} =
             Runner.run_turn(session, "Do the thing", issue, executor: executor, on_message: on_message)

    assert is_binary(session_id)
    assert_receive {:executor_called, "opencode", args, opts}
    assert args |> Enum.join(" ") =~ "run --format json --title OP-2: Implement opencode provider"
    assert args |> Enum.join(" ") =~ "--model anthropic/claude-sonnet-4"
    assert args |> Enum.join(" ") =~ "--agent build"
    assert args |> Enum.join(" ") =~ "--dangerously-skip-permissions"
    assert Path.expand(opts[:cd]) == Path.expand(issue_workspace)

    assert_receive {:runner_message, %{event: :session_started, provider: "opencode"}}
    assert_receive {:runner_message, %{event: :notification, payload: %{"type" => "message"}}}
    assert_receive {:runner_message, %{event: :notification, payload: %{"type" => "done"}}}
    assert_receive {:runner_message, %{event: :turn_completed, provider: "opencode"}}
  end

  test "run_turn returns failure on non-zero exit status" do
    workspace_root =
      Path.join(System.tmp_dir!(), "symphony-opencode-fail-#{System.unique_integer([:positive])}")

    issue_workspace = Path.join(workspace_root, "OP-3")
    File.mkdir_p!(issue_workspace)
    on_exit(fn -> File.rm_rf(workspace_root) end)

    write_workflow_file!(Workflow.workflow_file_path(), workspace_root: workspace_root)
    assert {:ok, session} = Runner.start_session(issue_workspace)

    assert {:error, {:opencode_run_failed, 17, "boom"}} =
             Runner.run_turn(session, "Do the thing", %{identifier: "OP-3"}, executor: fn _, _, _ -> {"boom", 17} end)
  end

  test "run_turn maps missing binary and timeout errors" do
    workspace_root =
      Path.join(System.tmp_dir!(), "symphony-opencode-errors-#{System.unique_integer([:positive])}")

    issue_workspace = Path.join(workspace_root, "OP-4")
    File.mkdir_p!(issue_workspace)
    on_exit(fn -> File.rm_rf(workspace_root) end)

    write_workflow_file!(Workflow.workflow_file_path(), workspace_root: workspace_root)
    assert {:ok, session} = Runner.start_session(issue_workspace)

    missing_binary_executor = fn _, _, _ -> raise ErlangError, original: :enoent end
    timeout_executor = fn _, _, _ -> raise ErlangError, original: :timeout end

    assert {:error, :opencode_not_found} = Runner.run_turn(session, "Do the thing", %{identifier: "OP-4"}, executor: missing_binary_executor)
    assert {:error, :opencode_run_timeout} = Runner.run_turn(session, "Do the thing", %{identifier: "OP-4"}, executor: timeout_executor)
  end
end

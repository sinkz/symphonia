# Symphonia

Symphonia is an autonomous work orchestration layer for software teams. It turns product tasks
into isolated implementation runs so engineers can manage delivery flow instead of supervising
agent terminals.

[![Symphony demo video preview](.github/media/symphony-demo-poster.jpg)](.github/media/symphony-demo.mp4)

_In this [demo video](.github/media/symphony-demo.mp4), Symphonia monitors a board for work and
spawns agents to handle tasks end-to-end. Agents return proof of work: CI status, PR feedback,
complexity analysis, and execution evidence._

> [!WARNING]
> Symphonia is an engineering preview for trusted environments.

## What Symphonia Proposes

Symphonia is designed as a pluggable orchestration core where your stack choices stay yours:

- Bring your runtime: `codex`, `opencode`, or a custom harness-compatible provider.
- Bring your tracker: `linear` by default, plus Jira/Trello/ClickUp/custom adapters.
- Workspace-isolated execution model: each issue/task runs in its own workspace lifecycle.
- In-repo workflow policy: teams version prompts, runtime settings, and hooks through
  `WORKFLOW.md`.

This means Symphonia is not a bet on one vendor runtime or one issue tracker. It is a stable
execution core that keeps your delivery system portable.

## Open Runtime, Open Tracker

Symphonia defaults to `codex` + `linear` because they are practical defaults, not hard lock-in.

Example runtime switch:

```yaml
agent:
  provider: opencode

opencode:
  command: opencode
  model: anthropic/claude-sonnet-4
  agent: build
  run_timeout_ms: 3600000
```

Example custom provider registration:

```elixir
Application.put_env(:symphony_elixir, :agent_provider_modules, %{
  "my-runtime" => MyApp.AgentProvider
})
```

Example custom tracker registration:

```elixir
Application.put_env(:symphony_elixir, :tracker_adapter_modules, %{
  "jira" => MyApp.Tracker.JiraAdapter
})
```

## Running Symphonia

### Requirements

Symphonia works best in codebases that have adopted
[harness engineering](https://openai.com/index/harness-engineering/).

### Option 1. Make your own

Tell your favorite coding agent to build Symphonia in a programming language of your choice:

> Implement Symphonia according to the following spec:
> https://github.com/openai/symphony/blob/main/SPEC.md

### Option 2. Use our experimental reference implementation

Check out [elixir/README.md](elixir/README.md) for instructions on how to set up your environment
and run the Elixir-based Symphonia implementation. You can also ask your favorite coding agent to
help with the setup:

> Set up Symphonia for my repository based on
> https://github.com/openai/symphony/blob/main/elixir/README.md

---

## License

This project is licensed under the [Apache License 2.0](LICENSE).

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

Symphonia is designed as a pluggable orchestration core:

- Agent runtime provider boundary: default `codex` today, with space for providers like
  `opencode`.
- Tracker adapter boundary: default `linear`, with extension points for Jira, Trello, ClickUp, and
  custom adapters.
- Workspace-isolated execution model: each issue/task runs in its own workspace lifecycle.
- In-repo workflow policy: teams version prompts, runtime settings, and hooks through
  `WORKFLOW.md`.

This allows us to evolve providers and trackers without rewriting the orchestrator core.

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

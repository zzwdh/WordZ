# Workspace

Owns the main application workflow.

- `Models`: workspace-only value types and feature sets.
- `Protocols`: workspace-facing abstraction points.
- `Services`: repository, coordinators, dispatchers, scene builders, and workflow orchestration.
- `Stores`: runtime scene graph and session state.

If code is about opening corpora, switching tabs, rebuilding result nodes, or persisting workspace state, it likely belongs here.

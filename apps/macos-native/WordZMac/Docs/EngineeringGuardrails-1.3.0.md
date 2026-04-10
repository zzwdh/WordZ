# WordZMac Engineering Guardrails (Phase 5)

Date: 2026-04-08  
Scope: 1.3.0 structural hardening and regression guardrails

## Purpose

Phase 5 freezes the architectural and state-flow cleanup work into repeatable checks.

The goal is not to replace full `swift test`, but to give future feature work a fast gate that catches:

1. architectural backsliding
2. composition-root leakage
3. root-shell/state-sync regressions
4. obvious performance regressions on the no-op sync path

## Guard surfaces

### 1. Architecture guard

Command:

```bash
zsh Scripts/architecture-guard.sh
```

This checks:

- legacy `Services/` growth
- root-level `Models / ViewModels / Views` drift
- UI framework imports in non-UI domains
- composition concrete leakage outside `App`
- composition-root workflow mutation
- workspace-to-view coupling
- analysis/storage back-references into shell/UI services

### 2. Focused engineering guard

Command:

```bash
zsh Scripts/engineering-guard.sh
```

This runs:

1. `architecture-guard.sh`
2. focused suites that protect the current structural work:
   - `CompositionTests`
   - `SceneSyncPlanTests`
   - `RootContentSceneTests`
   - `EngineeringGuardrailTests`
   - `MainWorkspaceViewModelTests`

Use this before large refactors, before release preparation, and before landing changes that touch:

- `App/Composition`
- `RootContentView*`
- `MainWorkspaceViewModel*`
- `WorkspaceSceneGraph*`
- `WorkspaceFlowCoordinator*`

### 3. Lightweight performance baseline

The current baseline is intentionally conservative and smoke-level only.

Protected path:

- repeated no-op `settings` scene sync must not rebuild the root scene
- the same loop must stay within a bounded runtime envelope on the in-memory fake workspace setup

Current guard:

- [EngineeringGuardrailTests.swift](/Users/zouyuxuan/corpus-lite/apps/macos-native/WordZMac/Tests/WordZMacTests/EngineeringGuardrailTests.swift)

This is not a benchmark suite. Its purpose is to catch accidental O(n) or repeated rebuild regressions on a path that should stay effectively no-op.

## How to use it

### During normal feature work

Run:

```bash
zsh Scripts/engineering-guard.sh
```

### Before release or invasive refactors

Run:

```bash
zsh Scripts/engineering-guard.sh
swift test --package-path .
```

## Failure interpretation

### `architecture-guard.sh` fails

Meaning:

- the source tree broke a placement or dependency rule

Typical response:

- move the file or helper into the owning domain
- replace a concrete cross-layer reference with a protocol
- update the baseline only if the architecture decision is intentional

### `CompositionTests` fails

Meaning:

- composition root or runtime dependency assembly drifted

Typical response:

- move live dependency resolution back into `App/Composition`
- avoid letting `ViewModel` or `Workspace` types construct their own live collaborators

### `RootContentSceneTests` or `MainWorkspaceViewModelTests` fails

Meaning:

- root shell/state sync behavior regressed

Typical response:

- inspect `SceneSyncPlan`, `requestSceneSync`, shell callback suppression, and root-scene rebuild triggers

### `EngineeringGuardrailTests` fails

Meaning:

- a no-op sync path is rebuilding work or has become unexpectedly slow

Typical response:

- inspect root-scene/welcome-scene request caching
- inspect scene sync coalescing
- inspect callbacks that mutate shell/sidebar state during sync

## Rule of thumb

If a change forces updates to both `ArchitectureBaseline-1.3.0.md` and guard scripts, treat it as an explicit architecture decision, not a casual code move.

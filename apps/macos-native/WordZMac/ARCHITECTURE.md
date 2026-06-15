# WordZMac Architecture Contract

This file is the living contract for the native macOS app architecture. Keep it
small, current, and aligned with `Scripts/architecture-guard.sh`.

## Package Graph

`WordZMac` is the executable shell. It should stay thin and depend on
`WordZAppShell`.

`WordZAppShell` owns app bootstrap and connects feature modules to the core app.
It may depend on feature targets and platform targets, but should not contain
feature business logic.

`WordZWorkspaceCore` is the current migration bridge for the native app. It owns
the main workspace shell, shared scene models, native services, coordinators,
and most legacy source that has not yet moved into a narrower target.

`WordZWorkspaceFeature` owns feature-module activation and page factories for
workspace verticals that are being split out of core.

`WordZLibraryFeature` owns Library-module activation, the Library page factory,
and the Library window entry. `WordZAppShell` injects the Library page factory
into `NativeAppContainer` and injects the Library window content into
`WordZCoreAppScenes`; `WordZWorkspaceCore` may host the remaining Library bridge
views and workflows until they can move without reversing the dependency
direction.

`WordZWorkbenchUI`, `WordZWindowing`, `WordZAnalysis`, `WordZStorage`,
`WordZEngine`, `WordZHost`, `WordZExport`, `WordZDiagnostics`, and
`WordZShared` are the target boundaries the app is moving toward.
`WordZEngine` now owns native runtime path and JSON support, not a Node process
transport. New code should move into the narrowest target or source domain that
can own it without reaching back into the workspace shell.

## Source Ownership

`App/Composition` is the composition root. It assembles live dependencies and
page view-model bundles, but should not own workflow mutation or SwiftUI view
assembly.

`Models/Workspace` describes workspace navigation and feature metadata. The
workspace feature registry is data-only; it must not import SwiftUI or AppKit
and must not construct feature pages.

`Views/Workspace/WorkspaceFeatureFactory.swift` owns SwiftUI feature page
assembly for the main workspace route surface. Adding a workspace page should
update the feature registry metadata and this UI factory together.

`Workspace/Services` owns workspace orchestration, scene graph synchronization,
workflow services, and action dispatch. It should depend on protocols and scene
models rather than concrete App or Host UI types.

`Analysis` owns analysis engines, scene builders, filtering, pagination, and
analysis-specific support. It must not reach into workspace shell state,
windowing, dialogs, or host presentation services.

`Storage` owns persistence, corpus libraries, snapshots, and migrations. It
must not reach into workspace shell, App composition, or host UI services.

`Host` owns platform integrations such as update checks, dialogs, sharing,
notifications, quick look, and macOS window-facing services.

`Views` owns SwiftUI and AppKit bridge code. It may render state and send
actions, but business orchestration and persistence stay outside this layer.

`App/WordZMacApp.swift` owns the remaining top-level SwiftUI window scene
declarations. Removed standalone feature windows should not keep stale App
companion files or scene routes.

## Boundary Rules

Run `Scripts/architecture-guard.sh` before landing structure changes. Run
`Scripts/engineering-guard.sh` before landing shell, composition, scene-sync, or
feature-routing changes.

Do not add root-level Swift files under `Models`, `ViewModels`, or `Views`.
Use the existing first-level folders or update the architecture contract and
guard in the same change.

Do not introduce new production code under a legacy `Services` root. Prefer
the owning domain and its `Services`, `Support`, `Models`, `Protocols`,
`Stores`, `Builders`, `State`, or `Transport` subfolder.

Keep `App/Composition` assembly-only. It may create services, stores, factories,
and page view-model bundles, but workflow state mutation belongs in workspace
services or coordinators.

Keep workspace feature metadata and SwiftUI page assembly separate. Metadata
lives in `Models/Workspace/WorkspaceFeatureRegistry*.swift`; SwiftUI page
construction lives in `Views/Workspace/WorkspaceFeatureFactory.swift`.

Keep migration adapters explicit. When a persistence model, draft model, and
summary model represent the same workspace state, update them together and keep
the structural alignment tests green.

## Evolution Checkpoints

When extracting a source domain into its own SwiftPM target, first make the
source-domain imports obey the future target dependency direction. Then move the
files, update `Package.swift`, and extend the architecture guard with the new
boundary.

When adding a feature vertical, add metadata to the feature registry, route UI
assembly through `WorkspaceFeatureFactory`, expose page factories through the
feature module when needed, and cover route/order stability in tests.

When adding table behavior, prefer shared table scene models, descriptors, and
result snapshots over per-page table state. Pagination, sorting, column
visibility, empty state, loading state, and error state should remain reusable.

When changing workspace persistence, treat `WorkspaceStateDraft`,
`WorkspaceSnapshotSummary`, and `NativePersistedWorkspaceSnapshot` as a single
contract. Add migration tests before changing persisted shape.

When a boundary needs to change, update this file, `Scripts/architecture-guard.sh`,
and the engineering guard tests in the same commit.

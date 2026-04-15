# ViewModels

Owns screen and workflow state for the presentation layer.

- `Workspace/` owns shell-scoped view models and runtime dependency assembly helpers.
- `Pages/` owns analysis page view models.
- `Library/` owns library window and sidebar view models.
- `Settings/` owns settings-specific view models.
- View models should stay free of `AppKit` imports; route native behavior through host or workspace bridge services.
- Root-level `ViewModels/` should not contain production Swift files; keep new code inside one of the fixed subdirectories above.
- Keep extension splits thematic. Prefer `+Actions`, `+Persistence`, `+Scene`, and similar topic slices only when a file has real standalone meaning.
- Merge tiny one-helper fragments back into adjacent files instead of leaving permanently fragmented `+Something.swift` shards.

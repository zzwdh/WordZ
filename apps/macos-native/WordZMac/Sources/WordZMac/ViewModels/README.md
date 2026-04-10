# ViewModels

Owns screen and workflow state for the presentation layer.

- Page view models and shell view models belong here.
- View models should stay free of `AppKit` imports; route native behavior through host or workspace bridge services.
- Keep extension splits thematic. Prefer `+Actions`, `+Persistence`, `+Scene`, and similar topic slices only when a file has real standalone meaning.
- Merge tiny one-helper fragments back into adjacent files instead of leaving permanently fragmented `+Something.swift` shards.

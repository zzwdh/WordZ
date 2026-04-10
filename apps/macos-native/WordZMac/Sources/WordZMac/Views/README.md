# Views

Owns SwiftUI views and AppKit bridging views.

- `Workspace/` owns the main shell, sidebar, split-container bridge, and page routing.
- `Workbench/` owns reusable presentation scaffolds and the native table bridge under `Workbench/Table/`.
- `Windows/` owns auxiliary windows, settings, library management, update, help, and menu bar content.
- Keep business orchestration, persistence, and App composition out of this layer.

Do not move orchestration or persistence logic into views.

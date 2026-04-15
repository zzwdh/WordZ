# Host

Owns macOS-native integration points.

- `Protocols/` defines narrow host-facing seams that other domains may depend on without importing `AppKit`.
- Window, notification, sharing, quick look, dialogs, update checks, and task center services belong here.
- Clipboard and window-document coordination stay in Host so `Workspace` orchestration can avoid direct `AppKit` access.
- `Support` is reserved for host-only helpers such as build metadata or date formatting.

UI code should call host services instead of talking to AppKit directly when possible.

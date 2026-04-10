# Host

Owns macOS-native integration points.

- Window, notification, sharing, quick look, dialogs, update checks, and task center services belong here.
- `Support` is reserved for host-only helpers such as build metadata or date formatting.

UI code should call host services instead of talking to AppKit directly when possible.

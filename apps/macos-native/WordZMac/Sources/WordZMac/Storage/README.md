# Storage

Owns local persistence and file-backed state.

- `Library`: corpus manifests, corpus store, import/update/recycle persistence.
- `Workspace`: workspace snapshot persistence.
- `Support`: storage-specific helper protocols and database support.

Keep storage schema and file layout concerns inside this domain.

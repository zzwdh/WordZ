# Models

Owns presentation-facing shared models.

- Scene models, action enums, pagination structs, and lightweight value types belong here.
- Avoid placing service logic or persistence logic in this directory.

If a model is tightly coupled to one domain and not reused elsewhere, prefer that domain instead.

## Current subfolders

- `Actions`: page and shell action enums.
- `Scene`: scene snapshots and table-state models.
- `Workspace`: workspace shell/context snapshots.
- `Analysis`: analysis-facing model definitions and search/filter state.
- `Library`: corpus metadata and library-level patch models.
- `Host`: host-facing presentation models.
- `Table`: shared native-table descriptors.
- `Export`: text export document models.

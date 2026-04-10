# WordZMac Source Layout

WordZMac now organizes source code by domain first, then by UI layer.

## Primary domains

- `Analysis`: analysis engines, scene builders, page-state protocols, filtering and pagination support.
- `Workspace`: workspace repository, coordinators, scene graph, shell composition, and workflow orchestration.
- `Engine`: local engine transport, RPC support, engine-facing models and contracts.
- `Storage`: local corpus library persistence, workspace snapshots, and storage support.
- `Host`: macOS-native integrations such as updates, notifications, dialogs, quick look, sharing, and window state.
- `Export`: CSV/TXT/XLSX export and preview-file generation.
- `Diagnostics`: diagnostics bundle generation and redaction.
- `Shared`: cross-domain support that is truly reused across multiple domains.
- `App`: app entry points and composition root. Live dependency assembly belongs in `App/Composition`.
- `Models`, `ViewModels`, `Views`, `Resources`: presentation-layer types and assets.

## Placement rules

- Put new code in the narrowest owning domain instead of the root.
- Do not add new production files to `Services/`; treat it as legacy overflow only.
- Put cross-domain helpers in `Shared/Support` only when they are genuinely domain-neutral.
- Put analysis result builders in `Analysis/Builders`.
- Put workspace chrome, orchestration, repository, and result-node building in `Workspace/Services`.
- Put file IO and persistence in `Storage`, not in `Workspace`.
- Put macOS host APIs in `Host`, not in `Views` or `ViewModels`.

## Naming rules

- Primary type files use `TypeName.swift`.
- Responsibility slices use `TypeName+Concern.swift`.
- Domain subfolders should use role names such as `Services`, `Support`, `Models`, `Protocols`, `Stores`, `Builders`, `State`, and `Transport`.
- Page view models should keep the pattern `PageViewModel.swift`, `+Actions`, `+Persistence`, and `+Scene` when that split is useful.

## Editing rules

- Prefer moving code into an existing domain over creating a new root-level folder.
- If a new domain is needed, add a `README.md` for it in the same change.
- When moving files across domains, keep type names and public behavior stable unless the feature explicitly changes.

## Guard workflow

- Run `Scripts/architecture-guard.sh` before release and large refactors.
- Run `Scripts/engineering-guard.sh` for the fast structural gate before landing shell, composition, or scene-sync changes.
- `Models` must stay free of root-level Swift files.
- `ViewModels` and `Views` may only use the existing root-level type families; do not introduce new root stems there without updating the architecture baseline.
- Treat any new production file under `Services/` as a structural regression.
- `Analysis` must not reach back into workspace shell, scene graph, or host UI services.
- `Storage` must not reach into workspace shell or host UI services.
- `App/Composition` must remain assembly-only and should not mutate workflow state directly.

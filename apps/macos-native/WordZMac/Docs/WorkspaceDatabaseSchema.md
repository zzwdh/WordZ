# Workspace Database Schema

## Overview

`workspace.db` is the central persistence store for workspace-scoped state. It replaces the previous spread of JSON files and is the only runtime source of truth for persisted workspace data.

The database is configured with:

- `PRAGMA foreign_keys=ON`
- `PRAGMA journal_mode=WAL`
- `PRAGMA synchronous=NORMAL`
- `PRAGMA busy_timeout=5000`

## Tables

### `schema_migrations`

Tracks additive schema changes applied to `workspace.db`.

| Column | Type | Notes |
| --- | --- | --- |
| `version` | `INTEGER PRIMARY KEY` | Monotonic schema version |
| `applied_at` | `TEXT NOT NULL` | ISO-8601 timestamp |
| `description` | `TEXT NOT NULL` | Human-readable migration note |

### `storage_meta`

Stores operational flags for storage bootstrap and migration.

| Column | Type | Notes |
| --- | --- | --- |
| `key` | `TEXT PRIMARY KEY` | Metadata key |
| `value` | `TEXT NOT NULL` | Metadata value |

### `workspace_snapshot`

Single-row table for the persisted workspace draft.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `INTEGER PRIMARY KEY CHECK (id = 1)` | Singleton row |
| `payload_json` | `TEXT NOT NULL` | Full `NativePersistedWorkspaceSnapshot` payload |
| `updated_at` | `TEXT NOT NULL` | ISO-8601 timestamp |

### `ui_settings`

Single-row table for persisted UI settings.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `INTEGER PRIMARY KEY CHECK (id = 1)` | Singleton row |
| `payload_json` | `TEXT NOT NULL` | Full `NativePersistedUISettings` payload |
| `updated_at` | `TEXT NOT NULL` | ISO-8601 timestamp |

### `analysis_preset`

Stores saved analysis presets with searchable hot fields and the original payload.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `TEXT PRIMARY KEY` | Preset id |
| `name` | `TEXT NOT NULL` | Display name |
| `created_at` | `TEXT NOT NULL` | ISO-8601 timestamp |
| `updated_at` | `TEXT NOT NULL` | ISO-8601 timestamp |
| `position` | `INTEGER NOT NULL DEFAULT 0` | Stable ordering |
| `payload_json` | `TEXT NOT NULL` | Full `NativeAnalysisPresetRecord` payload |

### `keyword_saved_list`

Stores saved keyword lists.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `TEXT PRIMARY KEY` | Saved list id |
| `name` | `TEXT NOT NULL` | Display name |
| `updated_at` | `TEXT NOT NULL` | ISO-8601 timestamp |
| `position` | `INTEGER NOT NULL DEFAULT 0` | Stable ordering |
| `payload_json` | `TEXT NOT NULL` | Full `KeywordSavedList` payload |

### `concordance_saved_set`

Stores persisted KWIC and concordance saved sets.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `TEXT PRIMARY KEY` | Saved set id |
| `name` | `TEXT NOT NULL` | Display name |
| `kind` | `TEXT NOT NULL` | `kwic`, `collocate`, etc. |
| `updated_at` | `TEXT NOT NULL` | ISO-8601 timestamp |
| `position` | `INTEGER NOT NULL DEFAULT 0` | Stable ordering |
| `payload_json` | `TEXT NOT NULL` | Full `ConcordanceSavedSet` payload |

### `evidence_item`

Stores evidence workbench items.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `TEXT PRIMARY KEY` | Item id |
| `corpus_id` | `TEXT NOT NULL` | Source corpus id |
| `sentence_id` | `INTEGER NOT NULL` | Source sentence id |
| `updated_at` | `TEXT NOT NULL` | ISO-8601 timestamp |
| `position` | `INTEGER NOT NULL DEFAULT 0` | Stable ordering |
| `payload_json` | `TEXT NOT NULL` | Full `EvidenceItem` payload |

### `sentiment_review_sample`

Stores sentiment review decisions and notes.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `TEXT PRIMARY KEY` | Sample id |
| `match_key` | `TEXT NOT NULL` | Stable dedupe key |
| `updated_at` | `TEXT NOT NULL` | ISO-8601 timestamp |
| `backend_kind` | `TEXT NOT NULL` | Analyzer backend |
| `domain_pack_id` | `TEXT NOT NULL` | Domain pack id |
| `position` | `INTEGER NOT NULL DEFAULT 0` | Stable ordering |
| `payload_json` | `TEXT NOT NULL` | Full `SentimentReviewSample` payload |

## Migration Strategy

- Startup ensures the schema exists before any read or write.
- Default singleton rows for `workspace_snapshot` and `ui_settings` are seeded on first initialization.
- Runtime persistence reads and writes only `workspace.db`.

## Operational Notes

- Diagnostics export emits database-derived snapshots as `workspace-snapshot.json` and `ui-settings.json`; it no longer depends on legacy workspace JSON files.
- Library backup and restore treat `workspace.db` as a first-class central database alongside `library.db`.

# wordz-engine-js

`wordz-engine-js` is the Windows-native sidecar engine for WordZ.

## Responsibilities

- Reuse the current JS corpus logic from the existing app
- Provide JSON-RPC over stdio to the native Windows shell
- Keep compatibility with the current `WordZ` user data directory for:
  - corpus library
  - recycle bin
  - backup / restore / repair
  - diagnostics export
- Persist native-shell workspace state in `native-state/`

## Current scope

- `app.*`
- `library.*`
- `workspace.*`
- `diagnostics.*`
- `analysis.*`
- `update.*` placeholder responses

## Local validation

From the repo root:

```bash
npm run native:engine:check
npm run native:engine:test
```

## Notes

- This package is intentionally framework-free.
- It directly imports the current repo root modules so the Windows native rewrite can reuse the existing analysis/storage stack before any deeper engine rewrite.

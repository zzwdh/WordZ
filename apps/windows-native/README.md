# WordZ Windows Native

This directory contains the Windows-native rewrite of WordZ.

## Direction

- Windows moves to a native shell
- macOS stays on the current Electron app
- the shared analysis/storage logic is reused through a local Node.js sidecar engine

## Stack

- WinUI 3
- .NET 8
- Windows App SDK
- Node.js 24 sidecar engine from `/Users/zouyuxuan/corpus-lite/packages/wordz-engine-js`

## Repository layout

- `/Users/zouyuxuan/corpus-lite/apps/windows-native/WordZ.Windows`
  WinUI 3 desktop shell
- `/Users/zouyuxuan/corpus-lite/packages/wordz-contracts`
  JSON-RPC methods, events and error codes shared with the engine
- `/Users/zouyuxuan/corpus-lite/packages/wordz-engine-js`
  stdio JSON-RPC engine that reuses the current JS corpus modules

## Goals

- Replace the Windows Electron UI completely
- Stop relying on Chromium for the Windows workbench
- Preserve the current WordZ data layout where practical:
  - `corpus-library`
  - recycle bin
  - backups
  - diagnostics exports
- Move Windows interaction toward native:
  - CommandBar and NavigationView
  - DataGrid virtualization
  - dialogs / notifications / Jump List / taskbar integrations

## Current implementation status

- WinUI shell scaffolding exists
- `EngineClient` talks to the Node sidecar over stdio JSON-RPC
- a first `MainWindowViewModel` is present
- native shell service and update service placeholders are present
- the JS engine package has syntax checks and tests
- the WinUI project is configured to copy a JS runtime mirror into the app output so the sidecar can resolve the current shared corpus modules
  This is intentionally heavier than the final target, but it makes the first native Windows milestone runnable before any deeper engine bundling work.

## Local build environment

- Windows 11
- Visual Studio 2022 or newer
- .NET 8 SDK
- Windows App SDK workload
- Node.js 24.x

## First Windows-side tasks

1. Open `WordZ.Windows.csproj` in Visual Studio on Windows
2. Restore NuGet packages
3. Verify `packages/wordz-engine-js/src/index.mjs` is copied into the app output
   The current scaffold now mirrors `packages/wordz-engine-js`, `packages/wordz-contracts`, the shared JS corpus modules and `node_modules` into the WinUI output tree.
4. Run the shell and confirm `app.getInfo` / `library.list` succeed
5. Start replacing placeholder tabs with native pages

## Known limitation right now

This repo is currently being edited from macOS, so the WinUI project has been scaffolded but not compiled locally here.

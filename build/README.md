Place packaging resources here when we add branded release assets.

Expected filenames:
- `icon.icns` for macOS builds
- `icon.ico` for Windows builds
- `icon.png` for Linux builds or generic fallbacks

Until those files are added, `electron-builder` will use the default Electron app icon.

Auto update:
- `WordZ` now defaults to a `GitHub Releases` update provider.
- The release workflow at `/Users/zouyuxuan/corpus-lite/.github/workflows/github-release.yml` publishes macOS and Windows builds to the current GitHub repository.
- The workflow injects `WORDZ_AUTO_UPDATE_GITHUB_OWNER` and `WORDZ_AUTO_UPDATE_GITHUB_REPO` into the packaged app, so end users can check updates without extra local configuration.
- For manual release publishing, set `GITHUB_TOKEN` or `GH_TOKEN`, then run one of:
  - `npm run release:github`
  - `npm run release:github:mac`
  - `npm run release:github:win`
- Manual publishing also accepts:
  - `WORDZ_AUTO_UPDATE_GITHUB_OWNER`
  - `WORDZ_AUTO_UPDATE_GITHUB_REPO`
  - `WORDZ_AUTO_UPDATE_GITHUB_PRIVATE`
- Recommended release flow:
  1. Update `/Users/zouyuxuan/corpus-lite/package.json` version.
  2. Push a tag like `v1.0.1`, or manually trigger the GitHub Release workflow.
  3. Let GitHub Actions publish `.exe`, `.zip`, `.dmg`, `latest.yml`, `latest-mac.yml`, and `.blockmap` files to the release.
- macOS production auto update still requires a signed app; unsigned local builds can exercise the UI but are not production-ready for end users.

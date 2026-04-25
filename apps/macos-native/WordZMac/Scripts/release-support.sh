#!/bin/zsh

release_support_node_bin() {
  local node_bin="${WORDZ_MAC_NODE_BIN:-$(command -v node || true)}"
  if [[ -z "$node_bin" ]]; then
    echo "node not found. Set WORDZ_MAC_NODE_BIN or install Node.js." >&2
    return 1
  fi
  echo "$node_bin"
}

release_support_script_dir() {
  if [[ -n "${SCRIPT_DIR:-}" ]]; then
    echo "$SCRIPT_DIR"
    return
  fi
  cd "$(dirname "$0")" && pwd
}

release_support_app_root() {
  local script_dir
  script_dir="$(release_support_script_dir)"
  cd "$script_dir/.." && pwd
}

release_support_repo_root() {
  local app_root
  app_root="$(release_support_app_root)"
  cd "$app_root/../../.." && pwd
}

release_support_package_json_path() {
  echo "$(release_support_repo_root)/package.json"
}

release_support_dist_dir() {
  echo "${WORDZ_MAC_DIST_DIR:-$(release_support_app_root)/dist-native}"
}

release_support_current_version() {
  local package_json
  local node_bin
  package_json="$(release_support_package_json_path)"
  node_bin="$(release_support_node_bin)"
  "$node_bin" -p "require('$package_json').version"
}

release_support_release_tag() {
  local version="${1:-$(release_support_current_version)}"
  echo "${WORDZ_MAC_RELEASE_TAG:-v$version}"
}

release_support_release_notes_path() {
  local version="${1:-$(release_support_current_version)}"
  echo "${WORDZ_MAC_RELEASE_NOTES_PATH:-$(release_support_app_root)/Docs/ReleaseNotes-$version.md}"
}

release_support_release_title_from_notes() {
  local notes_path="$1"
  if [[ -f "$notes_path" ]]; then
    /usr/bin/awk '/^# / { sub(/^# /, ""); print; exit }' "$notes_path"
  fi
}

release_support_resolve_latest_manifest() {
  local dist_dir="${1:-$(release_support_dist_dir)}"
  /bin/ls -t "$dist_dir"/*.manifest.json 2>/dev/null | /usr/bin/head -n 1
}

release_support_resolve_manifest_path() {
  local input_path="${1:-}"
  if [[ -z "$input_path" ]]; then
    input_path="$(release_support_dist_dir)"
  fi

  if [[ -d "$input_path" ]]; then
    local latest_manifest
    latest_manifest="$(release_support_resolve_latest_manifest "$input_path")"
    if [[ -z "$latest_manifest" ]]; then
      echo "no manifest found in $input_path" >&2
      return 1
    fi
    echo "$latest_manifest"
    return 0
  fi

  if [[ "$input_path" == *.checksums.txt ]]; then
    echo "${input_path%.checksums.txt}.manifest.json"
    return 0
  fi

  echo "$input_path"
}

release_support_dist_child_path() {
  local dist_dir="$1"
  local entry_name="${2//$'\r'/}"
  local label="${3:-release asset}"

  if [[ -z "$entry_name" ]]; then
    echo "$label name is empty." >&2
    return 1
  fi

  if [[ "$entry_name" == "." || "$entry_name" == ".." ]]; then
    echo "$label name is invalid: $entry_name" >&2
    return 1
  fi

  if [[ "$entry_name" != "${entry_name:t}" || "$entry_name" == *"/"* || "$entry_name" == *"\\"* ]]; then
    echo "$label must stay within ${dist_dir:t}: $entry_name" >&2
    return 1
  fi

  echo "$dist_dir/$entry_name"
}

release_support_read_manifest_value() {
  local manifest_path="$1"
  local key="$2"
  /usr/bin/plutil -extract "$key" raw -o - "$manifest_path" 2>/dev/null
}

release_support_repository_slug() {
  local package_json
  local node_bin
  package_json="$(release_support_package_json_path)"
  node_bin="$(release_support_node_bin)"
  "$node_bin" -e '
const fs = require("fs");
const pkg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const candidates = [
  pkg.repository && pkg.repository.url,
  pkg.repository && pkg.repository.path,
  pkg.bugs && pkg.bugs.url,
  pkg.homepage
];
for (const value of candidates) {
  if (!value) continue;
  const normalized = String(value)
    .trim()
    .replace(/^git\+/, "")
    .replace(/\.git$/, "");
  const match = normalized.match(/github\.com[:/]+([^/]+)\/([^/]+?)(?:\/|$)/i);
  if (match) {
    process.stdout.write(match[1] + "/" + match[2]);
    process.exit(0);
  }
}
' "$package_json" 2>/dev/null || true
}

release_support_release_page_url() {
  local version="${1:-$(release_support_current_version)}"
  local repository_slug
  repository_slug="$(release_support_repository_slug)"
  if [[ -n "$repository_slug" ]]; then
    echo "https://github.com/$repository_slug/releases/tag/$(release_support_release_tag "$version")"
  fi
}

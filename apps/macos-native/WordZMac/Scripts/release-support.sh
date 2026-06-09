#!/bin/zsh

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

release_support_version_path() {
  echo "${WORDZ_MAC_VERSION_FILE:-$(release_support_app_root)/VERSION}"
}

release_support_release_highlights_path() {
  echo "${WORDZ_MAC_RELEASE_HIGHLIGHTS_PATH:-$(release_support_app_root)/RELEASE_HIGHLIGHTS.md}"
}

release_support_dist_dir() {
  echo "${WORDZ_MAC_DIST_DIR:-$(release_support_app_root)/dist-native}"
}

release_support_current_version() {
  local version_file
  if [[ -n "${WORDZ_MAC_VERSION:-}" ]]; then
    echo "$WORDZ_MAC_VERSION"
    return
  fi

  version_file="$(release_support_version_path)"
  if [[ -f "$version_file" ]]; then
    /usr/bin/awk 'NF { print $1; exit }' "$version_file"
    return
  fi

  echo "native-preview"
}

release_support_release_channel() {
  echo "${WORDZ_MAC_RELEASE_CHANNEL:-stable}"
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

release_support_release_highlight_count() {
  local highlights_path="${1:-$(release_support_release_highlights_path)}"
  if [[ ! -f "$highlights_path" ]]; then
    echo "0"
    return
  fi
  /usr/bin/awk '/^- / { count += 1 } END { print count + 0 }' "$highlights_path"
}

release_support_json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\r'/}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\t'/\\t}"
  echo "$value"
}

release_support_release_highlights_json() {
  local highlights_path="${1:-$(release_support_release_highlights_path)}"
  local first=1
  local line
  local highlight

  echo "["
  if [[ -f "$highlights_path" ]]; then
    while IFS= read -r line; do
      if [[ "$line" == "- "* ]]; then
        highlight="${line#- }"
        if [[ "$first" -eq 0 ]]; then
          echo ","
        fi
        printf '    "%s"' "$(release_support_json_escape "$highlight")"
        first=0
      fi
    done < "$highlights_path"
  fi
  echo
  echo "  ]"
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
  local remote
  local owner
  local repo
  local rest

  if [[ -n "${WORDZ_MAC_REPOSITORY:-}" ]]; then
    echo "$WORDZ_MAC_REPOSITORY"
    return
  fi

  remote="$(git -C "$(release_support_repo_root)" config --get remote.origin.url 2>/dev/null || true)"
  remote="${remote#git+}"
  if [[ "$remote" == git@github.com:* ]]; then
    remote="${remote#git@github.com:}"
  elif [[ "$remote" == https://github.com/* ]]; then
    remote="${remote#https://github.com/}"
  elif [[ "$remote" == http://github.com/* ]]; then
    remote="${remote#http://github.com/}"
  fi
  remote="${remote%.git}"

  owner="${remote%%/*}"
  rest="${remote#*/}"
  repo="${rest%%/*}"
  if [[ -n "$owner" && -n "$repo" && "$rest" != "$remote" ]]; then
    echo "$owner/$repo"
  fi
}

release_support_release_page_url() {
  local version="${1:-$(release_support_current_version)}"
  local repository_slug
  repository_slug="$(release_support_repository_slug)"
  if [[ -n "$repository_slug" ]]; then
    echo "https://github.com/$repository_slug/releases/tag/$(release_support_release_tag "$version")"
  fi
}

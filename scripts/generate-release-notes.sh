#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/generate-release-notes.sh <tag> <output-path>

Example:
  ./scripts/generate-release-notes.sh v202604.5 release-notes.md
EOF
}

if [[ $# -ne 2 ]]; then
  usage >&2
  exit 1
fi

tag="$1"
output_path="$2"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
changelog_path="$repo_root/CHANGELOG.md"

mkdir -p "$(dirname "$output_path")"

extract_from_changelog() {
  local target_tag="$1"
  local changelog="$2"

  awk -v tag="$target_tag" '
    BEGIN {
      capture = 0
      found = 0
    }
    $0 ~ ("^## " tag "([[:space:]]-|$)") {
      capture = 1
      found = 1
      print
      next
    }
    capture && $0 ~ /^## / {
      exit
    }
    capture {
      print
    }
    END {
      if (found == 0) {
        exit 1
      }
    }
  ' "$changelog"
}

generate_from_git_history() {
  local target_tag="$1"
  local today
  local previous_tag
  local range
  local commit_lines

  today="$(date -u +%F)"
  previous_tag="$(git -C "$repo_root" tag --sort=-version:refname | awk -v current="$target_tag" '$0 != current { print; exit }')"

  if [[ -n "$previous_tag" ]]; then
    range="${previous_tag}..${target_tag}"
  else
    range="$target_tag"
  fi

  commit_lines="$(git -C "$repo_root" log --no-merges --format='- %s (%h)' "$range")"

  {
    printf '## %s - %s\n\n' "$target_tag" "$today"
    if [[ -n "$previous_tag" ]]; then
      printf '_Auto-generated from commits since `%s`._\n\n' "$previous_tag"
    else
      printf '_Auto-generated from the tagged commit history._\n\n'
    fi

    if [[ -n "$commit_lines" ]]; then
      printf '%s\n' "$commit_lines"
    else
      printf -- '- No user-facing commits were found for this tag range.\n'
    fi
  }
}

if [[ -f "$changelog_path" ]] && extract_from_changelog "$tag" "$changelog_path" > "$output_path"; then
  printf 'Release notes generated from CHANGELOG.md for %s\n' "$tag"
else
  generate_from_git_history "$tag" > "$output_path"
  printf 'Release notes auto-generated from git history for %s\n' "$tag"
fi
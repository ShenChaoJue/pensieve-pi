#!/usr/bin/env bash

set -euo pipefail

UPSTREAM_URL="https://github.com/kingkongshot/Pensieve"
REF="${1:-main}"

if [ "$#" -gt 1 ]; then
  echo "Usage: $0 [ref]" >&2
  exit 2
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
LOCAL_SRC="$REPO_ROOT/skills/pensieve/.src"
LOCAL_SKILL="$REPO_ROOT/skills/pensieve/SKILL.md"

if [ ! -d "$LOCAL_SRC" ]; then
  echo "ERROR: local source directory not found: $LOCAL_SRC" >&2
  exit 2
fi
if [ ! -f "$LOCAL_SRC/manifest.json" ]; then
  echo "ERROR: local manifest not found: $LOCAL_SRC/manifest.json" >&2
  exit 2
fi

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/pensieve-upstream.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT
UPSTREAM_REPO="$TMP_ROOT/upstream"
UPSTREAM_SRC="$UPSTREAM_REPO/.src"
UPSTREAM_SKILL="$UPSTREAM_REPO/SKILL.md"
CLONE_LOG="$TMP_ROOT/clone.log"

if ! git clone --depth 1 -b "$REF" "$UPSTREAM_URL" "$UPSTREAM_REPO" >"$CLONE_LOG" 2>&1; then
  echo "ERROR: could not shallow-clone upstream ref '$REF' from $UPSTREAM_URL" >&2
  sed 's/^/  /' "$CLONE_LOG" >&2
  exit 2
fi
if [ ! -d "$UPSTREAM_SRC" ]; then
  echo "ERROR: upstream ref '$REF' does not contain .src/" >&2
  exit 2
fi
if [ ! -f "$UPSTREAM_SRC/manifest.json" ]; then
  echo "ERROR: upstream ref '$REF' does not contain .src/manifest.json" >&2
  exit 2
fi

manifest_version() {
  sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" | head -n 1
}

UPSTREAM_VERSION=$(manifest_version "$UPSTREAM_SRC/manifest.json")
LOCAL_VERSION=$(manifest_version "$LOCAL_SRC/manifest.json")
if [ -z "$UPSTREAM_VERSION" ]; then
  echo "ERROR: could not parse version from upstream .src/manifest.json" >&2
  exit 2
fi
if [ -z "$LOCAL_VERSION" ]; then
  echo "ERROR: could not parse version from local .src/manifest.json" >&2
  exit 2
fi

# Run the requested recursive comparison once, then build a stable categorized
# report from the same trees instead of parsing platform-specific diff wording.
RECURSIVE_DIFF="$TMP_ROOT/recursive.diff"
recursive_status=0
diff -r "$UPSTREAM_SRC" "$LOCAL_SRC" >"$RECURSIVE_DIFF" 2>&1 || recursive_status=$?
if [ "$recursive_status" -gt 1 ]; then
  echo "ERROR: recursive diff failed" >&2
  sed 's/^/  /' "$RECURSIVE_DIFF" >&2
  exit 2
fi

UPSTREAM_FILES="$TMP_ROOT/upstream-files"
LOCAL_FILES="$TMP_ROOT/local-files"
ALL_FILES="$TMP_ROOT/all-files"
(
  cd "$UPSTREAM_SRC"
  find . -type f -print | sed 's#^\./##' | LC_ALL=C sort
) >"$UPSTREAM_FILES"
(
  cd "$LOCAL_SRC"
  find . -type f -print | sed 's#^\./##' | LC_ALL=C sort
) >"$LOCAL_FILES"
LC_ALL=C sort -u "$UPSTREAM_FILES" "$LOCAL_FILES" >"$ALL_FILES"

MISSING_DETAILS="$TMP_ROOT/missing-details"
EXTRA_DETAILS="$TMP_ROOT/extra-details"
PATCHED_DETAILS="$TMP_ROOT/patched-details"
DOCS_DETAILS="$TMP_ROOT/docs-details"
PI_ADAPTED_DETAILS="$TMP_ROOT/pi-adapted-details"
UNEXPECTED_DETAILS="$TMP_ROOT/unexpected-details"
: >"$MISSING_DETAILS"
: >"$EXTRA_DETAILS"
: >"$PATCHED_DETAILS"
: >"$DOCS_DETAILS"
: >"$PI_ADAPTED_DETAILS"
: >"$UNEXPECTED_DETAILS"

missing_count=0
extra_count=0
patched_count=0
docs_count=0
pi_adapted_count=0
unexpected_count=0
content_count=0

changed_line_count() {
  local upstream_file=$1
  local local_file=$2
  local file_diff="$TMP_ROOT/file.diff"
  local status=0

  diff -u "$upstream_file" "$local_file" >"$file_diff" 2>/dev/null || status=$?
  if [ "$status" -gt 1 ]; then
    echo "ERROR: could not diff '$upstream_file' and '$local_file'" >&2
    exit 2
  fi

  # Count added/removed content lines, excluding the two unified-diff headers.
  awk 'NR > 2 && (substr($0, 1, 1) == "+" || substr($0, 1, 1) == "-") { count++ } END { print count + 0 }' "$file_diff"
}

record_content_difference() {
  local display_path=$1
  local relative_path=$2
  local upstream_file=$3
  local local_file=$4
  local changed_lines

  changed_lines=$(changed_line_count "$upstream_file" "$local_file")
  content_count=$((content_count + 1))

  case "$relative_path" in
    scripts/maintain-auto-memory.sh|scripts/scan-structure.sh|scripts/sync-instructions.sh)
      printf '  - [patched] %s (%s changed lines)\n' "$display_path" "$changed_lines" >>"$PATCHED_DETAILS"
      patched_count=$((patched_count + 1))
      ;;
    *.md)
      printf '  - [docs-adapted] %s (%s changed lines)\n' "$display_path" "$changed_lines" >>"$DOCS_DETAILS"
      docs_count=$((docs_count + 1))
      ;;
    core/doctor_engine.py|core/schema.json)
      printf '  - [pi-adapted] %s (%s changed lines)\n' "$display_path" "$changed_lines" >>"$PI_ADAPTED_DETAILS"
      pi_adapted_count=$((pi_adapted_count + 1))
      ;;
    *)
      printf '  - [UNEXPECTED] %s (%s changed lines)\n' "$display_path" "$changed_lines" >>"$UNEXPECTED_DETAILS"
      unexpected_count=$((unexpected_count + 1))
      ;;
  esac
}

while IFS= read -r relative_path; do
  [ -n "$relative_path" ] || continue
  upstream_file="$UPSTREAM_SRC/$relative_path"
  local_file="$LOCAL_SRC/$relative_path"
  display_path=".src/$relative_path"

  if [ ! -f "$local_file" ]; then
    printf '  - %s\n' "$display_path" >>"$MISSING_DETAILS"
    missing_count=$((missing_count + 1))
  elif [ ! -f "$upstream_file" ]; then
    printf '  - %s\n' "$display_path" >>"$EXTRA_DETAILS"
    extra_count=$((extra_count + 1))
  elif ! cmp -s "$upstream_file" "$local_file"; then
    record_content_difference "$display_path" "$relative_path" "$upstream_file" "$local_file"
  fi
done <"$ALL_FILES"

# SKILL.md lives outside .src/, so compare it explicitly.
if [ -f "$UPSTREAM_SKILL" ] && [ -f "$LOCAL_SKILL" ]; then
  if ! cmp -s "$UPSTREAM_SKILL" "$LOCAL_SKILL"; then
    record_content_difference "SKILL.md" "SKILL.md" "$UPSTREAM_SKILL" "$LOCAL_SKILL"
  fi
elif [ -f "$UPSTREAM_SKILL" ]; then
  printf '  - SKILL.md\n' >>"$MISSING_DETAILS"
  missing_count=$((missing_count + 1))
elif [ -f "$LOCAL_SKILL" ]; then
  printf '  - SKILL.md\n' >>"$EXTRA_DETAILS"
  extra_count=$((extra_count + 1))
fi

if [ "$missing_count" -gt 0 ] || [ "$extra_count" -gt 0 ] || [ "$unexpected_count" -gt 0 ]; then
  conclusion="NEEDS-MERGE"
  exit_status=1
elif [ "$content_count" -gt 0 ]; then
  conclusion="EXPECTED-ADAPTATIONS-ONLY"
  exit_status=0
else
  conclusion="IN-SYNC"
  exit_status=0
fi

print_details() {
  local file=$1
  if [ -s "$file" ]; then
    cat "$file"
  else
    echo "  - (none)"
  fi
}

printf 'DRIFT: %s\n' "$conclusion"
printf 'Version: upstream v%s vs local v%s (ref: %s)\n' "$UPSTREAM_VERSION" "$LOCAL_VERSION" "$REF"
printf '\nSummary:\n'
printf '  Local missing (upstream added): %s\n' "$missing_count"
printf '  Local extra (upstream deleted): %s\n' "$extra_count"
printf '  Content differences: %s\n' "$content_count"
printf '    [patched]: %s\n' "$patched_count"
printf '    [docs-adapted]: %s\n' "$docs_count"
printf '    [pi-adapted]: %s\n' "$pi_adapted_count"
printf '    [UNEXPECTED]: %s\n' "$unexpected_count"
printf '\nLocal missing (upstream added):\n'
print_details "$MISSING_DETAILS"
printf '\nLocal extra (upstream deleted):\n'
print_details "$EXTRA_DETAILS"
printf '\nKnown port patches:\n'
print_details "$PATCHED_DETAILS"
printf '\nDocumentation adaptations (including root SKILL.md):\n'
print_details "$DOCS_DETAILS"
printf '\nPi adaptations:\n'
print_details "$PI_ADAPTED_DETAILS"
printf '\nUnexpected content differences:\n'
print_details "$UNEXPECTED_DETAILS"

exit "$exit_status"

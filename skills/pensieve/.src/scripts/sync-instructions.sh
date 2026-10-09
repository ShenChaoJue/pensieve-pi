#!/bin/bash
# Sync short Pensieve routing guidance into project instruction files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

START_MARKER="<!-- pensieve:instructions:start -->"
END_MARKER="<!-- pensieve:instructions:end -->"
GLOBAL_START_MARKER="<!-- pensieve:global-instructions:start -->"
GLOBAL_END_MARKER="<!-- pensieve:global-instructions:end -->"
TARGET_MODE="all"
CUSTOM_TARGETS=()
GLOBAL_MODE=0

usage() {
  cat <<'USAGE'
Usage:
  sync-instructions.sh [options]

Options:
  --global          Update the global Pi instruction file instead of project instructions
  --target <mode>   all | auto | agents. Default: all
                    all    updates/creates AGENTS.md
                    auto   updates existing AGENTS.md, or creates it if it does not exist
                    agents updates/creates AGENTS.md
  --file <path>     Update a specific instruction file. May be repeated.
  -h, --help        Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)
      GLOBAL_MODE=1
      shift
      ;;
    --target)
      [[ $# -ge 2 ]] || { echo "Missing value for --target" >&2; exit 1; }
      TARGET_MODE="$2"
      shift 2
      ;;
    --file)
      [[ $# -ge 2 ]] || { echo "Missing value for --file" >&2; exit 1; }
      CUSTOM_TARGETS+=("$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

pipeline_exists() {
  [[ -f "$PIPELINES_DIR/$1.md" ]]
}

build_instruction_block() {
  local routes=()

  if pipeline_exists "run-when-committing"; then
    routes+=("- Commit requests (\`commit\`, \`git commit\`): use \`.pensieve/pipelines/run-when-committing.md\`. Check staged diff, decide whether reusable insight should be captured, then make atomic commits.")
  fi

  if pipeline_exists "run-when-refactoring"; then
    routes+=("- Refactor requests (\`refactor\`, \`large refactor\`, \`split code\`): use \`.pensieve/pipelines/run-when-refactoring.md\`. Confirm the real problem, fix upstream data authority first, split large work into 2-3 user-visible steps, delete old paths when new paths work, and avoid compatibility/fallback branches.")
  fi

  if pipeline_exists "run-when-reviewing-code"; then
    routes+=("- Review requests (\`review\`, \`code review\`, \`inspect code\`): use \`.pensieve/pipelines/run-when-reviewing-code.md\`. Start from git history and changed hot spots, verify candidate issues, and report only high-signal findings with evidence and file locations.")
  fi

  if [[ "${#routes[@]}" -eq 0 ]]; then
    echo "No supported pipeline files found in: $PIPELINES_DIR" >&2
    echo "Expected run-when-committing.md, run-when-refactoring.md, or run-when-reviewing-code.md." >&2
    return 1
  fi

  cat <<EOF
$START_MARKER
## How To Use Pensieve

Use \`.pensieve/\` as the first source of architectural intent.

- \`maxims/\` are active engineering rules.
- \`decisions/\` are active project decisions.
- \`knowledge/\` explains boundary maps and debugging paths.
- \`pipelines/\` gives executable workflows.

Use these project pipelines directly when trigger words match; do not rediscover them through skills first.

$(printf '%s\n' "${routes[@]}")
$END_MARKER
EOF
}

trim_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "$value"
}

entry_title() {
  local path="$1"
  local line value first_line=1 in_frontmatter=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    if [[ "$first_line" -eq 1 ]]; then
      first_line=0
      if [[ "$line" == "---" ]]; then
        in_frontmatter=1
        continue
      fi
      break
    fi
    if [[ "$in_frontmatter" -eq 1 && "$line" == "---" ]]; then
      break
    fi
    if [[ "$in_frontmatter" -eq 1 && "$line" == title:* ]]; then
      value="$(trim_whitespace "${line#title:}")"
      value="${value#\"}"
      value="${value%\"}"
      value="${value#\'}"
      value="${value%\'}"
      if [[ -n "$value" ]]; then
        printf '%s\n' "$value"
        return 0
      fi
    fi
  done < "$path"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    if [[ "$line" == "# "* ]]; then
      trim_whitespace "${line#\# }"
      return 0
    fi
  done < "$path"

  value="$(basename "$path")"
  printf '%s\n' "${value%.md}"
}

global_entry_cap() {
  local category="$1"
  local schema_file="$SCRIPT_DIR/../core/schema.json"
  local py
  py="$(python_bin)" || {
    echo "Unable to read global entry caps: Python is required." >&2
    return 1
  }
  "$py" - "$schema_file" "$category" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as schema_file:
    schema = json.load(schema_file)
value = schema.get("global_root", {}).get("entry_caps", {}).get(sys.argv[2], 0)
print(value if isinstance(value, int) and value >= 0 else 0)
PY
}

build_global_instruction_block() {
  local global_data_root="$1"
  local maxims_cap pipelines_cap path count
  maxims_cap="$(global_entry_cap maxims)"
  pipelines_cap="$(global_entry_cap pipelines)"

  printf '%s\n' "$GLOBAL_START_MARKER"
  printf '%s\n\n' 'Maintained by `sync-instructions --global`; edit entries under the Pensieve global root, not this block.'
  printf '%s\n\n' '## Global Engineering Maxims (Pensieve)'
  count=0
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    [[ "$count" -lt "$maxims_cap" ]] || break
    printf -- '- %s\n' "$(entry_title "$path")"
    count=$((count + 1))
  done < <(find "$global_data_root/maxims" -maxdepth 1 -type f -name '*.md' 2>/dev/null | LC_ALL=C sort)
  if [[ "$count" -eq 0 ]]; then
    printf '%s\n' '- (none)'
  fi

  printf '\n%s\n\n' '## Global Pipelines (Pensieve)'
  count=0
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    [[ "$count" -lt "$pipelines_cap" ]] || break
    printf -- '- %s: `%s`\n' "$(entry_title "$path")" "$path"
    count=$((count + 1))
  done < <(find "$global_data_root/pipelines" -maxdepth 1 -type f -name '*.md' 2>/dev/null | LC_ALL=C sort)
  if [[ "$count" -eq 0 ]]; then
    printf '%s\n' '- (none)'
  fi
  printf '%s\n' "$GLOBAL_END_MARKER"
}

resolve_target_path() {
  local raw="$1"
  raw="$(to_posix_path "$raw")"
  if [[ "$raw" == /* ]]; then
    echo "$raw"
  else
    echo "$PROJECT_ROOT/$raw"
  fi
}

collect_targets() {
  local targets=()

  if [[ "${#CUSTOM_TARGETS[@]}" -gt 0 ]]; then
    local custom
    for custom in "${CUSTOM_TARGETS[@]}"; do
      targets+=("$(resolve_target_path "$custom")")
    done
    printf '%s\n' "${targets[@]}"
    return 0
  fi

  case "$TARGET_MODE" in
    all)
      targets+=("$PROJECT_ROOT/AGENTS.md")
      ;;
    auto)
      [[ -f "$PROJECT_ROOT/AGENTS.md" ]] && targets+=("$PROJECT_ROOT/AGENTS.md")
      if [[ "${#targets[@]}" -eq 0 ]]; then
        targets+=("$PROJECT_ROOT/AGENTS.md")
      fi
      ;;
    agents|agent)
      targets+=("$PROJECT_ROOT/AGENTS.md")
      ;;
    *)
      echo "Unsupported --target: $TARGET_MODE" >&2
      usage
      exit 1
      ;;
  esac

  printf '%s\n' "${targets[@]}"
}

sync_target_file() {
  local target="$1"
  local block_file="$2"
  local start_marker="$3"
  local end_marker="$4"
  local out_file existed start_count end_count

  mkdir -p "$(dirname "$target")"

  existed=0
  [[ -f "$target" ]] && existed=1

  if [[ "$existed" -eq 0 || ! -s "$target" ]]; then
    cp "$block_file" "$target"
    if [[ "$existed" -eq 0 ]]; then
      echo "created"
    else
      echo "updated"
    fi
    return 0
  fi

  start_count="$(grep -Fxc "$start_marker" "$target" || true)"
  end_count="$(grep -Fxc "$end_marker" "$target" || true)"

  if [[ "$start_count" -ne "$end_count" ]]; then
    echo "Malformed Pensieve instruction block in $target" >&2
    echo "Expected matching $start_marker and $end_marker markers." >&2
    return 1
  fi
  if [[ "$start_count" -gt 1 ]]; then
    echo "Malformed Pensieve instruction block in $target" >&2
    echo "Expected at most one $start_marker marker." >&2
    return 1
  fi

  out_file="$(mktemp)"
  if [[ "$start_count" -gt 0 ]]; then
    awk -v start="$start_marker" -v end="$end_marker" -v block_file="$block_file" '
      BEGIN {
        while ((getline line < block_file) > 0) {
          block = block line ORS
        }
        close(block_file)
        in_block = 0
      }
      $0 == start {
        printf "%s", block
        in_block = 1
        next
      }
      in_block {
        if ($0 == end) {
          in_block = 0
        }
        next
      }
      {
        print
      }
    ' "$target" > "$out_file"
  else
    cp "$target" "$out_file"
    printf '\n' >> "$out_file"
    cat "$block_file" >> "$out_file"
  fi

  mv "$out_file" "$target"
  echo "updated"
}

if [[ "$GLOBAL_MODE" -eq 1 ]]; then
  GLOBAL_ROOT="$(global_root)" || exit 1
  GLOBAL_ROOT="$(to_posix_path "$GLOBAL_ROOT")"
  if [[ ! -d "$GLOBAL_ROOT" ]]; then
    echo "Missing Pensieve global root: $GLOBAL_ROOT" >&2
    echo "Run init --global before syncing global instructions." >&2
    exit 1
  fi

  ensure_home
  GLOBAL_TARGET="${PENSIEVE_GLOBAL_INSTRUCTIONS_FILE:-$HOME/.pi/agent/AGENTS.md}"
  GLOBAL_TARGET="$(to_posix_path "$GLOBAL_TARGET")"
  BLOCK_FILE="$(mktemp)"
  build_global_instruction_block "$GLOBAL_ROOT" > "$BLOCK_FILE"
  status="$(sync_target_file "$GLOBAL_TARGET" "$BLOCK_FILE" "$GLOBAL_START_MARKER" "$GLOBAL_END_MARKER")"
  rm -f "$BLOCK_FILE"

  echo "✅ Pensieve global instruction sync completed"
  echo "  - global root: $GLOBAL_ROOT"
  echo "  - target: $GLOBAL_TARGET ($status)"
  exit 0
fi

PROJECT_ROOT="$(project_root)" || exit 1
PROJECT_ROOT="$(to_posix_path "$PROJECT_ROOT")"
validate_project_root "$PROJECT_ROOT"

DATA_ROOT="$(user_data_root)"
DATA_ROOT="$(to_posix_path "$DATA_ROOT")"
PIPELINES_DIR="$DATA_ROOT/pipelines"

if [[ ! -d "$PIPELINES_DIR" ]]; then
  echo "Missing Pensieve pipelines directory: $PIPELINES_DIR" >&2
  echo "Run init before syncing instruction files." >&2
  exit 1
fi

BLOCK_FILE="$(mktemp)"
build_instruction_block > "$BLOCK_FILE"

TARGETS=()
while IFS= read -r target; do
  [[ -n "$target" ]] && TARGETS+=("$target")
done < <(collect_targets)
if [[ "${#TARGETS[@]}" -eq 0 ]]; then
  echo "No instruction targets resolved." >&2
  rm -f "$BLOCK_FILE"
  exit 1
fi

echo "✅ Pensieve instruction sync completed"
echo "  - pipelines: $PIPELINES_DIR"
echo "  - targets:"

for target in "${TARGETS[@]}"; do
  status="$(sync_target_file "$target" "$BLOCK_FILE" "$START_MARKER" "$END_MARKER")"
  rel="${target#$PROJECT_ROOT/}"
  echo "    - $rel: $status"
done

rm -f "$BLOCK_FILE"

MARKER_SCRIPT="$SCRIPT_DIR/pensieve-session-marker.sh"
if [[ -f "$MARKER_SCRIPT" ]]; then
  bash "$MARKER_SCRIPT" --mode record --event sync-instructions || true
fi

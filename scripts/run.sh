#!/usr/bin/env bash
# scripts/run.sh - Interactive & CLI Test Runner for Official Maestro CLI
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ENV_FILE="${ENV_FILE:-.env}"

# Load defaults from single .env file if present
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

APP_ENV="${APP_ENV:-staging}"
APP_ID="${APP_ID:-}"
APP_ID_OVERRIDDEN=false
STAGING_APP_ID="${STAGING_APP_ID:-$APP_ID}"
PRODUCTION_APP_ID="${PRODUCTION_APP_ID:-$APP_ID}"
PLATFORM="${PLATFORM:-android}"
DEVICE=""
REPORT_FORMAT="HTML-DETAILED"
OPEN_REPORT=false
APP_FILE=""
AUTO_EMULATOR=false
PARALLEL="1"
EXECUTE=true # Executes by default; pass --dry-run to preview commands only
INTERACTIVE=false

INCLUDE_TAGS=()
EXCLUDE_TAGS=()
TARGETS=()
EXTRA_ARGS=()

print_usage() {
  cat <<'EOF'
Usage: ./scripts/run.sh [options] [test-file-or-dir...]

Interactive Mode:
  Run with no arguments to launch the step-by-step interactive prompt.

Options:
  --env <staging|production>   Select environment profile (default: APP_ENV from .env)
  --app-id <package_id>        Override APP_ID for this run
  --env-file <path>            Path to .env file (default: .env)
  -t, --tag <tag>              Include tests with tag (repeatable or comma-separated)
  -x, --exclude-tag <tag>      Exclude tests with tag (repeatable or comma-separated)
  --format <fmt>               Report format: HTML-DETAILED | HTML | JUNIT | NOOP (default: HTML-DETAILED)
  -p, --platform <name>        Platform: android | ios | web (default: android)
  --device <id>                Target specific device/emulator ID
  --app-file <path>            Install .apk/.app before running tests (Android via adb install)
  --emulator                   Start Android device via `maestro start-device`
  --parallel <n>               Shard flows across N connected devices (default: 1)
  --open                       Automatically open report.html after execution (WSL2/Linux/macOS)
  --dry-run                    Preview resolved lint + test commands without executing
  --execute                    Execute lint + tests (default behavior)
  -i, --interactive            Force interactive prompt even if options were passed
  -h, --help                   Show this help message
EOF
}

require_value() {
  if [[ $# -lt 2 || -z "${2:-}" || "$2" == -* ]]; then
    echo "Error: Option '$1' requires a value." >&2
    exit 1
  fi
}

normalize_lower() {
  local val="${1:-}"
  val="${val#"${val%%[![:space:]]*}"}"
  val="${val%"${val##*[![:space:]]}"}"
  echo "${val,,}"
}

split_csv_into_array() {
  local input="$1"
  local -n target_arr="$2"
  IFS=',' read -ra parts <<< "$input"
  for part in "${parts[@]}"; do
    part="${part//[[:space:]]/}"
    local lower="${part,,}"
    if [[ -n "$part" && "$lower" != "all" && "$lower" != "none" ]]; then
      target_arr+=("$part")
    fi
  done
}

if [[ $# -eq 0 ]]; then
  INTERACTIVE=true
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    -i|--interactive) INTERACTIVE=true; shift ;;
    --dry-run) EXECUTE=false; shift ;;
    --execute) EXECUTE=true; shift ;;
    --env)
      require_value "$1" "${2:-}"
      case "$(normalize_lower "$2")" in
        prod|production) APP_ENV="production" ;;
        stg|staging) APP_ENV="staging" ;;
        *) APP_ENV="$2" ;;
      esac
      shift 2
      ;;
    --app-id) require_value "$1" "${2:-}"; APP_ID="$2"; APP_ID_OVERRIDDEN=true; shift 2 ;;
    --env-file) require_value "$1" "${2:-}"; ENV_FILE="$2"; shift 2 ;;
    -t|--tag) require_value "$1" "${2:-}"; split_csv_into_array "$2" INCLUDE_TAGS; shift 2 ;;
    -x|--exclude-tag) require_value "$1" "${2:-}"; split_csv_into_array "$2" EXCLUDE_TAGS; shift 2 ;;
    --format) require_value "$1" "${2:-}"; REPORT_FORMAT="${2^^}"; shift 2 ;;
    -p|--platform) require_value "$1" "${2:-}"; PLATFORM="$2"; shift 2 ;;
    --device|--udid) require_value "$1" "${2:-}"; DEVICE="$2"; shift 2 ;;
    --app-file) require_value "$1" "${2:-}"; APP_FILE="$2"; shift 2 ;;
    --emulator) AUTO_EMULATOR=true; shift ;;
    --parallel) require_value "$1" "${2:-}"; PARALLEL="$2"; shift 2 ;;
    --open) OPEN_REPORT=true; shift ;;
    -e|--output|--debug-output|--test-output-dir) require_value "$1" "${2:-}"; EXTRA_ARGS+=("$1" "$2"); shift 2 ;;
    -*) EXTRA_ARGS+=("$1"); shift ;;
    *)
      if [[ "$1" == *.yaml || "$1" == *.yml || -d "$1" ]]; then
        TARGETS+=("$1")
      else
        EXTRA_ARGS+=("$1")
      fi
      shift
      ;;
  esac
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=("tests/")
fi

# Shared Helper: Parse YAML header tags (supports multi-line, inline [a,b], CRLF, quotes, comments)
scan_test_tags() {
  local mode="$1"
  local inc_csv="$2"
  local exc_csv="$3"

  node -e '
    const fs = require("fs");
    const path = require("path");
    const mode = process.argv[1];
    const inc = process.argv[2] ? process.argv[2].split(",").filter(Boolean) : [];
    const exc = process.argv[3] ? process.argv[3].split(",").filter(Boolean) : [];
    const targets = process.argv.slice(4);
    const files = [];

    function walk(p) {
      if (!fs.existsSync(p)) return;
      const st = fs.statSync(p);
      if (st.isDirectory()) {
        for (const entry of fs.readdirSync(p).sort()) walk(path.join(p, entry));
      } else if (/\.ya?ml$/i.test(p)) {
        files.push(p);
      }
    }

    function cleanTag(raw) {
      return raw
        .replace(/\s+#.*$/, "")
        .trim()
        .replace(/^["'\'']|["'\'']$/g, "")
        .trim();
    }

    function extractTags(content) {
      const normalized = content.replace(/\r\n/g, "\n");
      const head = normalized.split(/^---\s*$/m)[0];
      const lines = head.split("\n");
      const found = new Set();

      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const inlineMatch = line.match(/^tags:\s*\[([^\]]*)\]/);
        if (inlineMatch) {
          for (const part of inlineMatch[1].split(",")) {
            const tag = cleanTag(part);
            if (tag) found.add(tag);
          }
          break;
        }
        if (/^tags:\s*(?:#.*)?$/.test(line)) {
          for (let j = i + 1; j < lines.length; j++) {
            const next = lines[j];
            if (/^\s*(?:#.*)?$/.test(next)) continue;
            const itemMatch = next.match(/^\s*-\s+(.+)$/);
            if (!itemMatch) break;
            const tag = cleanTag(itemMatch[1]);
            if (tag) found.add(tag);
          }
          break;
        }
      }
      return found;
    }

    targets.forEach(walk);

    if (mode === "discover") {
      const allTags = new Set();
      for (const f of files) {
        for (const t of extractTags(fs.readFileSync(f, "utf8"))) allTags.add(t);
      }
      console.log(Array.from(allTags).sort().join(","));
      process.exit(0);
    }

    for (const f of files) {
      const fileTags = extractTags(fs.readFileSync(f, "utf8"));
      if (inc.length > 0 && !inc.some(t => fileTags.has(t))) continue;
      if (exc.length > 0 && exc.some(t => fileTags.has(t))) continue;
      console.log(f);
    }
  ' "$mode" "$inc_csv" "$exc_csv" "${TARGETS[@]}"
}

discover_tags() {
  scan_test_tags "discover" "" ""
}

resolve_filtered_tests() {
  local inc_csv=""
  local exc_csv=""
  if [[ ${#INCLUDE_TAGS[@]} -gt 0 ]]; then
    inc_csv="$(IFS=','; echo "${INCLUDE_TAGS[*]}")"
  fi
  if [[ ${#EXCLUDE_TAGS[@]} -gt 0 ]]; then
    exc_csv="$(IFS=','; echo "${EXCLUDE_TAGS[*]}")"
  fi
  scan_test_tags "filter" "$inc_csv" "$exc_csv"
}

# Interactive Step-by-Step Wizard
if [[ "$INTERACTIVE" == true ]]; then
  echo "============================================================"
  echo "  Maestro Mobile Template - Interactive Test Runner"
  echo "============================================================"
  echo ""

  # 1. Pick App ID / Environment (single step)
  echo "1) Select App ID:"
  echo "   [1] ${STAGING_APP_ID:-unset} (staging)"
  echo "   [2] ${PRODUCTION_APP_ID:-unset} (production)"
  echo "   [3] Custom App ID"
  read -r -p "   Choice [1/2/3] (default: 1): " env_choice
  env_norm="$(normalize_lower "${env_choice:-1}")"
  case "$env_norm" in
    2|production|prod)
      APP_ENV="production"
      APP_ID="${PRODUCTION_APP_ID:-$APP_ID}"
      ;;
    3|custom)
      read -r -p "   Enter custom App ID: " custom_app_id
      APP_ID="${custom_app_id:-$APP_ID}"
      read -r -p "   Data profile [staging/production] (default: staging): " custom_env
      custom_env_norm="$(normalize_lower "${custom_env:-staging}")"
      APP_ENV="${custom_env_norm:-staging}"
      ;;
    1|staging|stg|"")
      APP_ENV="staging"
      APP_ID="${STAGING_APP_ID:-$APP_ID}"
      ;;
    *)
      echo "Invalid choice '$env_choice', defaulting to staging (${STAGING_APP_ID:-$APP_ID})."
      APP_ENV="staging"
      APP_ID="${STAGING_APP_ID:-$APP_ID}"
      ;;
  esac
  echo ""

  # 2. Pick Include Tags
  discovered_tags="$(discover_tags)"
  echo "2) Include Tags (discovered: ${discovered_tags:-none})"
  read -r -p "   Include tags (e.g. smoke,onboarding or 'all') [all]: " inc_input
  if [[ -n "${inc_input:-}" ]]; then
    INCLUDE_TAGS=()
    split_csv_into_array "$inc_input" INCLUDE_TAGS
  fi
  echo ""

  # 3. Pick Exclude Tags
  default_exclude="none"
  echo "3) Exclude Tags (discovered: ${discovered_tags:-none})"
  read -r -p "   Exclude tags (e.g. demo,flaky or 'none') [${default_exclude}]: " exc_input
  exc_choice="${exc_input:-$default_exclude}"
  EXCLUDE_TAGS=()
  split_csv_into_array "$exc_choice" EXCLUDE_TAGS
  echo ""

  # 4. Choose Report Format
  echo "4) Report Format:"
  echo "   [1] HTML-DETAILED (recommended)"
  echo "   [2] HTML"
  echo "   [3] JUNIT"
  echo "   [4] NOOP"
  read -r -p "   Format [1/2/3/4] (default: 1): " fmt_choice
  case "$(normalize_lower "${fmt_choice:-1}")" in
    1|html-detailed|"") REPORT_FORMAT="HTML-DETAILED" ;;
    2|html) REPORT_FORMAT="HTML" ;;
    3|junit) REPORT_FORMAT="JUNIT" ;;
    4|noop) REPORT_FORMAT="NOOP" ;;
    *) REPORT_FORMAT="HTML-DETAILED" ;;
  esac
  echo ""

  # 5. Open Report Option
  read -r -p "5) Open report.html automatically after run? [y/N]: " open_input
  case "$(normalize_lower "${open_input:-n}")" in
    y|yes) OPEN_REPORT=true ;;
    *) OPEN_REPORT=false ;;
  esac
  echo ""
fi

# Resolve APP_ID from selected environment unless explicitly overridden via --app-id
if [[ "$INTERACTIVE" == false && "$APP_ID_OVERRIDDEN" == false ]]; then
  if [[ "$APP_ENV" == "production" && -n "$PRODUCTION_APP_ID" ]]; then
    APP_ID="$PRODUCTION_APP_ID"
  elif [[ "$APP_ENV" == "staging" && -n "$STAGING_APP_ID" ]]; then
    APP_ID="$STAGING_APP_ID"
  fi
fi

# Resolve & Lint Tag-Filtered Tests
mapfile -t FILTERED_FILES < <(resolve_filtered_tests)

if [[ ${#FILTERED_FILES[@]} -eq 0 ]]; then
  echo "No test files matched include=[${INCLUDE_TAGS[*]:-all}] exclude=[${EXCLUDE_TAGS[*]:-none}] under [${TARGETS[*]}]." >&2
  exit 1
fi

RUN_TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
REPORT_DIR="reports/${RUN_TIMESTAMP}"
REPORT_EXT="html"
if [[ "$REPORT_FORMAT" == "JUNIT" ]]; then
  REPORT_EXT="xml"
fi
REPORT_FILE="${REPORT_DIR}/report.${REPORT_EXT}"

LINT_CMD=("node" "scripts/lint.js" "${FILTERED_FILES[@]}")

# Build official `maestro` CLI command
TEST_CMD=("maestro" "--platform" "$PLATFORM")

if [[ -n "$DEVICE" ]]; then
  TEST_CMD+=("--device" "$DEVICE")
fi

TEST_CMD+=("test" "-e" "APP_ENV=$APP_ENV")
if [[ -n "$APP_ID" ]]; then
  TEST_CMD+=("-e" "APP_ID=$APP_ID")
fi

if [[ ${#INCLUDE_TAGS[@]} -gt 0 ]]; then
  TEST_CMD+=("--include-tags" "$(IFS=','; echo "${INCLUDE_TAGS[*]}")")
fi
if [[ ${#EXCLUDE_TAGS[@]} -gt 0 ]]; then
  TEST_CMD+=("--exclude-tags" "$(IFS=','; echo "${EXCLUDE_TAGS[*]}")")
fi

TEST_CMD+=("--format" "$REPORT_FORMAT")
if [[ "$REPORT_FORMAT" != "NOOP" ]]; then
  TEST_CMD+=("--output" "$REPORT_FILE")
fi
TEST_CMD+=("--test-output-dir" "$REPORT_DIR")

if [[ "$PARALLEL" -gt 1 ]]; then
  TEST_CMD+=("--shard-split" "$PARALLEL")
fi
if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  TEST_CMD+=("${EXTRA_ARGS[@]}")
fi

TEST_CMD+=("${FILTERED_FILES[@]}")

format_cmd() {
  local out=""
  local arg
  for arg in "$@"; do
    out+="$(printf '%q' "$arg") "
  done
  echo "${out% }"
}

show_report_info() {
  local report_path="$1"
  echo "Report Path: $report_path"
  if [[ "$OPEN_REPORT" == true && "$REPORT_FORMAT" == HTML* ]]; then
    if [[ -n "${WSL_DISTRO_NAME:-}" ]] && command -v explorer.exe >/dev/null 2>&1; then
      echo "Open Command: explorer.exe \"\$(wslpath -w \"$report_path\")\""
    elif command -v xdg-open >/dev/null 2>&1; then
      echo "Open Command: xdg-open \"$report_path\""
    elif command -v open >/dev/null 2>&1; then
      echo "Open Command: open \"$report_path\""
    fi
  fi
}

open_report_file() {
  local report_path="$1"
  [[ -f "$report_path" ]] || return 0
  if [[ -n "${WSL_DISTRO_NAME:-}" ]] && command -v explorer.exe >/dev/null 2>&1; then
    explorer.exe "$(wslpath -w "$report_path")" >/dev/null 2>&1 || true
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$report_path" >/dev/null 2>&1 || true
  elif command -v open >/dev/null 2>&1; then
    open "$report_path" >/dev/null 2>&1 || true
  fi
}

echo "------------------------------------------------------------"
echo "Execution Plan (Official Maestro CLI)"
echo "  Environment : $APP_ENV (APP_ID=${APP_ID:-unset})"
echo "  Platform    : $PLATFORM"
echo "  Include Tags: ${INCLUDE_TAGS[*]:-all}"
echo "  Exclude Tags: ${EXCLUDE_TAGS[*]:-none}"
echo "  Format      : $REPORT_FORMAT"
echo "  Matched Tests (${#FILTERED_FILES[@]}):"
for f in "${FILTERED_FILES[@]}"; do
  echo "    - $f"
done
echo "------------------------------------------------------------"
echo "Commands to Execute:"
echo "  1) Lint:"
echo "     $(format_cmd "${LINT_CMD[@]}")"
echo "  2) Test:"
echo "     $(format_cmd "${TEST_CMD[@]}")"
echo "------------------------------------------------------------"

if [[ "$EXECUTE" == false ]]; then
  if [[ "$REPORT_FORMAT" != "NOOP" ]]; then
    show_report_info "$REPORT_FILE"
  fi
  echo ""
  echo "(Dry-run preview only. Re-run without --dry-run to execute these commands.)"
  exit 0
fi

export MAESTRO_CLI_NO_ANALYTICS=1

# Optional auto-start device via official maestro
if [[ "$AUTO_EMULATOR" == true && "$PLATFORM" != "web" ]]; then
  echo "Starting device for platform '$PLATFORM'..."
  maestro start-device --platform "$PLATFORM"
fi

# Optional APK install on Android
if [[ -n "$APP_FILE" && "$PLATFORM" == "android" ]]; then
  echo "Installing app binary: $APP_FILE"
  adb install -r "$APP_FILE"
fi

# Pre-flight Device Readiness Check
if [[ "$PLATFORM" == "android" ]]; then
  if ! adb devices | awk 'NR>1 && $2=="device" {found=1} END {exit !found}'; then
    echo "Error: No ready Android device/emulator found (check 'adb devices' or 'maestro list-devices')." >&2
    exit 1
  fi
fi

# Lint filtered tests
echo "Linting ${#FILTERED_FILES[@]} filtered test file(s)..."
"${LINT_CMD[@]}"

# Prepare output folder and execute tests
mkdir -p "$REPORT_DIR"
TEST_EXIT=0
"${TEST_CMD[@]}" || TEST_EXIT=$?

if [[ "$REPORT_FORMAT" != "NOOP" && -f "$REPORT_FILE" ]]; then
  echo "------------------------------------------------------------"
  show_report_info "$REPORT_FILE"
  if [[ "$OPEN_REPORT" == true ]]; then
    open_report_file "$REPORT_FILE"
  fi
fi

exit "$TEST_EXIT"

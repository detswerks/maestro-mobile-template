#!/usr/bin/env bash
# scripts/run.sh - Interactive & CLI Test Runner for Maestro Mobile Template
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
DRIVER=""
DEVICE=""
ARTIFACTS="on-failure"
RETRIES="${TEST_RETRIES:-0}"
DISABLE_ANIMATIONS=true
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
  --artifacts <mode>           Screenshot/hierarchy capture: on-failure | always | never (default: on-failure)
  --retries <n>                Retry failed flows up to N times in the same run (default: 0)
  --disable-animations         Disable system animations during run (default: true on Android)
  --keep-animations            Keep system animations enabled
  -p, --platform <name>        Platform: android | ios | web (default: android)
  -d, --driver <name>          Driver: uiautomator2 | wda | devicelab | appium (auto-selected by platform)
  --device <id>                Target specific device/emulator ID
  --app-file <path>            Install .apk/.app/.ipa before running tests
  --emulator                   Auto-start Android emulator
  --parallel <n>               Run across N connected devices (default: 1)
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

normalize_lower() {
  local val="${1:-}"
  val="${val#"${val%%[![:space:]]*}"}"
  val="${val%"${val##*[![:space:]]}"}"
  echo "${val,,}"
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
    --artifacts) require_value "$1" "${2:-}"; ARTIFACTS="$2"; shift 2 ;;
    --retries) require_value "$1" "${2:-}"; RETRIES="$2"; shift 2 ;;
    --disable-animations) DISABLE_ANIMATIONS=true; shift ;;
    --keep-animations) DISABLE_ANIMATIONS=false; shift ;;
    -p|--platform) require_value "$1" "${2:-}"; PLATFORM="$2"; shift 2 ;;
    -d|--driver) require_value "$1" "${2:-}"; DRIVER="$2"; shift 2 ;;
    --device) require_value "$1" "${2:-}"; DEVICE="$2"; shift 2 ;;
    --app-file) require_value "$1" "${2:-}"; APP_FILE="$2"; shift 2 ;;
    --emulator) AUTO_EMULATOR=true; shift ;;
    --parallel) require_value "$1" "${2:-}"; PARALLEL="$2"; shift 2 ;;
    --open) OPEN_REPORT=true; shift ;;
    -e|--output) require_value "$1" "${2:-}"; EXTRA_ARGS+=("$1" "$2"); shift 2 ;;
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

# Helper: Discover all tags present in target YAML files
discover_tags() {
  scan_test_tags "discover" "" ""
}

# Helper: Resolve filtered test files matching include/exclude tags
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

  # 4. Choose Screenshot Config
  echo "4) Screenshot / Artifacts Config:"
  echo "   [1] on-failure (recommended)"
  echo "   [2] always"
  echo "   [3] never"
  read -r -p "   Artifacts [1/2/3] (default: 1): " art_choice
  case "$(normalize_lower "${art_choice:-1}")" in
    1|on-failure|"") ARTIFACTS="on-failure" ;;
    2|always) ARTIFACTS="always" ;;
    3|never) ARTIFACTS="never" ;;
    *) ARTIFACTS="on-failure" ;;
  esac
  echo ""

  # 5. Retries, Animations & Report Open
  read -r -p "5) Retries on failure [${RETRIES}]: " retries_input
  RETRIES="${retries_input:-$RETRIES}"

  read -r -p "   Disable system animations? [Y/n]: " anim_input
  case "$(normalize_lower "${anim_input:-y}")" in
    n|no) DISABLE_ANIMATIONS=false ;;
    *) DISABLE_ANIMATIONS=true ;;
  esac

  read -r -p "   Open report.html automatically after run? [y/N]: " open_input
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

# Default open-source drivers
if [[ -z "$DRIVER" ]]; then
  if [[ "$PLATFORM" == "ios" ]]; then
    DRIVER="wda"
  elif [[ "$PLATFORM" == "web" ]]; then
    DRIVER="cdp"
  else
    DRIVER="uiautomator2"
  fi
fi

# 5. Resolve & Lint Tag-Filtered Tests
mapfile -t FILTERED_FILES < <(resolve_filtered_tests)

if [[ ${#FILTERED_FILES[@]} -eq 0 ]]; then
  echo "No test files matched include=[${INCLUDE_TAGS[*]:-all}] exclude=[${EXCLUDE_TAGS[*]:-none}] under [${TARGETS[*]}]." >&2
  exit 1
fi

LINT_CMD=("npx" "maestro-runner" "lint" "${FILTERED_FILES[@]}")

# Build [global options] test [test options] <targets>
TEST_CMD=("npx" "maestro-runner" "--platform" "$PLATFORM" "--driver" "$DRIVER")

if [[ -n "$DEVICE" ]]; then
  TEST_CMD+=("--device" "$DEVICE")
fi
if [[ -n "$APP_FILE" ]]; then
  TEST_CMD+=("--app-file" "$APP_FILE")
fi
if [[ "$AUTO_EMULATOR" == true ]]; then
  TEST_CMD+=("--auto-start-emulator")
fi

TEST_CMD+=("test" "-e" "APP_ENV=$APP_ENV")
if [[ -n "$APP_ID" ]]; then
  TEST_CMD+=("-e" "APP_ID=$APP_ID")
fi

for tag in "${INCLUDE_TAGS[@]+"${INCLUDE_TAGS[@]}"}"; do
  TEST_CMD+=("--include-tags" "$tag")
done
for tag in "${EXCLUDE_TAGS[@]+"${EXCLUDE_TAGS[@]}"}"; do
  TEST_CMD+=("--exclude-tags" "$tag")
done

TEST_CMD+=("--artifacts" "$ARTIFACTS")

if [[ "$RETRIES" -gt 0 ]]; then
  TEST_CMD+=("--retries" "$RETRIES")
fi
if [[ "$PARALLEL" -gt 1 ]]; then
  TEST_CMD+=("--parallel" "$PARALLEL")
fi
if [[ "$DISABLE_ANIMATIONS" == true && "$PLATFORM" == "android" ]]; then
  TEST_CMD+=("--disable-animations")
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
  local report_html="$1"
  echo "Report Path: $report_html"
  if [[ "$OPEN_REPORT" == true ]]; then
    if [[ -n "${WSL_DISTRO_NAME:-}" ]] && command -v explorer.exe >/dev/null 2>&1; then
      echo "Open Command: explorer.exe \"\$(wslpath -w \"$report_html\")\""
    elif command -v xdg-open >/dev/null 2>&1; then
      echo "Open Command: xdg-open \"$report_html\""
    elif command -v open >/dev/null 2>&1; then
      echo "Open Command: open \"$report_html\""
    fi
  fi
}

open_report_file() {
  local report_html="$1"
  [[ -f "$report_html" ]] || return 0
  if [[ -n "${WSL_DISTRO_NAME:-}" ]] && command -v explorer.exe >/dev/null 2>&1; then
    explorer.exe "$(wslpath -w "$report_html")" >/dev/null 2>&1 || true
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$report_html" >/dev/null 2>&1 || true
  elif command -v open >/dev/null 2>&1; then
    open "$report_html" >/dev/null 2>&1 || true
  fi
}

echo "------------------------------------------------------------"
echo "Execution Plan"
echo "  Environment : $APP_ENV (APP_ID=${APP_ID:-unset})"
echo "  Platform    : $PLATFORM ($DRIVER)"
echo "  Include Tags: ${INCLUDE_TAGS[*]:-all}"
echo "  Exclude Tags: ${EXCLUDE_TAGS[*]:-none}"
echo "  Artifacts   : $ARTIFACTS"
echo "  Retries     : $RETRIES"
echo "  Animations  : $([[ "$DISABLE_ANIMATIONS" == true ]] && echo "disabled" || echo "enabled")"
echo "  Matched Tests (${#FILTERED_FILES[@]}):"
for f in "${FILTERED_FILES[@]}"; do
  echo "    - $f"
done
echo "------------------------------------------------------------"
echo "Commands to Execute:"
echo "  1) Lint:"
echo "     MAESTRO_RUNNER_NO_TELEMETRY=1 $(format_cmd "${LINT_CMD[@]}")"
echo "  2) Test:"
echo "     MAESTRO_RUNNER_NO_TELEMETRY=1 $(format_cmd "${TEST_CMD[@]}")"
echo "------------------------------------------------------------"

if [[ "$EXECUTE" == false ]]; then
  show_report_info "reports/<timestamp>/report.html"
  echo ""
  echo "(Dry-run preview only. Re-run without --dry-run to execute these commands.)"
  exit 0
fi

export MAESTRO_RUNNER_NO_TELEMETRY=1

# Pre-flight Device Readiness Check
if [[ "$PLATFORM" != "web" && "$AUTO_EMULATOR" == false ]]; then
  echo "Checking connected device readiness..."
  ready_count="$(npx maestro-runner devices --json | node -e '
    const fs = require("fs");
    const raw = fs.readFileSync(0, "utf8");
    const start = raw.indexOf("[");
    if (start === -1) { console.log(0); process.exit(0); }
    const list = JSON.parse(raw.slice(start));
    const platform = process.argv[1];
    const targetDevice = process.argv[2];
    const ready = list.filter(d =>
      d.platform === platform &&
      d.ready === true &&
      (!targetDevice || d.id === targetDevice)
    );
    console.log(ready.length);
  ' "$PLATFORM" "$DEVICE")"

  if [[ "$ready_count" -eq 0 ]]; then
    echo "Error: No ready '$PLATFORM' device found (check 'npx maestro-runner devices')." >&2
    exit 1
  fi
fi

# Step 5: Lint filtered tests
echo "Linting ${#FILTERED_FILES[@]} filtered test file(s)..."
"${LINT_CMD[@]}"

# Step 6: Run tests and show report path if generated during this run
RUN_START_MS="$(node -e 'console.log(Date.now())')"
TEST_EXIT=0
"${TEST_CMD[@]}" || TEST_EXIT=$?

LATEST_REPORT="$(node -e '
  const fs = require("fs");
  const path = require("path");
  const startMs = Number(process.argv[1]);
  if (!fs.existsSync("reports")) process.exit(0);
  let newest = null;
  let newestMs = 0;
  for (const dir of fs.readdirSync("reports")) {
    const candidate = path.join("reports", dir, "report.html");
    if (!fs.existsSync(candidate)) continue;
    const mtimeMs = fs.statSync(candidate).mtimeMs;
    if (mtimeMs >= startMs - 1000 && mtimeMs > newestMs) {
      newestMs = mtimeMs;
      newest = candidate;
    }
  }
  if (newest) console.log(newest);
' "$RUN_START_MS")"

if [[ -n "$LATEST_REPORT" ]]; then
  echo "------------------------------------------------------------"
  show_report_info "$LATEST_REPORT"
  if [[ "$OPEN_REPORT" == true ]]; then
    open_report_file "$LATEST_REPORT"
  fi
fi

exit "$TEST_EXIT"

#!/usr/bin/env bash
# scripts/run.sh - Dynamic Test Runner for Maestro Mobile Template
set -e

ENV_FILE="${ENV_FILE:-.env}"
PLATFORM="${PLATFORM:-android}"
DRIVER=""
TAG=""
PARALLEL="1"
APP_FILE=""
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--tag) TAG="$2"; shift 2 ;;
    -p|--platform) PLATFORM="$2"; shift 2 ;;
    -d|--driver) DRIVER="$2"; shift 2 ;;
    --parallel) PARALLEL="$2"; shift 2 ;;
    --app-file) APP_FILE="$2"; shift 2 ;;
    --emulator) EXTRA_ARGS+=("--auto-start-emulator"); shift ;;
    *) EXTRA_ARGS+=("$1"); shift ;;
  esac
done

# Default to 100% open-source drivers (uiautomator2 for Android, wda for iOS)
if [ -z "$DRIVER" ]; then
  if [ "$PLATFORM" = "ios" ]; then
    DRIVER="wda"
  else
    DRIVER="uiautomator2"
  fi
fi

CMD=("maestro-runner" "--env-file" "$ENV_FILE" "--platform" "$PLATFORM" "--driver" "$DRIVER")

if [ -n "$TAG" ]; then
  CMD+=("--include-tags" "$TAG")
fi

if [ "$PARALLEL" -gt 1 ]; then
  CMD+=("--parallel" "$PARALLEL")
fi

if [ -n "$APP_FILE" ]; then
  CMD+=("--app-file" "$APP_FILE")
fi

export MAESTRO_RUNNER_NO_TELEMETRY=1
echo "🚀 Running (${DRIVER}): ${CMD[*]} test tests/ ${EXTRA_ARGS[*]}"
"${CMD[@]}" test tests/ "${EXTRA_ARGS[@]}"

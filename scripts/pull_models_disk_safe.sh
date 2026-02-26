#!/usr/bin/env bash
set -euo pipefail

API_URL="${API_URL:-http://127.0.0.1:11434}"
RESERVE_GIB="${RESERVE_GIB:-55}"
REQUEST_TIMEOUT_SEC="${REQUEST_TIMEOUT_SEC:-1800}"

MODELS=(
  "smollm2:135m"
  "smollm2:360m"
  "smollm2:1.7b"
  "llama3.2:1b"
  "llama3.2:3b"
  "qwen2.5:0.5b"
  "qwen2.5:1.5b"
  "gemma2:2b"
  "granite3.3:2b"
  "tinyllama:latest"
  "phi3:mini"
  "qwen2.5:3b"
  "qwen3:8b"
)

free_gib() {
  df -k ~ | awk 'NR==2 {printf "%d", $4/1024/1024}'
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd curl
require_cmd jq
require_cmd rg

TAGS_JSON="$(curl -sS "$API_URL/api/tags")"
if ! printf '%s' "$TAGS_JSON" | jq -e '.models' >/dev/null 2>&1; then
  echo "Could not read model list from $API_URL/api/tags" >&2
  exit 1
fi

INSTALLED=()
while IFS= read -r line; do
  INSTALLED+=("$line")
done < <(printf '%s' "$TAGS_JSON" | jq -r '.models[].name')

echo "Start free disk GiB: $(free_gib)"
echo "Reserve floor GiB: $RESERVE_GIB"

for model in "${MODELS[@]}"; do
  if printf '%s\n' "${INSTALLED[@]}" | rg -Fxq "$model"; then
    echo "ALREADY_HAVE $model"
    continue
  fi

  fg="$(free_gib)"
  if [[ "$fg" -le "$RESERVE_GIB" ]]; then
    echo "STOP_LOW_DISK free=${fg}GiB reserve=${RESERVE_GIB}GiB model=$model"
    break
  fi

  echo "PULL_START $model free=${fg}GiB"
  payload="$(jq -nc --arg name "$model" '{name:$name, stream:false}')"
  resp="$(curl -sS --max-time "$REQUEST_TIMEOUT_SEC" -H 'Content-Type: application/json' -d "$payload" "$API_URL/api/pull" || true)"

  if printf '%s' "$resp" | jq -e '.error' >/dev/null 2>&1; then
    echo "PULL_FAIL $model $(printf '%s' "$resp" | jq -r '.error')"
  else
    echo "PULL_OK $model"
    INSTALLED+=("$model")
  fi

  echo "FREE_NOW_GIB $(free_gib)"
done

echo "End free disk GiB: $(free_gib)"

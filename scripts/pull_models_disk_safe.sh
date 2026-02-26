#!/usr/bin/env bash
# ==============================================================================
# Script: pull_models_disk_safe.sh
# Purpose: Automates pulling a required list of Ollama models for benchmarking 
#          while ensuring the machine does not run out of disk space. It checks 
#          available disk space before each pull and halts if a specified floor 
#          (RESERVE_GIB) is reached.
# ==============================================================================

# Fail on error, undefined vars, or failures in a command pipeline.
set -euo pipefail

# Configuration defaults that can be overridden by environment variables.

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

# free_gib()
# Function to calculate completely available disk space in GiB.
# Uses 'df -k ~' to get kilobytes of the home directory's mount.
# awk parses the second line, 4th column (Available KB), and converts to GiB.
free_gib() {
  df -k ~ | awk 'NR==2 {printf "%d", $4/1024/1024}'
}

# require_cmd()
# Helper function to ensure CLI dependencies exist before proceeding.
require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd curl
require_cmd jq
require_cmd rg

# 1. Fetch currently installed models from Ollama's local API.
# This prevents re-downloading existing models, saving time and bandwidth.
TAGS_JSON="$(curl -sS "$API_URL/api/tags")"
if ! printf '%s' "$TAGS_JSON" | jq -e '.models' >/dev/null 2>&1; then
  echo "Could not read model list from $API_URL/api/tags" >&2
  exit 1
fi

# Parse the JSON response to build an array of already installed model names.
# process substitution <(...) is used to safely map the lines to an array.
INSTALLED=()
while IFS= read -r line; do
  INSTALLED+=("$line")
done < <(printf '%s' "$TAGS_JSON" | jq -r '.models[].name')

echo "Start free disk GiB: $(free_gib)"
echo "Reserve floor GiB: $RESERVE_GIB"

for model in "${MODELS[@]}"; do
  # Fast-path: Check if the model is already in the generic INSTALLED array.
  # ripgrep (rg) is used for exact string matching (-Fx).
  if printf '%s\n' "${INSTALLED[@]}" | rg -Fxq "$model"; then
    echo "ALREADY_HAVE $model"
    continue
  fi

  # Safety check: Calculate remaining space *before* initiating the pull.
  fg="$(free_gib)"
  if [[ "$fg" -le "$RESERVE_GIB" ]]; then
    # Halt the entire script if space is too low to prevent disk exhaustion.
    echo "STOP_LOW_DISK free=${fg}GiB reserve=${RESERVE_GIB}GiB model=$model"
    break
  fi

  echo "PULL_START $model free=${fg}GiB"
  
  # Construct the JSON payload required by the Ollama Pull API.
  # We instruct Ollama NOT to stream the output for easier parsing.
  payload="$(jq -nc --arg name "$model" '{name:$name, stream:false}')"
  
  # Issue the pull request. We allow it to run for `REQUEST_TIMEOUT_SEC`.
  resp="$(curl -sS --max-time "$REQUEST_TIMEOUT_SEC" -H 'Content-Type: application/json' -d "$payload" "$API_URL/api/pull" || true)"

  # Parse the response to check for API errors originating from Ollama.
  if printf '%s' "$resp" | jq -e '.error' >/dev/null 2>&1; then
    echo "PULL_FAIL $model $(printf '%s' "$resp" | jq -r '.error')"
  else
    echo "PULL_OK $model"
    # Append the successfully pulled model to our local state buffer.
    INSTALLED+=("$model")
  fi

  echo "FREE_NOW_GIB $(free_gib)"
done

echo "End free disk GiB: $(free_gib)"

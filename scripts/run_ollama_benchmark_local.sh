#!/usr/bin/env bash
# ==============================================================================
# Script: run_ollama_benchmark_local.sh
# Purpose: Orchestrates a multi-model, multi-seed deterministic benchmark against
#          a local Ollama instance. It queries models with a specific prompt,
#          measures latency, evaluates the correctness of the answer via regex,
#          and compiles raw traces and aggregate summaries into a results folder.
# ==============================================================================

# Fail on error, undefined vars, or pipeline failures.
set -euo pipefail

# Configuration defaults that can be overridden via environment variables.

API_URL="${API_URL:-http://127.0.0.1:11434}"
PROMPT="${PROMPT:-is abba palindrome?}"
SEEDS_CSV="${SEEDS_CSV:-11,22,33}"
OUT_DIR="${OUT_DIR:-docs/results/$(date -u +%Y-%m-%dT%H-%M-%SZ)}"
INCLUDE_CLOUD_MODELS="${INCLUDE_CLOUD_MODELS:-0}"
REQUEST_TIMEOUT_SEC="${REQUEST_TIMEOUT_SEC:-900}"

# Helper to check for required CLI tools
require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

# Ensure jq (JSON parsing) and rg (ripgrep, for fast regex) are available.
require_cmd curl
require_cmd jq
require_cmd rg
require_cmd awk

# Create the unique output directory for this benchmark run.
mkdir -p "$OUT_DIR"

# Calculates free disk space in GiB to monitor disk health during tests.
free_gib() {
  df -k ~ | awk 'NR==2 {printf "%d", $4/1024/1024}'
}

# classify_verdict()
# Evaluates the LLM's response to determine if it correctly identified a palindrome.
# Uses ripgrep (rg) to scan the lowercase output for specific keywords.
classify_verdict() {
  local text="$1"
  local lower
  lower="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')"

  # Look for "not a palindrome" or "no" to classify as incorrect.
  if printf '%s' "$lower" | rg -q '\bnot (a )?palindrome\b|\bno[, ]'; then
    printf 'incorrect'
  # Look for "yes" or "is a palindrome" to classify as correct.
  elif printf '%s' "$lower" | rg -q '\byes\b|\bis (indeed )?a palindrome\b'; then
    printf 'correct'
  # Fallback if the LLM hallucinated heavily or was ambiguous.
  else
    printf 'unclear'
  fi
}

# Parse the comma-separated seeds string into a bash array.
IFS=',' read -r -a SEEDS <<<"$SEEDS_CSV"

TAGS_JSON="$(curl -sS "$API_URL/api/tags")"
if ! printf '%s' "$TAGS_JSON" | jq -e '.models' >/dev/null 2>&1; then
  echo "Could not read model list from $API_URL/api/tags" >&2
  exit 1
fi

# Determine which models to benchmark
MODELS=()
if [[ "$INCLUDE_CLOUD_MODELS" == "1" ]]; then
  # Include all models from the API
  while IFS= read -r line; do
    MODELS+=("$line")
  done < <(printf '%s' "$TAGS_JSON" | jq -r '.models[].name')
else
  # Filter out models ending in ':cloud' (e.g. OpenAI/Anthropic proxies in Ollama)
  while IFS= read -r line; do
    MODELS+=("$line")
  done < <(printf '%s' "$TAGS_JSON" | jq -r '.models[].name' | rg -v ':cloud$')
fi

if [[ "${#MODELS[@]}" -eq 0 ]]; then
  echo "No models found for benchmark." >&2
  exit 1
fi

RAW_JSONL="$OUT_DIR/raw.jsonl"
SUMMARY_JSON="$OUT_DIR/summary.json"
SUMMARY_MD="$OUT_DIR/summary.md"
METADATA_JSON="$OUT_DIR/metadata.json"
MODELS_TXT="$OUT_DIR/models.txt"
RUN_LOG="$OUT_DIR/run.log"

START_EPOCH="$(date +%s)"
START_DISK_GIB="$(free_gib)"

printf '%s\n' "${MODELS[@]}" >"$MODELS_TXT"

{
  echo "Benchmark started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "API URL: $API_URL"
  echo "Prompt: $PROMPT"
  echo "Seeds: $SEEDS_CSV"
  echo "Models: ${#MODELS[@]}"
  echo "Start free disk GiB: $START_DISK_GIB"
  echo
} >"$RUN_LOG"

# ------------------------------------------------------------------------------
# Main Benchmark Loop
# ------------------------------------------------------------------------------
# Iterate over every model, and for each model, iterate over every seed.
for model in "${MODELS[@]}"; do
  trial=1
  for seed in "${SEEDS[@]}"; do
    start="$(date +%s)"

    # Build the JSON payload to send to Ollama.
    # We pass temperature 0 and the specific seed for maximum determinism.
    payload="$(jq -nc \
      --arg model "$model" \
      --arg prompt "$PROMPT" \
      --argjson seed "$seed" \
      '{model:$model,prompt:$prompt,stream:false,options:{temperature:0,seed:$seed}}')"

    # Execute the LLM completion request.
    resp="$(curl -sS --max-time "$REQUEST_TIMEOUT_SEC" \
      -H 'Content-Type: application/json' \
      -d "$payload" \
      "$API_URL/api/generate" || true)"

    end="$(date +%s)"
    latency_sec="$((end - start))"

    if printf '%s' "$resp" | jq -e '.error' >/dev/null 2>&1; then
      verdict="error"
      answer="$(printf '%s' "$resp" | jq -r '.error')"
    else
      answer="$(printf '%s' "$resp" | jq -r '.response // ""')"
      verdict="$(classify_verdict "$answer")"
    fi

    # Append the raw data for this specific trial as a JSONL (JSON Lines) object.
    # This allows downstream tools/dashboards to parse exact traces.
    jq -nc \
      --arg model "$model" \
      --argjson trial "$trial" \
      --argjson seed "$seed" \
      --argjson latency_sec "$latency_sec" \
      --arg verdict "$verdict" \
      --arg answer "$answer" \
      --arg prompt "$PROMPT" \
      '{
        model:$model,
        trial:$trial,
        seed:$seed,
        latency_sec:$latency_sec,
        verdict:$verdict,
        prompt:$prompt,
        answer:$answer
      }' >>"$RAW_JSONL"

    short_answer="$(printf '%s' "$answer" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' | cut -c1-120)"
    echo "[$model] trial=$trial seed=$seed latency=${latency_sec}s verdict=$verdict answer=\"$short_answer\"" | tee -a "$RUN_LOG" >/dev/null

    trial="$((trial + 1))"
  done
done

# ------------------------------------------------------------------------------
# Aggregation & Reporting
# ------------------------------------------------------------------------------
# Use jq to read the entire raw.jsonl file, group trials by model,
# and calculate the total correct, incorrect, and average latency.
jq -s '
  group_by(.model) |
  map({
    model: .[0].model,
    trials: length,
    correct: (map(select(.verdict == "correct")) | length),
    incorrect: (map(select(.verdict == "incorrect")) | length),
    unclear: (map(select(.verdict == "unclear")) | length),
    errors: (map(select(.verdict == "error")) | length),
    avg_latency_sec: ((map(.latency_sec) | add) / length)
  }) |
  sort_by(.model)
' "$RAW_JSONL" >"$SUMMARY_JSON"

# Convert the summary JSON into a readable Markdown table.
{
  echo "| model | correct/trials | incorrect | unclear | errors | avg_latency_sec |"
  echo "|---|---:|---:|---:|---:|---:|"
  jq -r '.[] | "| \(.model) | \(.correct)/\(.trials) | \(.incorrect) | \(.unclear) | \(.errors) | \(.avg_latency_sec | tostring) |"' "$SUMMARY_JSON"
} >"$SUMMARY_MD"

END_EPOCH="$(date +%s)"
END_DISK_GIB="$(free_gib)"

jq -nc \
  --arg api_url "$API_URL" \
  --arg prompt "$PROMPT" \
  --arg seeds "$SEEDS_CSV" \
  --argjson include_cloud_models "$INCLUDE_CLOUD_MODELS" \
  --arg started_at "$(date -u -r "$START_EPOCH" +%Y-%m-%dT%H:%M:%SZ)" \
  --arg finished_at "$(date -u -r "$END_EPOCH" +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson model_count "${#MODELS[@]}" \
  --argjson start_free_disk_gib "$START_DISK_GIB" \
  --argjson end_free_disk_gib "$END_DISK_GIB" \
  --arg raw_jsonl "$RAW_JSONL" \
  --arg summary_json "$SUMMARY_JSON" \
  --arg summary_md "$SUMMARY_MD" \
  '{
    api_url:$api_url,
    prompt:$prompt,
    seeds:$seeds,
    include_cloud_models:$include_cloud_models,
    started_at:$started_at,
    finished_at:$finished_at,
    model_count:$model_count,
    start_free_disk_gib:$start_free_disk_gib,
    end_free_disk_gib:$end_free_disk_gib,
    files:{
      raw_jsonl:$raw_jsonl,
      summary_json:$summary_json,
      summary_md:$summary_md
    }
  }' >"$METADATA_JSON"

{
  echo
  echo "Benchmark finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "End free disk GiB: $END_DISK_GIB"
  echo "Output directory: $OUT_DIR"
} >>"$RUN_LOG"

echo "Wrote benchmark results to $OUT_DIR"
echo "Summary: $SUMMARY_MD"

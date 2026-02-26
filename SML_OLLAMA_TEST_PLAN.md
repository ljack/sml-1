# SML Ollama Local Test Plan

## Goal
Run the prompt `is abba palidrome?` across as many local Ollama models as possible, while avoiding low-disk incidents.

## Guardrails
- Local only: use `http://127.0.0.1:11434` (no cloud inference endpoints).
- Disk safety floor: stop pulling new models if free space is `<= 55 GiB`.
- Exclude cloud-tagged models from test runs (example: `kimi-k2.5:cloud`).

## Current Snapshot (2026-02-26)
- Free disk: about `62 GiB` on `/System/Volumes/Data`.
- Local models currently visible:
  - `phi3:mini`
  - `tinyllama:latest`
  - `granite3.3:2b`
  - `gemma2:2b`
  - `qwen2.5:1.5b`
  - `qwen2.5:0.5b`
  - `llama3.2:3b`
  - `llama3.2:1b`
  - `smollm2:1.7b`
  - `smollm2:360m`
  - `smollm2:135m`
  - `qwen3:8b`
  - `qwen2.5:3b`
  - `kimi-k2.5:cloud` (skip for local-only runs)

## Execution Steps
1. Verify daemon and free space.
2. Optionally pull additional small models only if free space is above floor.
3. Run prompt across all local non-cloud models.
4. Save result table (model, answer, timing, free space after run).

## Commands
### 1) Check status
```bash
curl -sS http://127.0.0.1:11434/api/tags | jq -r '.models[].name'
df -h ~
```

### 2) Run prompt on all local non-cloud models
```bash
API='http://127.0.0.1:11434'
PROMPT='is abba palidrome?'

for m in $(curl -sS "$API/api/tags" | jq -r '.models[].name' | rg -v ':cloud$'); do
  echo "=== $m ==="
  payload=$(jq -nc --arg model "$m" --arg prompt "$PROMPT" '{model:$model,prompt:$prompt,stream:false}')
  curl -sS -H 'Content-Type: application/json' -d "$payload" "$API/api/generate" \
    | jq -r '.response // .error // "no response"'
  echo
done
```

### 3) Optional bounded pull loop (disk-safe)
```bash
API='http://127.0.0.1:11434'
RESERVE_GIB=55
free_gib(){ df -k ~ | awk 'NR==2 {printf "%d", $4/1024/1024}'; }

for m in smollm2:135m smollm2:360m smollm2:1.7b llama3.2:1b llama3.2:3b qwen2.5:0.5b qwen2.5:1.5b gemma2:2b granite3.3:2b tinyllama:latest phi3:mini; do
  fg=$(free_gib)
  [ "$fg" -le "$RESERVE_GIB" ] && echo "Stop: low disk (${fg}GiB)" && break
  payload=$(jq -nc --arg name "$m" '{name:$name,stream:false}')
  curl -sS -H 'Content-Type: application/json' -d "$payload" "$API/api/pull" | jq -r '.status // .error'
done
```

## Output Format (recommended)
- `model`
- `answer` (raw response text)
- `correctness` (manual check: yes/no)
- `latency_sec`
- `free_disk_gib_after`

# Deterministic Benchmark (3 Trials Per Model)

## Run Configuration

- Date: `2026-02-26`
- Prompt: `is abba palindrome?`
- API: `http://127.0.0.1:11434`
- Options: `temperature=0`, seeds `11,22,33`
- Model filter: local models only (`*:cloud` excluded)
- Disk free: `57 GiB -> 57 GiB`
- Machine-generated source bundle: `results/2026-02-26T21-00-00Z/`

## Summary

| model | correct/3 | incorrect/3 | unclear/3 | errors/3 | avg_latency_sec |
|---|---:|---:|---:|---:|---:|
| phi3:mini | 3 | 0 | 0 | 0 | 2.33 |
| tinyllama:latest | 0 | 3 | 0 | 0 | 0.67 |
| granite3.3:2b | 0 | 3 | 0 | 0 | 2.00 |
| gemma2:2b | 0 | 3 | 0 | 0 | 2.33 |
| qwen2.5:1.5b | 3 | 0 | 0 | 0 | 1.33 |
| qwen2.5:0.5b | 3 | 0 | 0 | 0 | 0.67 |
| llama3.2:3b | 0 | 3 | 0 | 0 | 2.00 |
| llama3.2:1b | 3 | 0 | 0 | 0 | 1.00 |
| smollm2:1.7b | 3 | 0 | 0 | 0 | 1.67 |
| smollm2:360m | 0 | 3 | 0 | 0 | 0.67 |
| smollm2:135m | 0 | 3 | 0 | 0 | 0.67 |
| qwen3:8b | 3 | 0 | 0 | 0 | 28.00 |
| qwen2.5:3b | 0 | 3 | 0 | 0 | 2.67 |

## Per-Trial Evidence (verdict + latency)

| model | t1 | t2 | t3 |
|---|---|---|---|
| phi3:mini | correct (4s) | correct (2s) | correct (2s) |
| tinyllama:latest | incorrect (1s) | incorrect (0s) | incorrect (1s) |
| granite3.3:2b | incorrect (3s) | incorrect (2s) | incorrect (1s) |
| gemma2:2b | incorrect (4s) | incorrect (1s) | incorrect (2s) |
| qwen2.5:1.5b | correct (2s) | correct (1s) | correct (1s) |
| qwen2.5:0.5b | correct (1s) | correct (1s) | correct (0s) |
| llama3.2:3b | incorrect (3s) | incorrect (2s) | incorrect (1s) |
| llama3.2:1b | correct (2s) | correct (0s) | correct (1s) |
| smollm2:1.7b | correct (3s) | correct (2s) | correct (1s) |
| smollm2:360m | incorrect (1s) | incorrect (1s) | incorrect (0s) |
| smollm2:135m | incorrect (1s) | incorrect (0s) | incorrect (1s) |
| qwen3:8b | correct (30s) | correct (27s) | correct (27s) |
| qwen2.5:3b | incorrect (4s) | incorrect (2s) | incorrect (3s) |

## Notes

- Deterministic settings removed most run-to-run variance.
- Speed/correctness winners in this specific test:
  - `qwen2.5:0.5b`
  - `llama3.2:1b`
  - `qwen2.5:1.5b`
- `qwen3:8b` was accurate but significantly slower.

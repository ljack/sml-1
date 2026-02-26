# SML Ollama Local Benchmark

Local-only benchmark kit for testing small language models (SML) with Ollama.

This repository focuses on:
- reproducible local inference tests
- disk-safe model pulls
- publishable evidence files under `results/`
- credential hygiene checks before pushing to GitHub

## Quick Start

1. Ensure `ollama serve` is running locally.
2. Run benchmark:

```bash
bash scripts/run_ollama_benchmark_local.sh
```

3. Run secret scan before commit/push:

```bash
bash scripts/secret_scan.sh
```

## Local-Only Rules

- API endpoint is `http://127.0.0.1:11434`.
- Cloud-tagged models (for example `*:cloud`) are excluded by default.

## Key Files

- `scripts/run_ollama_benchmark_local.sh` deterministic multi-trial benchmark
- `scripts/pull_models_disk_safe.sh` bounded model pull loop with free-disk floor
- `scripts/secret_scan.sh` credential leak scanner
- `results/` benchmark evidence and summaries
- `docs/index.md` GitHub Pages-friendly summary page

## Safety Notes

- Never hardcode tokens in files.
- Use env vars for credentials (for example `UPCLOUD_TOKEN`) and rotate tokens if exposed.
- Run `scripts/secret_scan.sh` before every push.

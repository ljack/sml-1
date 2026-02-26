# SML Ollama Benchmark Evidence

This page summarizes local-only benchmark evidence for the prompt:

`is abba palindrome?`

## Scope

- Inference endpoint: `http://127.0.0.1:11434`
- Cloud-tagged models excluded (for example `*:cloud`)
- Deterministic settings: `temperature=0`, seeds `11,22,33`

## Main Results

See:
- [`results/2026-02-26-deterministic-3trials.md`](../results/2026-02-26-deterministic-3trials.md)
- [`results/2026-02-26-single-run-comparison.md`](../results/2026-02-26-single-run-comparison.md)
- [`results/2026-02-26-secret-scan.md`](../results/2026-02-26-secret-scan.md)
- Machine-generated bundle:
  - [`results/2026-02-26T21-00-00Z/summary.md`](../results/2026-02-26T21-00-00Z/summary.md)
  - [`results/2026-02-26T21-00-00Z/metadata.json`](../results/2026-02-26T21-00-00Z/metadata.json)
  - [`results/2026-02-26T21-00-00Z/raw.jsonl`](../results/2026-02-26T21-00-00Z/raw.jsonl)

## Reproducibility

Run locally:

```bash
bash scripts/run_ollama_benchmark_local.sh
```

Optional disk-safe pulls:

```bash
bash scripts/pull_models_disk_safe.sh
```

Secret hygiene check before push:

```bash
bash scripts/secret_scan.sh
```

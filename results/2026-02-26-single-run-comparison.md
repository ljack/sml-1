# Single-Run Prompt Comparison

## Purpose

Compare one-pass responses when using:

1. `is abba palidrome?` (typo)
2. `is abba palindrome?` (corrected spelling)

Both runs used local-only models from `http://127.0.0.1:11434` (cloud-tagged models excluded).

## Outcome Delta

| model | typo prompt | corrected prompt | delta |
|---|---|---|---|
| phi3:mini | correct | correct | unchanged |
| tinyllama:latest | incorrect | incorrect | unchanged |
| granite3.3:2b | incorrect | incorrect | unchanged |
| gemma2:2b | incorrect | incorrect | unchanged |
| qwen2.5:1.5b | correct | correct | unchanged |
| qwen2.5:0.5b | noisy correct | cleaner correct | slight improvement |
| llama3.2:3b | incorrect | incorrect | unchanged |
| llama3.2:1b | correct | correct | unchanged |
| smollm2:1.7b | incorrect | correct | improved |
| smollm2:360m | unclear | incorrect | worsened |
| smollm2:135m | incorrect | unclear/incoherent | mixed |
| qwen3:8b | correct | correct | unchanged |
| qwen2.5:3b | correct | incorrect | regressed |

## Notes

- Prompt spelling alone did not consistently improve model behavior.
- Deterministic 3-trial testing is the stronger evidence baseline for ranking.

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-.}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd rg

PATTERN='(ucat_[A-Za-z0-9]{20,}|UPCLOUD_TOKEN[[:space:]]*=[[:space:]]*["'"'"']?[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN (RSA|EC|OPENSSH|DSA|PRIVATE) KEY-----)'

echo "Running secret scan in: $ROOT_DIR"
echo "Pattern set: UpCloud tokens, common API tokens, private key headers"
echo

if rg -n --hidden --glob '!.git/*' --glob '!results/*.jsonl' --glob '!results/*/raw.jsonl' -e "$PATTERN" "$ROOT_DIR"; then
  echo
  echo "Potential secrets found. Review before commit/push." >&2
  exit 2
fi

echo "No secret patterns detected."

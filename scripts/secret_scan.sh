#!/usr/bin/env bash
# ==============================================================================
# Script: secret_scan.sh
# Purpose: Scans the repository for accidentally committed secrets (API keys,
#          tokens, private keys) before allowing a push to GitHub or the public.
#          Uses ripgrep (rg) for extreme speed.
# ==============================================================================

set -euo pipefail

# Define the directory to scan. Defaults to the current directory (.).

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd rg

# The master regex pattern for detecting secrets:
# 1. ucat_[A-Za-z0-9]{20,} -> UpCloud API tokens.
# 2. UPCLOUD_TOKEN=... -> UpCloud API tokens (often named in env vars).
# 3. AKIA[0-9A-Z]{16} -> AWS Access Key IDs.
# 4. ghp_[A-Za-z0-9]{36} -> GitHub Personal Access Tokens (Classic).
# 5. github_pat_[...] -> GitHub Fine-grained Personal Access Tokens.
# 6. xox[baprs]-... -> Slack API tokens.
# 7. -----BEGIN ... PRIVATE KEY----- -> Standard SSH/SSL Private Keys.
PATTERN='(ucat_[A-Za-z0-9]{20,}|UPCLOUD_TOKEN[[:space:]]*=[[:space:]]*["'"'"']?[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN (RSA|EC|OPENSSH|DSA|PRIVATE) KEY-----)'

echo "Running secret scan in: $ROOT_DIR"
echo "Pattern set: UpCloud tokens, common API tokens, private key headers"
echo

# Execute ripgrep (rg) across the codebase.
# -n: show line numbers.
# --hidden: search hidden files/folders (like .env).
# --glob: explictly EXCLUDE the .git folder and the generated JSONL result files 
#         (because benchmark traces might randomly hallucinate things that look like keys).
# -e "$PATTERN": evaluate the regex.
if rg -n --hidden --glob '!.git/*' --glob '!results/*.jsonl' --glob '!results/*/raw.jsonl' -e "$PATTERN" "$ROOT_DIR"; then
  echo
  # If rg returns true (exit code 0), it FOUND a match. 
  # We halt and exit with code 2 to signal a failure (secrets leaked!).
  echo "Potential secrets found. Review before commit/push." >&2
  exit 2
fi

# If rg returns false, no secrets were found. Safe to proceed.
echo "No secret patterns detected."

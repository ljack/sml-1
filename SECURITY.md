# Security Checklist (Before Push)

1. Run:

```bash
bash scripts/secret_scan.sh
```

2. Confirm no real credentials are committed:
- UpCloud tokens (`ucat_...`)
- Private keys
- PATs / API keys

3. Keep credentials out of tracked files:
- Use environment variables (for example `UPCLOUD_TOKEN`)
- Use local config files that are ignored by git

4. If a token was shared in chat or logs, rotate it.

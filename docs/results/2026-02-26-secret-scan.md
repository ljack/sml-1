# Secret Scan Evidence

## Command

```bash
bash scripts/secret_scan.sh /Users/jarkko/_dev/sml-1
```

## Output

```
Running secret scan in: /Users/jarkko/_dev/sml-1
Pattern set: UpCloud tokens, common API tokens, private key headers

No secret patterns detected.
```

## Notes

- Scan includes hidden files, excluding `.git/`.
- Intended as a pre-push gate for public repository publication.

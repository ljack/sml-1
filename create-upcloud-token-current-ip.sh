#!/usr/bin/env bash
set -euo pipefail

# Defaults can be overridden with flags:
#   -n|--name <token-name>
#   -e|--expires-in <duration>
TOKEN_NAME="test"
EXPIRES_IN="1h"

while (($#)); do
  case "$1" in
    -n|--name)
      TOKEN_NAME="${2:?missing value for $1}"
      shift 2
      ;;
    -e|--expires-in)
      EXPIRES_IN="${2:?missing value for $1}"
      shift 2
      ;;
    -h|--help)
      printf '%s\n' \
        "Usage: create-upcloud-token-current-ip.sh [-n NAME] [-e DURATION]" \
        "" \
        "Creates an UpCloud API token restricted to this machine's current public IPs." \
        "" \
        "Examples:" \
        "  ./create-upcloud-token-current-ip.sh" \
        "  ./create-upcloud-token-current-ip.sh --name ci-token --expires-in 4h"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

ipv4="$(curl -4 -fsS https://api.ipify.org || true)"
ipv6="$(curl -6 -fsS https://api64.ipify.org || true)"

args=(
  account token create
  --name "$TOKEN_NAME"
  --expires-in "$EXPIRES_IN"
)

if [[ -n "$ipv4" ]]; then
  args+=(--allow-ip-range "${ipv4}/32")
fi

if [[ -n "$ipv6" ]]; then
  args+=(--allow-ip-range "${ipv6}/128")
fi

if [[ -z "$ipv4" && -z "$ipv6" ]]; then
  echo "Could not detect public IPv4 or IPv6 address." >&2
  exit 1
fi

echo "Detected IPs:"
[[ -n "$ipv4" ]] && echo "  IPv4: $ipv4/32"
[[ -n "$ipv6" ]] && echo "  IPv6: $ipv6/128"
echo
echo "Running: upctl ${args[*]}"
upctl "${args[@]}"

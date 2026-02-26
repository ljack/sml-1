#!/usr/bin/env bash
# ==============================================================================
# Script: create-upcloud-token-current-ip.sh
# Purpose: Creates a temporary UpCloud API token restricted automatically to the
#          public IPv4 and IPv6 addresses of the machine executing this script.
# Usage: ./create-upcloud-token-current-ip.sh [-n NAME] [-e DURATION]
# ==============================================================================

# Abort the script if any command fails (-e), if any undefined variable is used (-u),
# or if any command in a pipeline fails (-o pipefail). This prevents silent errors.
set -euo pipefail

# Default configuration. Can be overridden via command-line flags.
#   -n|--name <token-name>
#   -e|--expires-in <duration>
TOKEN_NAME="test"
EXPIRES_IN="1h"

# Argument parsing loop. Iterates through all flags provided to the script.
# $# is the number of arguments. shift moves positional parameters to the left.
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

# Fetch the machine's current public IP addresses.
# -4 / -6 forces IPv4 or IPv6 resolution via curl.
# -fsS makes curl fail silently on error without cluttering the output.
# || true ensures the script doesn't abort if the machine lacks IPv4 or IPv6 connectivity.
ipv4="$(curl -4 -fsS https://api.ipify.org || true)"
ipv6="$(curl -6 -fsS https://api64.ipify.org || true)"

# Initialize the array of arguments to be passed to the UpCloud CLI (upctl).
args=(
  account token create
  --name "$TOKEN_NAME"
  --expires-in "$EXPIRES_IN"
)

# Append the detected IPs as allowed ranges to the upctl arguments list.
# /32 for IPv4 means exactly that single IP.
if [[ -n "$ipv4" ]]; then
  args+=(--allow-ip-range "${ipv4}/32")
fi

# /128 for IPv6 means exactly that single IP.
if [[ -n "$ipv6" ]]; then
  args+=(--allow-ip-range "${ipv6}/128")
fi

# Abort if the machine is completely disconnected from the internet.
if [[ -z "$ipv4" && -z "$ipv6" ]]; then
  echo "Could not detect public IPv4 or IPv6 address." >&2
  exit 1
fi

echo "Detected IPs:"
[[ -n "$ipv4" ]] && echo "  IPv4: $ipv4/32"
[[ -n "$ipv6" ]] && echo "  IPv6: $ipv6/128"
echo

# Execute the final command.
# "${args[*]}" prints the array as a single space-separated string for display.
# "${args[@]}" expands the array, safely passing each element as a distinct argument to upctl.
echo "Running: upctl ${args[*]}"
upctl "${args[@]}"

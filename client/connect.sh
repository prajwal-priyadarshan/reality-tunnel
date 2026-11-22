#!/usr/bin/env bash
# Start the tunnel.   bash connect.sh          -> proxy mode (browsers; no sudo)
#                     bash connect.sh tun      -> whole-Mac mode (asks for your password)
# Stop with Ctrl+C. In proxy mode the macOS system proxy is turned off again on exit.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-proxy}"
CFG="$DIR/out/config-$MODE.json"

command -v sing-box >/dev/null || { echo "sing-box not installed. Run: brew install sing-box"; exit 1; }
[ -f "$CFG" ] || { echo "No $CFG. Run make_client_config.py with your vless:// link first."; exit 1; }

sing-box check -c "$CFG"
echo "Connecting ($MODE mode). Ctrl+C to stop."
if [ "$MODE" = "tun" ]; then
  exec sudo "$(command -v sing-box)" run -c "$CFG"
else
  exec sing-box run -c "$CFG"
fi

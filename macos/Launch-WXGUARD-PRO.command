#!/bin/bash
# WXGUARD PRO local macOS launcher (Intel or Apple Silicon).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEB="$ROOT/web"
PORT="${WXGUARD_PORT:-8137}"
if ! command -v node >/dev/null 2>&1; then
  echo "WXGUARD PRO requires Node.js 22 or newer. Install Node.js, then retry."
  read -r -p "Press Return to close..." _ || true
  exit 1
fi
MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$MAJOR" -lt 22 ]; then
  echo "Node.js 22 or newer required; found $(node --version)."
  read -r -p "Press Return to close..." _ || true
  exit 1
fi
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
  echo "Invalid WXGUARD_PORT: $PORT"
  exit 1
fi
if [ ! -f "$WEB/tools/dev-server.mjs" ]; then
  echo "Missing web server. Keep the launcher inside the complete WXGUARD PRO checkout."
  exit 1
fi
BROWSER=""
for app in "Google Chrome" "Microsoft Edge" "Brave Browser" "Chromium"; do
  if [ -d "/Applications/$app.app" ]; then BROWSER="$app"; break; fi
done
if [ -z "$BROWSER" ]; then
  echo "Install Chrome, Edge, Brave, or Chromium for Web Bluetooth / Web Serial support."
  exit 1
fi
echo "Starting WXGUARD PRO at http://127.0.0.1:$PORT/"
cd "$WEB"
node tools/dev-server.mjs --port "$PORT" &
SERVER_PID=$!
cleanup() { kill "$SERVER_PID" 2>/dev/null || true; wait "$SERVER_PID" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
sleep 2
if ! kill -0 "$SERVER_PID" 2>/dev/null; then
  echo "Local server did not start. Port $PORT may already be in use."
  exit 1
fi
open -a "$BROWSER" "http://127.0.0.1:$PORT/"
echo "Leave this window open while using WXGUARD PRO. Press Control-C to stop."
wait "$SERVER_PID"

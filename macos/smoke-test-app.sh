#!/bin/bash
# Check a built "WXGUARD PRO.app" without opening a browser: bundle shape, signature, and that its
# own server (run with --serve-only) serves the client, refuses escapes and refuses a busy port.
#
#     bash macos/smoke-test-app.sh [path/to/WXGUARD PRO.app]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/dist/macos/WXGUARD PRO.app}"
BIN="$APP/Contents/MacOS/WXGUARD PRO"
PORT="${SMOKE_PORT:-18139}"
URL="http://127.0.0.1:$PORT"
fail() { echo "FAIL: $*" >&2; exit 1; }

test -x "$BIN" || fail "missing executable $BIN"
plutil -lint "$APP/Contents/Info.plist" >/dev/null
test -f "$APP/Contents/Resources/web/index.html" || fail "web client not bundled"
test -f "$APP/Contents/Resources/web/data/protocol.json" || fail "data bundle not bundled"
test ! -e "$APP/Contents/Resources/web/serve.mjs" || fail "Node starter should not be bundled"
lipo -info "$BIN" | grep -q x86_64 || fail "no Intel (x86_64) slice"
codesign --verify --deep --strict "$APP" || fail "signature invalid"
echo "ok: bundle, Intel slice, signature"

"$BIN" --serve-only --port "$PORT" > /tmp/wxguard-app-smoke.log 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT
for _ in {1..20}; do curl --silent --fail --max-time 1 "$URL/__wxguard-app" >/dev/null && break; sleep 0.5; done

code() { curl --silent --path-as-is --output /dev/null --write-out '%{http_code}' --max-time 5 "$URL$1"; }
curl --silent --fail "$URL/" | grep -q 'WXGUARD PRO' || { cat /tmp/wxguard-app-smoke.log; fail "index not served"; }
[ "$(code /data/protocol.json)" = 200 ] || fail "data bundle not served"
[ "$(code /src/app.js)" = 200 ] || [ "$(code /sw.js)" = 200 ] || fail "scripts not served"
for escape in "/../../../etc/passwd" "/%2e%2e/%2e%2e/%2e%2e/etc/passwd" "/..%2f..%2f..%2fetc/passwd"; do
  [ "$(code "$escape")" = 404 ] || fail "path escape not refused: $escape"
done
[ "$(curl --silent -X POST -o /dev/null -w '%{http_code}' "$URL/")" = 405 ] || fail "POST not refused"
echo "ok: serves client and data, refuses escapes and POST"

if "$BIN" --serve-only --port "$PORT" > /tmp/wxguard-app-busy.log 2>&1; then
  fail "second server started on a busy port"
fi
grep -q addressInUse /tmp/wxguard-app-busy.log || { cat /tmp/wxguard-app-busy.log; fail "busy port not reported"; }
echo "ok: refuses a busy port"
echo "smoke test passed"

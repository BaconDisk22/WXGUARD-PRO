# WXGUARD PRO on macOS

There are two ways to run WXGUARD PRO on a Mac. Most people want the app.

## The app (recommended)

`WXGUARD PRO.app` is a click-to-open app for Intel and Apple Silicon Macs (macOS 12 or newer). It opens WXGUARD PRO in **its own window**, with no tabs or address bar, and does not need Node.js, Python or a copy of this repository.

### What you need

- Google Chrome, Microsoft Edge, Brave or Chromium installed. Radio connections use Web Bluetooth and Web Serial, which only Chromium-based browsers have. WXGUARD PRO uses the browser's engine for its window but keeps its own separate profile: your normal browser tabs, history and sign-ins aren't touched.

### Install

1. Download `WXGUARD-PRO-macOS.zip` from the [Releases page](https://github.com/TheLogsAreScreaming/WXGUARD-PRO-Releases/releases).
2. Double-click the ZIP, then drag **WXGUARD PRO** into **Applications**.
3. Open it. The first time, macOS blocks it because the app is not notarized by Apple:
   - Click **Done** (not "Move to Trash").
   - Open **System Settings → Privacy & Security**, scroll down to the message about "WXGUARD PRO", and click **Open Anyway**. Confirm with your password.
   - From then on it opens normally.

   Alternatively, in Terminal: `xattr -dr com.apple.quarantine "/Applications/WXGUARD PRO.app"`

Optional: check the download against the published checksum with `shasum -a 256 WXGUARD-PRO-macOS.zip` and compare it to `WXGUARD-PRO-macOS.zip.sha256`.

### Using it

- **Opening it** starts a small local server (only reachable from this Mac, at `http://127.0.0.1:8137/`) and opens the WXGUARD PRO window.
- **Closing the window** (or ⌘Q) shuts everything down. Nothing keeps running in the background.
- **Opening it again** while it is running brings the window to the front.
- The app has no Dock icon of its own. The window appears under the browser's icon (for example Chrome's), because the browser draws it.
- Settings, saved places and radio permissions are kept between launches in `~/Library/Application Support/WXGUARD PRO/`.
- Log file: `~/Library/Logs/WXGUARD PRO.log`.

### Troubleshooting

| Message | What to do |
| --- | --- |
| "needs Google Chrome, Microsoft Edge, Brave or Chromium" | Install one of them, then open WXGUARD PRO again. |
| "Port 8137 is already in use by another program" | Quit the other program (often the developer launcher below or `npm run dev`). Or use another port: `WXGUARD_PORT=8138 open -a "WXGUARD PRO"`. Settings are stored per port, so stick with one. |
| "WXGUARD PRO is damaged and can't be opened" | The quarantine flag is set on an unsigned download. Run the `xattr` command above. |
| Radio won't connect | See the [radio troubleshooting guide](../web/docs/RADIO_TROUBLESHOOTING.md). The app window uses the same Web Bluetooth/Web Serial as the browser. |

### Building it yourself

Needs the Xcode Command Line Tools (`xcode-select --install`) and Node.js 22+:

```sh
bash macos/build-app.sh          # → dist/macos/WXGUARD PRO.app and WXGUARD-PRO-macOS.zip
bash macos/smoke-test-app.sh     # checks the bundle and its server without opening a window
```

`macos/app/main.swift` is the whole app: a static file server for the client bundled in `Contents/Resources/web` (built by `web/tools/package.mjs`) and the browser app-window launcher. `--serve-only [--port N]` runs just the server.

### Status

Ad-hoc signed only, not notarized (that needs a paid Apple Developer account). Built and smoke-tested in CI on Intel macOS and tested by hand on an Intel Mac (macOS 26). Not yet tested with a live MeshCore radio from the app window.

## Developer launcher

`Launch-WXGUARD-PRO.command` runs the development server from a full checkout and opens your normal browser. It needs Node.js 22+ and the complete repository. Double-click it in Finder (once per checkout: `chmod +x macos/Launch-WXGUARD-PRO.command`) and keep its Terminal window open. Port: `WXGUARD_PORT=8138 bash macos/Launch-WXGUARD-PRO.command`. It uses the same default port (8137) as the app, so run one at a time.

# WXGUARD PRO on Intel Mac — local launcher (preview)

This is a **browser launcher**, not a signed or notarized native macOS .app. It starts the existing local web server and opens an installed Chromium-based browser. A live MeshCore radio and browser permissions are still needed for actual radio operations.

## Requirements

- macOS on Intel (also compatible in principle with Apple Silicon)
- Node.js 22 or newer
- Google Chrome, Microsoft Edge, Brave or Chromium
- Complete WXGUARD PRO repository checkout

## Launch

From Terminal, once per checkout:

```sh
chmod +x macos/Launch-WXGUARD-PRO.command
```

Then double-click `macos/Launch-WXGUARD-PRO.command` in Finder. Keep the Terminal window open while using the web client. Closing it stops the local server.

The launcher binds the existing development server to localhost only and defaults to port 8137. To change the port, run `WXGUARD_PORT=8138 bash macos/Launch-WXGUARD-PRO.command` from Terminal.

**Important:** This is an early packaging step. It has not been tested on physical Intel Mac hardware or a MeshCore radio, and does not replace a future signed click-to-open .app.

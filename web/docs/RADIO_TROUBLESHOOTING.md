# WXGUARD PRO — Radio Connection Troubleshooting

This guide is for the **browser-based MeshCore client**. A native Intel Mac click-to-open app has not been verified as released.

## Before connecting

1. Use a current Chromium-based browser that supports the transport you intend to use. Safari and Firefox do not expose the required Web Bluetooth/Web Serial APIs.
2. Confirm the MeshCore radio is powered on and is not already connected to another application or phone.
3. If using USB, verify the cable supports data and the device appears in the browser's serial device chooser. If using Bluetooth, confirm the radio is discoverable and the browser is allowed to use Bluetooth.
4. Confirm the radio and nearby mesh nodes share the same LoRa frequency, bandwidth, spreading factor and coding rate.

## Connection succeeds but no weather arrives

- Check that a weather bot with a `WX-` prefix is in range.
- Check that the weather channel and radio region/preset match the network.
- Inspect the client's **Heard since connecting** indicator. Zero heard packets suggests a radio or mesh configuration issue rather than a display problem.
- Try the built-in recorded-data demo to distinguish display rendering from live reception. Demo data is not a substitute for over-the-air verification.

## Disconnects or reconnects

- Reconnect using the browser's radio selector. A reconnect may require selecting the device again because browser permissions and device ownership vary.
- If the port is busy, close other radio applications and reconnect the USB cable or Bluetooth session.
- Record the browser version, operating system, radio model, firmware version, transport, and any error text when reporting a reproducible issue.
- Do not interpret stale cached conditions as current weather; verify the data timestamp before making decisions.

## Reporting a problem

Open a [GitHub issue](https://github.com/TheLogsAreScreaming/WXGUARD-PRO/issues) with reproduction steps, expected/actual behavior and whether the issue also occurs in recorded-data mode. Never include personal radio keys, credentials, or private location data in public logs.

## Safety and release status

The [standalone demonstration](../demo.html) contains **simulated** weather only. It does not issue radio transmissions or represent real NWS warnings. Check the [WXGUARD-PRO-Releases page](https://github.com/TheLogsAreScreaming/WXGUARD-PRO-Releases/releases) for available builds.

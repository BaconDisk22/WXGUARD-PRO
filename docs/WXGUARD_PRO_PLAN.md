# WXGUARD PRO — Brand and Desktop Plan

WXGUARD PRO is an independent, Coast Guard–inspired weather and mesh communications application built on the MeshWX project. It is **not affiliated with or endorsed by the United States Coast Guard**. Do not use official USCG seals, emblems, or insignia.

## Design tokens

| Token | Hex | Purpose |
| --- | --- | --- |
| navy | #002D72 | Primary navigation |
| orange | #FF4B00 | Accent and actionable controls |
| midnight | #091827 | Dark canvas |
| slate | #243746 | Panels |
| steel | #54728C | Secondary content |
| white | #FFFFFF | Primary text |
| connected | #22C55E | Connected status |
| critical | #DC2626 | Critical alerts |

Accessibility: preserve at least WCAG AA contrast for normal text; do not rely on color alone to communicate alert severity. The palette is inspired by maritime emergency communications and is not represented as an official USCG specification.

## Intel Mac desktop target

- macOS Tahoe, Intel x86_64
- Click-to-open WXGUARD PRO.app and distributable .dmg
- Combined dashboard and optional locally managed Python weather-bot process
- Preserve MeshWX v5 wire compatibility and existing MeshCore behavior
- Verify USB serial and Bluetooth transports under macOS before selecting a desktop wrapper
- Prefer a lightweight wrapper if transport support is reliable; otherwise use native adapters
- No unsupported claim of a signed or notarized release before signing/notarization is completed

## Implementation sequence

1. Audit existing web CSS, entrypoints, backend configuration and tests.
2. Introduce shared color tokens and rebrand visible application strings without renaming wire protocols or commands.
3. Prototype Intel Mac desktop launcher and backend lifecycle management.
4. Test radio discovery, permissions, reconnect and shutdown behavior on physical Intel macOS hardware.
5. Profile startup, memory, radar rendering and refresh frequency before optimizing.
6. Add enhanced dashboard controls, alerts, scheduling and diagnostics behind tests.
7. Produce CI artifacts; sign and notarize the release when credentials are available.

## Attribution

Preserve the upstream Apache-2.0 license, notices and original authorship. WXGUARD PRO is the product brand; MeshWX v5 remains the protocol name for interoperability.

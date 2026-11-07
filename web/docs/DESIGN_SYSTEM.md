# WXGUARD PRO design system

One visual language for every screen, defined in one place. The approach borrows from Apple's
Human Interface Guidelines (grouped lists, sheets, clear hierarchy, system fonts) and Material 3
(semantic colour roles, tonal surfaces, state layers) without copying either.

## Files

| File | Holds |
|---|---|
| `styles/tokens.css` | **Every** colour, type size, weight, space, radius, shadow, duration and layer. Loaded first. |
| `styles/app.css` | Base, shell (bars, screens, sheets) and the shared components from `src/ui/kit/components.js`. |
| `styles/place.css`, `styles/radio.css` | The few classes specific to the place pages and the radio side. |

No other stylesheet defines a colour: `test/wxguard.test.mjs` fails on a hex colour outside
`tokens.css`. Add a token rather than a value.

## Colour

Each semantic token is defined **once for both themes** with `light-dark()`. The theme follows
the system; `<html data-theme="light|dark">` forces one.

| Role | Token | Use |
|---|---|---|
| Ground | `--bg`, `--surface`, `--surface-2` | page, cards, inset fields/tags/map water |
| States | `--surface-hover`, `--surface-press` | pointer hover and press on rows and buttons |
| Lines | `--border`, `--separator` | card hairline, row dividers |
| Ink | `--text`, `--text-2`, `--text-3` | primary, secondary, tertiary. All ≥ 4.5:1 on every surface, both themes |
| Interactive | `--accent`, `--accent-ink`, `--accent-soft` | buttons, links, selection, focus. Navy family, **never orange** |
| Identity | `--brand` (signal orange) | the bar stripe and the mark only. Not for text (3.4:1) |
| Status | `--stale` / `--good` / `--bad` / `--info` + `-soft` | missing-or-old, OK, error, information |
| Weather | `--tint-*` | NWS event colours, meaning fixed by the Weather Service |
| Radar | `--radar-*` | echo levels. Never an event tint |

Colour is never the only signal: every status also has an icon and words.

`MapCanvas` cannot parse `light-dark()`, so it resolves each token through a hidden probe element
(`getComputedStyle(probe).color`). Use the same trick for anything else drawn on a canvas.

## Type, space and shape

- Type scale in `rem` (so the system text size scales it): `--text-largeTitle`, `--text-title2`,
  `--text-title`, `--text-body`, `--text-callout`, `--text-foot`, `--text-label`. Weights
  `--weight-regular|medium|semibold|bold`.
- Spacing on a 4-pt grid: `--space-1` (4px) to `--space-8` (32px). `--gutter` = 16px.
- Shape: `--radius` (16px cards), `--radius-small` (10px fields, menu items), `--radius-pill`
  (buttons, pills, tags). `--target` = 44px minimum touch target.
- Depth: `--shadow-card` (faint in light, none in dark, where the hairline does the work),
  `--shadow-float` (menus, sheets, dialogs, toasts).
- Motion: `--duration-fast|duration|duration-slow`, `--ease-out|ease-standard`. All durations are 0
  under `prefers-reduced-motion`.

## Components (`src/ui/kit/components.js`)

| Component | Notes |
|---|---|
| `List`, `Card`, `Row`, `Note`, `Header` | A screen is a column of cards of rows. A row with an `onclick` is a button with a chevron. A row with `tint` colours its icon by the NWS event. |
| `Button({ kind })` | `default` (outlined), `primary` (filled accent, one per screen), `plain` (text), `destructive` (text in `--bad`). |
| `Banner({ kind })` | `warning` (default), `info`, `success`, `error`. Icon follows the kind. Errors use `role="alert"`. |
| `EmptyState({ icon, title, text, actions })` | What is missing and what to do about it. Prefer it to a bare sentence in a card. |
| `confirmAction({ title, message, confirmLabel })` | Ask before anything that can't be undone. Resolves `true` only on the confirm button; focus starts on Cancel. |
| `toast(text)` | A brief confirmation ("Disconnected"). Never the only place something important is said. |
| `Field`, `Select`, `Switch` | Rows you type in or choose from. Focus shows a ring; `invalid` paints the field red. |
| `openMenu(anchor, items)` | Arrow keys, Home/End, Escape; focus returns to the anchor. |
| `Spinner`, `Prose`, `Empty` | |
| `brandMark()` (`icons.js`) | The WXGUARD shield drawn inline, so it works in the single-file build. |

Connection status (connect sheet) uses `.status-card`, a coloured `.status-badge` and a
`.checklist` of what was verified on the radio, each line ✓ / ⚠ / spinner.

## Rules of thumb

- One primary button per screen. Destructive actions go through `confirmAction` or a confirmation sheet.
- Frequently used destinations go near the top of a screen; explanations fold away (see the radio
  page's "At a glance" card and its folded "How it works").
- Every user-facing string goes through `t()`. A new `web.*.en.json` table must also be listed in
  `WEB_TABLES` in `src/app/main.js` (a test checks this).
- Icons are named; a test fails on a literal icon name that doesn't exist.
- No web fonts, CDNs or tiles: the tool is used where there is no internet.

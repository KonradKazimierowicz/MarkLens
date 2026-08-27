# Configuration reference

MarkLens validates every imported or saved value and writes normalized JSON. The current schema version is `1`.

## Groups

- `theme.mode`: `auto`, `light`, or `dark`.
- `theme.light` / `theme.dark`: six-digit hex values for page, surfaces, text, headings, links, accent, borders, code, syntax tokens, warnings, quotes, tables, and scrollbar.
- `typography`: an allowlisted Windows font, text size `12–24`, line height `1.2–2.2`, and heading scale `0.85–1.35`.
- `layout`: document width `560–1600`, padding `12–72`, and block spacing `0.6–2.5`.
- `components`: radius `0–28` plus enum styles for shadow, quotes, tables, separators, and scrollbar.
- `branding`: header/logo/file visibility, title, workspace, generated logo filename, and favicon behavior.
- `behavior`: table-of-contents and toolbar behavior plus the local first-run completion marker.
- `customPresets`: up to 20 named appearance snapshots. At rest these are separated into `themes/custom-presets.json`; exports combine them for portability.

Invalid properties fall back to defaults, excessive numbers are clamped, and unknown properties are discarded. This makes import forward-tolerant without permitting arbitrary CSS, file paths, or executable content.

## Adding a setting

1. Add the default to `app/default-settings.json`.
2. Add allowlist or range validation to `Get-MarkLensValidatedSettings`.
3. Map the normalized value in `viewer.js` to a CSS variable or finite component attribute.
4. Consume it in `viewer.css`.
5. Add a visual control to the Appearance panel.
6. Add a normalization, persistence, and live-preview test.

This is the only supported settings flow; viewer components should not read unvalidated JSON directly.

## First-run styles and guide

A new profile opens a five-card style picker before the document becomes interactive. Choosing a preset previews and saves its complete theme, typography, layout, and component settings. **Skip setup** keeps the current appearance while preventing the prompt from returning.

After a style is chosen, a five-step contextual guide explains the toolbar. It supports keyboard navigation and can be closed with `Escape`. To replay it later, open **Appearance → Reader behavior → Show quick guide**.

## Printing

Use the printer icon in the reader toolbar to open the native Edge print preview. The same action remains visible beside Settings when the header is disabled. `Ctrl+P` also uses the print layout.

The printed document uses the browser's selected paper size and printer while MarkLens supplies safe printable margins, a white page, black text, the source file name, expanded disclosure sections, wrapped code, repeated table headings, and page-break protection for important blocks. Reader controls and the local source path are excluded from paper and PDF output.

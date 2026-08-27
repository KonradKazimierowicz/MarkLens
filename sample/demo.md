# Welcome to MarkLens

MarkLens turns a local Markdown file into a calm reading view — and lets you make that view yours.

## Try the reader

- Open **Settings → Appearance** from the gear button.
- Switch between auto, light, and dark mode.
- Pick a preset, then change colors, fonts, width, or spacing.
- Save your variation as a custom preset.
- Export the full configuration as JSON.

> Your document and settings stay on this computer.

## Formatting

Inline `code` uses its own configurable surface. Code blocks are highlighted:

```powershell
$message = 'Install → double-click .md → read'
Write-Host $message
```

| Capability | Included |
|---|:---:|
| Local rendering | ✓ |
| Syntax highlighting | ✓ |
| Custom themes | ✓ |
| Accounts or telemetry | Never |

---

## Markdown in, beautiful reading out

This is the Markdown source:

````markdown
### Ship a tiny Windows tool

- [x] Render Markdown locally
- [x] Highlight code
- [ ] Make the coffee

```powershell
$document = 'notes.md'
Write-Host "Opening $document with MarkLens"
```
````

And this is how its code looks after MarkLens renders it:

```powershell
$document = 'notes.md'
$reader = Join-Path $env:LOCALAPPDATA 'Programs\MarkLens'
Write-Host "Opening $document from $reader"
```

Use fenced blocks such as ` ```powershell `, ` ```javascript `, or ` ```json ` to get automatic syntax highlighting.

---

### A smaller heading

External links, such as the [MarkLens repository](https://github.com/KonradKazimierowicz/MarkLens), open only when selected. Remote images are blocked by default for privacy.

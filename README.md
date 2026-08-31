# MarkLens — Markdown Reader for Windows

> **A free, open-source Markdown reader and Markdown viewer for Windows 10 and 11.**

[![Download MarkLens for Windows](https://img.shields.io/badge/Download_for_Windows-MarkLens_1.3.1-2563eb?style=for-the-badge&logo=windows11)](https://github.com/KonradKazimierowicz/MarkLens/releases/latest/download/MarkLens-Setup-v1.3.1.exe)

![Windows 10 and 11](https://img.shields.io/badge/Windows-10%20%7C%2011-2563eb?style=flat-square)
![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-334155?style=flat-square)
![Local first](https://img.shields.io/badge/data-local%20only-16a34a?style=flat-square)
![MIT License](https://img.shields.io/badge/license-MIT-f59e0b?style=flat-square)

MarkLens opens `.md` and `.markdown` files in a calm desktop reading view. It supports GitHub-flavored Markdown, syntax highlighting, dark mode, custom themes, and Windows file associations.

No account, advertisements, telemetry, cloud storage, administrator rights, or internet connection are required.

## Start in three steps

1. [Download `MarkLens-Setup-v1.3.1.exe`](https://github.com/KonradKazimierowicz/MarkLens/releases/latest/download/MarkLens-Setup-v1.3.1.exe).
2. Run the installer, then choose MarkLens for `.md` and `.markdown` on the Windows Default Apps page that opens.
3. Double-click any Markdown file.

Windows may ask which application should open Markdown the first time. Choose **MarkLens** and enable **Always**.

> The version 1.x installer is unsigned. SmartScreen may show a warning, while Smart App Control can block unsigned apps entirely. Verify the [SHA-256 checksum](https://github.com/KonradKazimierowicz/MarkLens/releases/latest/download/MarkLens-Setup-v1.3.1.exe.sha256) and read [Troubleshooting](docs/TROUBLESHOOTING.md).

Need more detail? Read the [installation guide](docs/INSTALLATION.md) or [troubleshooting guide](docs/TROUBLESHOOTING.md).

## Read Markdown, not editor chrome

MarkLens turns local notes, documentation, README files, technical guides, and code-heavy Markdown into a focused reading surface.

![MarkLens dark theme showing a longer Markdown document, highlighted code, and a compact table of contents](docs/images/marklens-dark-reader.png)

## Why MarkLens?

- **Native Windows flow:** double-click Markdown in File Explorer.
- **Automatic folder mode:** open a Markdown file or a folder to browse every Markdown file beside it from a side file list, with newly created files appearing automatically.
- **Offline by default:** documents and settings stay on this computer.
- **GitHub-flavored Markdown:** tables, task lists, quotes, links, and fenced code.
- **Syntax highlighting:** readable code blocks without an editor.
- **Light and dark modes:** manual or system-aware theme selection.
- **Live customization:** colors, typography, spacing, width, and component styles.
- **Portable settings:** custom presets plus JSON import and export.
- **Copy Markdown:** place the complete raw source document on the clipboard in one click.
- **Print preview:** an ink-friendly document view with readable code, tables, links, and page breaks.
- **Friendly first run:** choose from five visual styles, then learn every toolbar action in a short guide.
- **Lightweight installation:** per-user setup with no administrator rights.

## Open one file or a whole project

Point MarkLens at a project folder and every Markdown file inside appears in a **Files** list beside the document. Switch between README, changelog, and docs without leaving the reader — and files created while the project is open show up in the list automatically.

![MarkLens project folder mode showing a side list of six Markdown files with their subfolders next to the rendered document and its table of contents](docs/images/marklens-folder-mode.png)

## Start with a style, not a settings maze

On first launch, MarkLens offers five complete visual directions: **Ocean Blue, Forest Green, Amber Paper, Plum Focus, and Midnight Cyan**. Selecting a card previews it immediately. A five-step guide then points to the table of contents, light/dark switch, Markdown clipboard, print preview, and Appearance settings.

![MarkLens first-run style picker with five visual presets](docs/images/marklens-first-run.png)

## Make the Markdown viewer yours

The main Appearance view keeps five essential colors visible: **Background, Body text, Headings, Links, and Accent**. One change updates both light and dark modes.

Open **Advanced colors** for complete, independent palettes. Advanced typography and layout controls stay available without crowding the everyday settings.

![MarkLens rendering an English Markdown document with its Appearance panel open](docs/images/marklens-reader.png)

## Markdown and code support

MarkLens renders GitHub-flavored Markdown locally with Marked, sanitizes the result with DOMPurify, and highlights fenced code with highlight.js.

The included [demo document](sample/demo.md) shows raw Markdown beside its rendered result:

````markdown
## Release check

- [x] Open Markdown locally
- [x] Highlight fenced code

```powershell
Get-FileHash .\MarkLens-Setup-v1.3.1.exe -Algorithm SHA256
```
````

## Local-first privacy and security

Markdown content never leaves the computer. A small local bridge binds only to `127.0.0.1` so the browser-based settings panel can save configuration.

A restrictive Content Security Policy blocks scripts, frames, objects, remote images, and network connections. Relative images are confined to the opened document directory.

Read the [privacy policy](PRIVACY.md) and [security policy](SECURITY.md) for the complete model and private vulnerability reporting.

## Help and documentation

- [Install, update, or uninstall](docs/INSTALLATION.md)
- [Fix common problems](docs/TROUBLESHOOTING.md)
- [Configure themes, layout, and branding](docs/CONFIGURATION.md)
- [Browse all documentation](docs/README.md)
- [Report a bug](https://github.com/KonradKazimierowicz/MarkLens/issues/new?template=bug_report.yml)
- [Request a feature](https://github.com/KonradKazimierowicz/MarkLens/issues/new?template=feature_request.yml)

## For developers

Clone and launch the demo:

```powershell
git clone https://github.com/KonradKazimierowicz/MarkLens.git
cd MarkLens
npm ci --ignore-scripts
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\app\MarkLens.ps1 -Path .\sample\demo.md
```

Or open a whole project folder — MarkLens lists every Markdown file inside it and keeps the list current while you work:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\app\MarkLens.ps1 -Path .
```

Run the complete verification suite:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\run-tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\verify-vendor.ps1
```

Build the Windows installer locally:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\build-installer.ps1
```

The project intentionally uses a local, manual release process and does not require GitHub Actions.

## Repository layout

```text
app/        MarkLens runtime and reader interface
docs/       User and contributor documentation
installer/  Per-user Windows installer entry point
sample/     Safe Markdown demo files
tests/      PowerShell and real-browser verification
tools/      Installer build and dependency checks
```

See the [architecture](docs/ARCHITECTURE.md), [roadmap](docs/ROADMAP.md), and [contributing guide](CONTRIBUTING.md).

MarkLens is free and open source under the [MIT License](LICENSE). Third-party notices are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

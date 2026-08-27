# MarkLens

> **Markdown deserves a reader, not another editor tab.**

![Windows 10 and 11](https://img.shields.io/badge/Windows-10%20%7C%2011-2563eb?style=flat-square)
![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-334155?style=flat-square)
![Local first](https://img.shields.io/badge/data-local%20only-16a34a?style=flat-square)
![MIT License](https://img.shields.io/badge/license-MIT-f59e0b?style=flat-square)

MarkLens turns a local `.md` file into a calm, polished reading view. Install it once, double-click Markdown in File Explorer, and read with no account, ads, telemetry, or cloud dependency.

![MarkLens rendering an English Markdown document with its Appearance panel open](docs/images/marklens-reader.png)

### Dark mode, with the document still in view

The optional table of contents keeps longer notes easy to scan while the reading surface stays focused on the current section.

![MarkLens dark theme rendering a longer Markdown document with a compact table of contents](docs/images/marklens-dark-reader.png)

## A reader that gets out of the way

- **Open naturally.** Register `.md` and `.markdown` for the current Windows user.
- **Read beautifully.** Render GitHub-flavored Markdown, tables, task lists, quotes, and highlighted code.
- **Make it yours.** Adjust the theme live, save custom presets, or move settings through JSON.
- **Stay private.** Keep the document, configuration, and rendering on this computer.
- **Install lightly.** Use a per-user installer with no administrator rights required.

## Five colors, one decision

The main Appearance view keeps color editing focused: **Background, Body text, Headings, Links, and Accent**. Change one color and MarkLens updates both light and dark modes together.

Open **Advanced colors** when the two modes should differ. It reveals complete, independent light and dark palettes without crowding the everyday controls.

Typography and layout follow the same idea. Common controls stay visible; heading fonts, code fonts, spacing, component styles, and other detailed choices live under **Advanced**.

## Markdown in, beautiful reading out

The included [demo document](sample/demo.md) shows both raw Markdown and its rendered result, including fenced code with syntax highlighting.

````markdown
## Release check

- [x] Read the document locally
- [x] Highlight fenced code

```powershell
Get-FileHash .\MarkLens-Setup-v1.0.0.exe -Algorithm SHA256
```
````

## Install

Download `MarkLens-Setup-v1.0.0.exe` and its `.sha256` file from [GitHub Releases](https://github.com/KonradKazimierowicz/MarkLens/releases), then run the installer.

MarkLens installs to `%LOCALAPPDATA%\Programs\MarkLens` and registers file associations only for the current user. If Windows keeps an older default, choose **Open with → MarkLens → Always** once.

Verify the package when desired:

```powershell
Get-FileHash .\MarkLens-Setup-v1.0.0.exe -Algorithm SHA256
```

For an unattended per-user installation:

```powershell
.\MarkLens-Setup-v1.0.0.exe /Q:U
```

The installer may be unsigned, so Windows SmartScreen can show a reputation warning until signed builds are available.

## Privacy by architecture

Markdown content never leaves the computer. A small local bridge listens only on `127.0.0.1` and exists so the browser-based settings panel can save configuration safely.

Marked renders Markdown, DOMPurify sanitizes the result, and a restrictive Content Security Policy blocks scripts, frames, objects, remote images, and network connections.

Mutation endpoints require a random per-view token. Relative raster images are limited to the opened document directory; traversal, `file://`, SVG, active HTML, and `javascript:` links are blocked.

Read [PRIVACY.md](PRIVACY.md) and the [security model](docs/SECURITY.md) for the complete details.

## Local data

Updates replace the app while preserving settings and custom themes:

```text
%LOCALAPPDATA%\MarkLens\
├── config\settings.json
├── themes\custom-presets.json
├── assets\logo.png | logo.jpg
└── cache\view-<sha256-prefix>.html
```

A regular uninstall keeps user data. Run `uninstall.ps1 -RemoveUserData` only when a complete cleanup is wanted.

## Develop locally

Runtime requirements are Windows 10/11, Windows PowerShell 5.1+, and Microsoft Edge. Node.js is needed only for contributor browser tests.

```powershell
git clone https://github.com/KonradKazimierowicz/MarkLens.git
cd MarkLens
npm ci --ignore-scripts
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\app\MarkLens.ps1 -Path .\sample\demo.md
```

Run the full test and vendor checks:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\run-tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\verify-vendor.ps1
```

Build the installer locally:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\build-installer.ps1
```

The build produces the installer and checksum in `dist\`. Releases are prepared locally and uploaded manually; the project does not require GitHub Actions.

## How it fits together

```text
Markdown file
    ↓
PowerShell core → validated local settings
    ↓                         ↓
cached viewer snapshot ← theme and preset engine
    ↓                         ↓
DOMPurify → CSS variables → Microsoft Edge app mode
```

Explore the [architecture](docs/ARCHITECTURE.md), [configuration reference](docs/CONFIGURATION.md), and [roadmap](docs/ROADMAP.md).

## Contributing

Issues and focused pull requests are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), then review the [changelog](CHANGELOG.md) and [release checklist](docs/RELEASE_CHECKLIST.md).

MarkLens is free and open source under the [MIT License](LICENSE). Third-party notices are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

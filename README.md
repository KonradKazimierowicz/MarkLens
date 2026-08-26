# MarkLens

**Download it, install it, double-click a Markdown file and read it beautifully. Customize the entire reader to your own style.**

MarkLens is a lightweight, local-first Markdown reader for Windows 10 and Windows 11. It opens `.md` and `.markdown` files from File Explorer, renders them with syntax highlighting, and presents the result in Microsoft Edge app mode. There are no accounts, ads, telemetry, cloud database, or required internet connection.

## What it does

- opens Markdown files by double-click after per-user installation;
- renders GitHub-flavored Markdown and highlighted code locally;
- provides light, dark, and system-aware automatic modes;
- exposes colors, fonts, width, text size, line height, spacing, corners, shadows, quotes, tables, separators, and scrollbar styling as settings;
- supports neutral built-in presets plus create/delete custom presets;
- imports and exports settings as JSON;
- supports an optional PNG or JPEG logo, application name, workspace name, header visibility, and source-file visibility;
- stores application files separately from settings, themes, assets, and cache;
- installs and uninstalls without administrator rights.

## Install

1. Download `MarkLens-Setup-v1.0.0.exe` and its `.sha256` file from [GitHub Releases](https://github.com/KonradKazimierowicz/MarkLens/releases).
2. Verify the checksum if desired:

   ```powershell
   Get-FileHash .\MarkLens-Setup-v1.0.0.exe -Algorithm SHA256
   ```

3. Run the installer. MarkLens is installed to `%LOCALAPPDATA%\Programs\MarkLens` and registered only for the current user.
4. Double-click a `.md` or `.markdown` file. If Windows keeps an older default application, use **Open with → Choose another app → MarkLens → Always** once.

The public installer is intentionally simple and may be unsigned. Windows SmartScreen can therefore show a reputation warning until signed builds are available.

## Make it yours

Open any document and select the gear button. The Appearance panel previews changes immediately and saves them outside the installation directory. Choose one of these starting points:

- Default
- Minimal Light
- Minimal Dark
- GitHub-like
- Documentation
- Writer
- Developer

You can modify a preset, save it under a new name, delete custom presets, reset everything, or move the complete configuration through JSON export/import. SVG logos are deliberately not accepted in v1.0 because SVG can contain active or externally referencing content; PNG and JPEG are supported safely.

## Local data

```text
%LOCALAPPDATA%\MarkLens\
├── config\
│   └── settings.json
├── themes\
│   └── custom-presets.json
├── assets\
│   └── logo.png | logo.jpg
└── cache\
    └── view-<sha256-prefix>.html
```

Updates replace application files in `%LOCALAPPDATA%\Programs\MarkLens` but preserve the data directory. A normal uninstall also preserves your settings; `uninstall.ps1 -RemoveUserData` is available when a complete cleanup is wanted.

## Privacy and security

Markdown content never leaves the computer. MarkLens serves each viewer from a random high port bound only to `127.0.0.1`; this small local bridge lets the settings panel write the configuration file. It is not a cloud backend and accepts no remote connections.

Untrusted Markdown is rendered by Marked, sanitized by DOMPurify, and then inserted into the document. A restrictive Content Security Policy blocks scripts, frames, objects, remote images, and network connections. Mutation endpoints require a random per-view token. Relative raster images are served only from the opened document's directory, while `file://`, path traversal, external image fetching, SVG images, active HTML, and `javascript:` links are blocked by default. External web links open only after the user selects them.

See [PRIVACY.md](PRIVACY.md) and [docs/SECURITY.md](docs/SECURITY.md) for the full model.

## Developer quick start

Runtime requirements: Windows 10/11, Windows PowerShell 5.1+, and Microsoft Edge. Contributors also need Node.js to run the real-browser security test; Node and Playwright are development-only and are not included in the installed application.

```powershell
git clone https://github.com/KonradKazimierowicz/MarkLens.git
cd MarkLens
npm ci --ignore-scripts
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\app\MarkLens.ps1 -Path .\sample\demo.md
```

Run the complete test suite:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\run-tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\verify-vendor.ps1
```

Install directly from a source checkout:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

## Build the installer

IExpress ships with supported Windows versions, so no heavyweight packaging framework is required.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\build-installer.ps1
```

Outputs:

```text
dist\MarkLens-Setup-v1.0.0.exe
dist\MarkLens-Setup-v1.0.0.exe.sha256
```

## Architecture

```text
Markdown file
    ↓
PowerShell core → validated user configuration
    ↓                         ↓
cached viewer snapshot ← theme/preset engine
    ↓                         ↓
DOMPurify → CSS variables → Microsoft Edge app mode
```

The open-source core has no account, payment, sync, or marketplace dependencies. Future extension points operate on exported configuration and theme packages without changing the reader's local contract. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/MIGRATION_ANALYSIS.md](docs/MIGRATION_ANALYSIS.md), and [docs/CONFIGURATION.md](docs/CONFIGURATION.md).

## Contributing and releases

Read [CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md), the [release checklist](docs/RELEASE_CHECKLIST.md), and the [roadmap](docs/ROADMAP.md). CI runs the Windows tests, verifies vendored hashes, builds the installer, and publishes a workflow artifact. A `v*` tag also creates a GitHub Release with the EXE and checksum.

## License

MarkLens is free and open source under the [MIT License](LICENSE). Third-party library notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

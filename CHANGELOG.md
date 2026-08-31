# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and semantic versioning.

## [1.3.1] - 2026-08-31

### Fixed

- Opening an individual Markdown file now automatically discovers other `.md` and `.markdown` files in its containing folder and shows them in the **Files** panel, while keeping the originally opened document active.

## [1.3.0] - 2026-08-31

### Added

- **Project folder mode:** MarkLens now opens a whole folder. The reader finds every `.md` and `.markdown` file inside it (skipping hidden and `node_modules` directories), starts on the README when one exists, and shows a **Files** list in the side panel for switching between documents without leaving the reader.
- The file list refreshes automatically, so Markdown files created, renamed, or deleted while the folder is open appear in the list within a few seconds.
- New loopback routes `GET /api/files` and `GET /api/document` behind the same relative-path, junction, and folder-escape validation as document assets.

### Changed

- Relative images now resolve against the current document in folder mode and remain confined to the opened folder.

## [1.2.0] - 2026-08-27

### Added

- A first-run style picker with exactly five previewable reading presets: Ocean Blue, Forest Green, Amber Paper, Plum Focus, and Midnight Cyan.
- A five-step contextual guide covering the table of contents, theme switch, Markdown clipboard, printing, and Appearance settings.
- A **Show quick guide** action in Reader behavior for replaying the walkthrough at any time.
- Keyboard focus management, Escape handling, arrow-key preset navigation, and responsive onboarding coverage down to 320 pixels.

### Changed

- Reworked the built-in preset collection into five distinct, complete light/dark style systems.
- Resetting appearance no longer causes first-run setup to reappear.

## [1.1.1] - 2026-08-27

### Changed

- The clipboard action now copies the complete raw Markdown source instead of the local file path.
- Updated the clipboard action label and confirmation message to describe the copied content accurately.

## [1.1.0] - 2026-08-27

### Added

- A persistent **Print / preview** action backed by the native Edge print dialog.
- An ink-friendly print layout with document identification, printable margins, expanded details, wrapped code, repeated table headers, and sensible page-break rules.
- Real-browser coverage that verifies the print action, print-only visibility, computed print styles, and PDF generation.

### Changed

- Removed the manual reload action from the reader toolbar.
- Print remains available as a floating action when the reader header is disabled.

## [1.0.1] - 2026-08-27

### Added

- MarkLens-specific Windows Default Apps flow after interactive installation and from Reader behavior settings.
- Friendly MarkLens name and icon registration for the Windows file-handler chooser.
- Real-browser responsive coverage at 320, 390, 768, 1024, and 1440 pixel widths.

### Changed

- The reader toolbar now auto-hides by default while retaining the reading-progress strip and revealing itself at the top edge, on upward scrolling, or keyboard focus.
- The table of contents has a clearer active state, section count, mobile close control, and a dedicated touch-friendly scroll surface.
- The browser favicon now uses the same packaged, multi-size blue-to-teal icon as the Windows application.

### Fixed

- Mobile table of contents could remain `display: none` when the desktop preference was disabled.
- Long tables of contents could not scroll reliably on small screens.
- `.md` files could continue opening the Windows app chooser because registration alone cannot confirm a user default.

## [1.0.0] - 2026-08-27

### Added

- Independent MarkLens application and neutral branding.
- Per-user Windows installation, `.md` / `.markdown` registration, update-safe user data, and normal uninstall entry.
- Local Markdown rendering with Marked 18.0.11 and highlight.js 11.12.0.
- Focused five-color editing shared by light and dark modes, plus independent advanced palettes, typography, layout, component styling, reader behavior, and reset.
- Optional PNG/JPEG logo, application/workspace names, header and source-name visibility.
- Seven built-in presets, custom preset create/delete, and JSON import/export.
- Separate config, themes, assets, and cache directories under `%LOCALAPPDATA%\MarkLens`.
- DOMPurify sanitization, restrictive CSP, loopback-only settings bridge, anti-CSRF token, path confinement, input limits, and dependency hash verification.
- Local Windows verification and installer build tooling, documentation, privacy policy, roadmap, and a manual GitHub Release checklist.
- User-first installation and troubleshooting guides, direct release downloads, product screenshots, and structured GitHub issue forms.

### Fixed

- Installer completion no longer waits indefinitely for a dialog owned by hidden PowerShell; interactive completion auto-closes and `/Q:U` performs a silent install.

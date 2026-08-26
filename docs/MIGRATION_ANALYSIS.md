# Migration analysis

This document records the stage-one review of the original branded reader and the decisions used to create the independent MarkLens repository. The source repository remains unchanged.

## Files reviewed

| Source file or mechanism | Finding | MarkLens decision |
|---|---|---|
| `app/MdReader.ps1` | Reads a template, Base64-embeds Markdown and libraries, writes an MD5-keyed HTML cache, then starts Edge app mode. Branding and paths are embedded in the launcher. | Keep the lightweight PowerShell entry point and Base64 transport. Split configuration/rendering into `MarkLens.Core.psm1`, replace MD5 with a SHA-256 cache key, and add a loopback-only settings bridge. |
| `app/launch.vbs` | Correctly hides the PowerShell console and quotes the file argument. | Reuse the small VBS launcher pattern with neutral names and messages. |
| `app/viewer.template.html` | A single large HTML/CSS/JS file contains brand colors, logo, fonts, layout, interactions, and direct `innerHTML = marked.parse(...)`. | Replace it with structural HTML plus separate `viewer.css`, `viewer.js`, validated bootstrap data, CSS variables, DOMPurify, CSP, and a settings drawer. |
| `install.ps1` | Uses per-user HKCU registration and supports `.md` / `.markdown`, but contains brand-specific ProgID, labels, icon, and type names. | Retain per-user registration, add Registered Applications capabilities, use `MarkLens.Document`, and remove all source branding. |
| `uninstall.ps1` | Carefully clears extension defaults only when they still point to the application. File removal is constrained to one expected install root. | Retain both safety properties, remove MarkLens capability entries, and preserve user data by default. |
| cache generation | One cache file per source path under `%LOCALAPPDATA%`, regenerated on open. The original uses an eight-character MD5 path hash. | Preserve deterministic replacement, use a 16-character SHA-256 prefix, and put cache under the independent MarkLens data root. |
| `marked.js` | Vendored Marked 12.0.2, executed locally. The result is trusted as HTML. | Upgrade to 18.0.11, keep it vendored/offline, and treat its output as untrusted until DOMPurify sanitizes it. |
| `highlight.js` | Vendored highlight.js 11.10.0 and runs after rendering. | Upgrade CDN assets to 11.12.0, keep local execution, and run only on sanitized code nodes. |
| Edge app mode | Finds Edge from registry or standard paths and starts `--app=file:///...`. | Keep Edge discovery and app mode, serve `http://127.0.0.1:<random>/` to support safe settings persistence. |
| installer EXE | IExpress bundles a ZIP payload and per-user installer; no admin rights or external packaging runtime. | Retain IExpress, rename the artifact to `MarkLens-Setup-vX.X.X.exe`, add hash output, update-safe data separation, validation, CI, and release automation. |

## What was reusable without product coupling

- Windows PowerShell 5.1 as the application host.
- A VBS shim for silent Explorer invocation.
- Microsoft Edge `--app` mode and fallback to the default browser.
- Vendored client-side libraries for offline operation.
- HKCU-only file registration.
- IExpress as a zero-download installer builder.

These are technical patterns, not copied product identity.

## What required refactoring

- The monolithic viewer and launcher responsibilities.
- All appearance values, which now flow through one validated configuration model.
- Browser-to-disk persistence, solved by an authenticated loopback bridge.
- Cache hashing and cache/data layout.
- File-association discoverability and uninstall metadata.
- Dependency provenance and automated verification.

## Source-specific elements removed

- Product name, publisher, ProgID, descriptive strings, and registry paths.
- Red/orange/yellow brand gradient and all brand-specific palette names.
- Brand logo, branded application icon, and brand-only embedded font bundle.
- Source-specific installer filenames and release documentation.

## New components

- `MarkLens.Core.psm1`: directories, schema allowlisting, safe JSON embedding, cache generation.
- `viewer.js`: theme engine, sanitized renderer, settings UI, presets, import/export, branding.
- `viewer.css`: a CSS-variable-driven visual layer with no organization-specific design.
- Loopback HTTP bridge: validated settings/logo writes and confined local image reads.
- `default-settings.json` and `presets.json`: data-driven appearance defaults.
- Security, privacy, contribution, architecture, roadmap, and release documentation.
- Windows tests, vendor hash checks, CI build, and tag release workflow.

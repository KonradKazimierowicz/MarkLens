# Architecture

MarkLens is deliberately a small Windows application composed of PowerShell and a browser viewer. The system has no cloud runtime.

## Runtime flow

```text
Explorer file association
        ↓
app/launch.vbs (hidden process shim)
        ↓
app/MarkLens.ps1
        ├── validate source file or folder, extensions, and size
        ├── scan folder workspaces for Markdown files (no junctions, hidden, or node_modules)
        ├── bind random port on 127.0.0.1 only
        ├── load app/MarkLens.Core.psm1
        └── start Microsoft Edge --app
                    ↓
             GET local viewer
                    ↓
default settings + user settings + custom presets
                    ↓
allowlist validation → bootstrap JSON → CSS variables
                    ↓
Markdown bytes → Marked → DOMPurify → controlled DOM transforms
                    ↓
highlight.js → reader UI
```

## Configuration pipeline

```text
%LOCALAPPDATA%\MarkLens\config\settings.json
%LOCALAPPDATA%\MarkLens\themes\custom-presets.json
                 ↓
        server-side allowlist
                 ↓
         normalized settings
                 ↓
     viewer theme engine / CSS vars
                 ↓
          document components
```

No appearance setting is interpreted as arbitrary CSS. Colors must be six-digit hex values; numeric settings are clamped; fonts and component styles use enums; branding text is length-limited; logo paths are generated internally.

## Module boundaries

- **Windows integration:** `install.ps1`, `uninstall.ps1`, `launch.vbs`. It knows registry and process details, not theme behavior.
- **Application core:** `MarkLens.Core.psm1`. It owns the data model, persistence, validation, cache, and viewer assembly.
- **Local transport:** `MarkLens.ps1`. It owns loopback HTTP parsing, route allowlists, security headers, local assets, and lifecycle.
- **Viewer:** `viewer.template.html`, `viewer.css`, `viewer.js`. It owns rendering and interaction but cannot choose arbitrary disk paths.
- **Theme data:** `default-settings.json`, `presets.json`, user JSON. It contains values rather than layout implementation.
- **Packaging:** `installer/` and `tools/build-installer.ps1`. It copies a fixed payload and never stores user configuration in the install directory.

## Local bridge rationale

A `file://` viewer cannot reliably persist to `%LOCALAPPDATA%`, and browser `localStorage` behavior for local files is not a stable cross-file contract. A short-lived loopback service provides a narrow persistence API without Electron, WebView2 redistribution, an administrator service, or a cloud backend. It binds `System.Net.Sockets.TcpListener` to `IPAddress.Loopback`, chooses a random port, uses a random 256-bit mutation token, rejects chunked and oversized requests, and exposes only fixed routes.

## Extension boundary

The open-source core contract is the versioned JSON configuration plus local theme/assets directories. Future optional theme packs, backup, synchronization, PDF export, or plugins can consume that contract from separate modules. Account, billing, marketplace, and synchronization code must not become a dependency of file opening, rendering, settings, import/export, or built-in themes.

Schema changes increment `schemaVersion`, preserve unknown future export fields during migration where safe, and add explicit validators/defaults. Appearance components consume only CSS variables so new fields do not require scattering logic across PowerShell, HTML, and CSS.

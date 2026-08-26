# Privacy

MarkLens is local-first and privacy-first by design.

## Data MarkLens reads

- the Markdown file explicitly opened by the user;
- relative PNG, JPEG, GIF, or WebP images located inside that document's directory;
- the local MarkLens settings, custom presets, and optional logo.

## Data MarkLens writes

MarkLens writes only to `%LOCALAPPDATA%\MarkLens`: validated settings, custom presets, the optional logo, and cached self-contained viewer snapshots. Because a cache snapshot contains the opened Markdown in Base64 form, anyone who can read your Windows profile can also read that cache. The cache can be deleted at any time and will be recreated as needed.

## Network behavior

MarkLens does not upload documents, settings, paths, or usage information. It contains no telemetry and does not contact an update service. A temporary HTTP listener binds to the IPv4 loopback address `127.0.0.1` so the browser-based settings panel can persist changes. It cannot be reached from another computer and stops when the viewer closes or after an inactivity limit.

Remote images embedded in Markdown are blocked, preventing tracking pixels and accidental requests. Selecting an ordinary `http` or `https` link is the only built-in action that can intentionally open an external network destination.

## Removal

Normal uninstall preserves customization for upgrades. Run the source `uninstall.ps1` with `-RemoveUserData` to remove `%LOCALAPPDATA%\MarkLens` as well.

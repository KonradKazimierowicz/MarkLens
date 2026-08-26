# Roadmap

The roadmap keeps the local open-source reader useful on its own. Items are proposals, not commitments.

## v1.1 — polish and accessibility

- keyboard focus trap and improved compact/mobile settings navigation;
- WCAG contrast feedback for custom palette combinations;
- live source-file watching and a manual cache management screen;
- additional safe raster image formats where Windows support is reliable;
- localized UI strings, starting with Polish;
- signed release feasibility and improved default-app onboarding.

## v1.2 — portable themes and output

- standalone versioned theme-pack files in the `themes` directory;
- theme thumbnails and conflict-safe import;
- print presets and local PDF export;
- optional sanitized SVG rasterization in an isolated helper;
- portable mode for USB/folder-based installations;
- richer code-highlight palettes exposed through the same validator/CSS-variable pipeline.

## Later

- an explicit, permissioned plugin manifest for local-only extensions;
- optional encrypted configuration backup/sync implemented outside the core;
- optional theme marketplace client with offline core and signed package verification;
- team branding bundles;
- macOS/Linux platform adapters if a comparably lightweight host is practical.

Payments, accounts, synchronization, and marketplace services are intentionally absent from v1.x core. If introduced later, they must remain optional adapters and must never gate local file reading or free customization.

# Security policy

MarkLens assumes every opened Markdown file, imported configuration, path, and uploaded logo may be malicious.

## Supported versions

Security fixes are applied to the latest published release. Upgrade to the newest version before reporting a problem that may already be resolved.

## Report a vulnerability

Please use the repository's [private security advisory form](https://github.com/KonradKazimierowicz/MarkLens/security/advisories/new). Do not open a public issue for a vulnerability.

Include the affected version, Windows version, reproduction steps, expected impact, and whether opening a file is enough to trigger the issue. Never attach private documents or sensitive data.

## Security model

| Boundary | Main abuse cases | Controls |
|---|---|---|
| Markdown → HTML | Scripts, event handlers, frames, unsafe URLs, DOM clobbering | Marked output passes through DOMPurify; active tags and attributes are forbidden; links and images receive a second protocol and path check. |
| Viewer → local API | Cross-site requests changing settings or logos | Random per-view 256-bit token, same-origin requests, fixed routes, request-size limits, and no CORS. |
| Relative image → disk | Traversal, symlink escape, arbitrary reads, oversized files, active SVG | Canonical paths stay below the source directory; reparse points are rejected; raster allowlist; 10 MB cap; no SVG. |
| Imported JSON → CSS/UI | CSS or path injection and memory abuse | 256 KB cap, strict property allowlist, hex colors, enums, numeric clamps, fixed logo names, and preset limits. |
| Browser viewer → network | Tracking images, silent requests, embedded pages | CSP `default-src 'none'`, `connect-src 'self'`, `img-src 'self' data:`, and no frames, objects, or remote images. |
| Loopback socket → host | LAN exposure, request smuggling, denial of service | Bind only to `127.0.0.1`, random high port, bounded headers and bodies, no chunked encoding, read timeouts, and a 24-hour idle ceiling. |

## Sanitization order

1. Decode the original bytes as UTF-8.
2. Parse with Marked in GitHub-flavored Markdown mode.
3. Sanitize the generated HTML with DOMPurify.
4. Insert only the sanitized result.
5. Disable non-web and relative document links.
6. Rewrite relative raster images to the confined local image endpoint.
7. Highlight code from the sanitized DOM.

MarkLens does not support SVG logos or SVG Markdown images in version 1.0. Their external-reference and parser surface is unnecessary for the core reader.

## Dependency policy

Browser dependencies are vendored so runtime remains offline. Versions, sources, licenses, and SHA-256 hashes are committed and checked before every release.

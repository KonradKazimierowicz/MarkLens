# Security model

MarkLens assumes every opened Markdown file, imported configuration, path, and uploaded logo may be malicious.

## Trust boundaries and assets

| Boundary | Main abuse cases | Controls |
|---|---|---|
| Markdown → HTML | script execution, event handlers, iframes, unsafe URLs, DOM clobbering | Marked output passes through DOMPurify; active tags/attributes are forbidden; links and images get a second protocol/path pass. |
| Viewer → local API | cross-site requests altering settings or logo | random per-view 256-bit header token, same-origin requests, fixed routes, small request limits, no CORS. |
| Relative image → disk | path traversal, junction/symlink escape, arbitrary file read, oversized files, SVG active content | canonical path must remain below the source directory; reparse points are rejected; raster extension allowlist; 10 MB cap; no SVG. |
| Imported JSON → CSS/UI | CSS injection, path injection, memory abuse | 256 KB cap, strict property allowlist, hex colors, enums, numeric clamps, fixed logo names, preset count/name limits. |
| Browser viewer → network | tracking images, silent requests, embedded remote pages | CSP `default-src 'none'`, `connect-src 'self'`, `img-src 'self' data:`, no frames/objects, remote images removed. |
| Loopback socket → host | LAN exposure, request smuggling, denial of service | bind only `127.0.0.1`, random high port, 32 KB header/3 MB body caps, no chunked encoding, read timeouts, 24-hour idle ceiling. |

## Sanitization order

1. Decode the original bytes as UTF-8.
2. Parse with Marked in GFM mode.
3. Sanitize the entire generated HTML string with DOMPurify.
4. Insert only the sanitized string.
5. Disable non-web and relative document links.
6. Rewrite relative raster image paths to the confined local image endpoint.
7. Highlight code from the sanitized DOM.

The application intentionally does not support SVG logos or SVG Markdown images in v1.0. SVG used through `<img>` is safer than inline SVG, but its external-reference and parser surface is unnecessary for the core product. A future release may add rasterization in an isolated process.

## Dependency policy

Browser dependencies are vendored so runtime is offline. Versions, sources, licenses, and SHA-256 hashes are committed. Run `tools/verify-vendor.ps1` locally before every release. Updating a dependency requires reviewing upstream release/security notes and rerunning the hostile Markdown browser check.

## Reporting

Use GitHub's private Security Advisories for the repository. Include the affected version, reproduction, impact, and whether opening a file is sufficient to trigger the issue. Do not attach private documents.

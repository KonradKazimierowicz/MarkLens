# GitHub Release checklist

## Code and product

- [ ] `VERSION`, tag, installer name, and changelog version match.
- [ ] No organization-specific source branding remains.
- [ ] Interactive install opens the MarkLens Default Apps page; after one-time user confirmation, double-click `.md` → read works on Windows 10 and Windows 11.
- [ ] `.markdown` behaves the same as `.md`.
- [ ] Edge app mode and default-browser fallback both work.
- [ ] Appearance changes are live and persist after closing/reopening.
- [ ] All seven built-in presets render in light and dark modes.
- [ ] Custom preset create/delete and JSON import/export work.
- [ ] PNG and JPEG logo upload/removal, branding-off, hidden header, and filename visibility work.
- [ ] Update install preserves `%LOCALAPPDATA%\MarkLens`.
- [ ] Interactive setup completes without a hidden dialog, and `Setup.exe /Q:U` finishes unattended.
- [ ] Installed Apps uninstall removes program/registry entries and preserves settings.

## Security and privacy

- [ ] `tests/run-tests.ps1` passes in Windows PowerShell 5.1.
- [ ] `tools/verify-vendor.ps1` passes.
- [ ] Hostile Markdown is verified in a real Chromium browser: no script, event handler, iframe, `javascript:` URL, remote image, or traversal succeeds.
- [ ] CSP and other security response headers are present.
- [ ] No secrets, user documents, generated cache, or local settings are committed.
- [ ] Vendored versions, hashes, license texts, and notices match.
- [ ] The EXE and SHA-256 checksum are produced from a clean checkout.

## Publication

- [ ] Review README download/install/developer/build instructions.
- [ ] Confirm repository description, topics, MIT license detection, Issues, Discussions (if desired), and Security Advisories.
- [ ] Run the complete test suite, vendor verification, and installer build locally from a clean checkout.
- [ ] Push an annotated tag matching `VERSION`.
- [ ] Create the GitHub Release manually from the annotated tag.
- [ ] Confirm the GitHub Release contains the EXE and `.sha256` file.
- [ ] Test the downloaded release artifact on a clean Windows user profile.
- [ ] Document the unsigned SmartScreen expectation in release notes.

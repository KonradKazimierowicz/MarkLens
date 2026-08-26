# Contributing to MarkLens

Thank you for helping keep Markdown reading small, safe, and personal.

## Principles

- Preserve the install → double-click → read flow.
- Keep the core useful offline and without an account.
- Prefer Windows-native capabilities and small vanilla HTML/CSS/JavaScript modules over large frameworks.
- Treat Markdown, imported JSON, paths, and uploaded assets as untrusted input.
- Add a CSS variable and validated configuration field for new appearance options; do not hard-code user-facing theme values into viewer components.

## Workflow

1. Create a focused branch.
2. Add or update tests for behavior and abuse cases.
3. Install the development-only browser dependency and run:

   ```powershell
   npm ci --ignore-scripts
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\run-tests.ps1
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\verify-vendor.ps1
   ```

4. Build the installer for installation-related changes.
5. Update `CHANGELOG.md` for user-visible changes.
6. Open a pull request explaining the user outcome, security impact, and verification performed.

Do not commit generated `dist/`, `work/`, browser artifacts, secrets, or user settings. Dependency changes must update the vendored file, upstream license, `VERSIONS.json`, hash verification, and security rationale together.

Security issues should be reported privately through the repository's GitHub Security Advisories rather than a public issue.

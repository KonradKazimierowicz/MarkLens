# Install MarkLens

## Recommended: Windows installer

1. [Download the latest MarkLens installer](https://github.com/KonradKazimierowicz/MarkLens/releases/latest/download/MarkLens-Setup-v1.2.0.exe).
2. Run `MarkLens-Setup-v1.2.0.exe`.
3. Windows opens the MarkLens file-default page. Choose MarkLens for both `.md` and `.markdown`.
4. Double-click any Markdown file.

MarkLens installs for the current Windows user. Administrator rights are not required.

Windows deliberately requires this one-time confirmation; applications cannot silently replace your default file handlers. You can reopen the same page later from **Settings → Appearance → Reader behavior → Set MarkLens as default**.

## Verify the download

Download the accompanying [SHA-256 checksum](https://github.com/KonradKazimierowicz/MarkLens/releases/latest/download/MarkLens-Setup-v1.2.0.exe.sha256), then run:

```powershell
Get-FileHash .\MarkLens-Setup-v1.2.0.exe -Algorithm SHA256
```

Compare the displayed hash with the value in the `.sha256` file.

## Silent installation

Use this command for an unattended, per-user installation:

```powershell
.\MarkLens-Setup-v1.2.0.exe /Q:U
```

Silent installation registers MarkLens as an available handler but does not open Windows Settings. File defaults must still be confirmed by the signed-in user.

## Update

Download and run the newer installer. Application files are replaced while settings and custom themes under `%LOCALAPPDATA%\MarkLens` are preserved.

## Uninstall

Open **Windows Settings → Apps → Installed apps**, find **MarkLens**, and select **Uninstall**.

A normal uninstall preserves themes and settings for a future reinstall. See [Troubleshooting](TROUBLESHOOTING.md) when a full reset is needed.

## Run from source

This path is intended for developers, not regular users:

```powershell
git clone https://github.com/KonradKazimierowicz/MarkLens.git
cd MarkLens
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\app\MarkLens.ps1 -Path .\sample\demo.md
```

# Troubleshooting MarkLens

## Windows SmartScreen appears

MarkLens 1.0 may be unsigned. Confirm that the installer came from the official GitHub Release and verify its checksum. If it matches, select **More info → Run anyway**.

## Windows Smart App Control blocks the installer

Some Windows 11 systems refuse unsigned applications without offering **Run anyway**. Do not disable system protection only to install MarkLens.

Until a signed build is available, use the [source launch instructions](INSTALLATION.md#run-from-source) or wait for a signed release. The limitation is documented in every unsigned release.

## Markdown still opens in another application

Right-click a `.md` file and choose **Open with → Choose another app → MarkLens → Always**.

You can also open **Windows Settings → Apps → Default apps**, search for `.md` and `.markdown`, and select MarkLens for both extensions.

## The installer does not require administrator access

MarkLens installs under `%LOCALAPPDATA%\Programs\MarkLens` for the current user. Running as administrator is unnecessary and does not install it for other accounts.

## My settings disappeared after an update

Settings live separately under `%LOCALAPPDATA%\MarkLens`. A regular update or uninstall should preserve that folder.

Open MarkLens, select the gear icon, and use **Export JSON** before manual cleanup or moving to another computer.

## Reset the appearance

Open the gear icon and select **Reset defaults** at the bottom of the settings panel.

## MarkLens needs Microsoft Edge

The reader uses the installed Microsoft Edge runtime in app mode. Update or reinstall Microsoft Edge if no reader window opens.

## Still stuck?

[Open a bug report](https://github.com/KonradKazimierowicz/MarkLens/issues/new?template=bug_report.yml) with the MarkLens version, Windows version, and exact steps to reproduce. Do not upload private Markdown files.

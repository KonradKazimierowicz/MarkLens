param(
    [Parameter(Mandatory = $true)][string]$PayloadZip,
    [string]$InstallRoot,
    [switch]$SkipRegistration,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function Show-MarkLensInstallerMessage {
    param([string]$Message, [string]$Title, [ValidateSet('Information','Error')][string]$Kind = 'Information')
    if ($Quiet) { return }
    Add-Type -AssemblyName System.Windows.Forms
    $icon = if ($Kind -eq 'Error') { [Windows.Forms.MessageBoxIcon]::Error } else { [Windows.Forms.MessageBoxIcon]::Information }
    [Windows.Forms.MessageBox]::Show($Message, $Title, [Windows.Forms.MessageBoxButtons]::OK, $icon) | Out-Null
}

if ([string]::IsNullOrWhiteSpace($InstallRoot)) { $InstallRoot = Join-Path $env:LOCALAPPDATA 'Programs\MarkLens' }
$InstallRoot = [IO.Path]::GetFullPath($InstallRoot)
$stageRoot = Join-Path $env:TEMP ('marklens-setup-' + [guid]::NewGuid().ToString('N'))

try {
    if (-not (Test-Path -LiteralPath $PayloadZip -PathType Leaf)) { throw 'The installer payload is missing.' }
    New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null
    Expand-Archive -LiteralPath $PayloadZip -DestinationPath $stageRoot -Force
    foreach ($relativePath in @('app\MarkLens.ps1','app\MarkLens.Core.psm1','app\viewer.template.html','app\viewer.js','app\viewer.css','app\launch.vbs','install.ps1','uninstall.ps1','VERSION')) {
        if (-not (Test-Path -LiteralPath (Join-Path $stageRoot $relativePath) -PathType Leaf)) { throw "Incomplete installer payload: $relativePath" }
    }
    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
    Get-ChildItem -LiteralPath $stageRoot -Force | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $InstallRoot -Recurse -Force }
    if (-not $SkipRegistration) {
        & (Join-Path $InstallRoot 'install.ps1') -ApplicationRoot $InstallRoot
        $version = [IO.File]::ReadAllText((Join-Path $InstallRoot 'VERSION')).Trim()
        $uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\MarkLens'
        $uninstallCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + (Join-Path $InstallRoot 'uninstall.ps1') + '" -RemoveFiles'
        $estimatedSize = [Math]::Ceiling((Get-ChildItem -LiteralPath $InstallRoot -File -Recurse | Measure-Object Length -Sum).Sum / 1KB)
        New-Item -Path $uninstallKey -Force | Out-Null
        Set-ItemProperty -Path $uninstallKey -Name DisplayName -Value 'MarkLens'
        Set-ItemProperty -Path $uninstallKey -Name DisplayVersion -Value $version
        Set-ItemProperty -Path $uninstallKey -Name Publisher -Value 'MarkLens contributors'
        Set-ItemProperty -Path $uninstallKey -Name DisplayIcon -Value (Join-Path $InstallRoot 'app\marklens.ico')
        Set-ItemProperty -Path $uninstallKey -Name InstallLocation -Value $InstallRoot
        Set-ItemProperty -Path $uninstallKey -Name UninstallString -Value $uninstallCommand
        Set-ItemProperty -Path $uninstallKey -Name URLInfoAbout -Value 'https://github.com/KonradKazimierowicz/MarkLens'
        Set-ItemProperty -Path $uninstallKey -Name NoModify -Value 1 -Type DWord
        Set-ItemProperty -Path $uninstallKey -Name NoRepair -Value 1 -Type DWord
        Set-ItemProperty -Path $uninstallKey -Name EstimatedSize -Value $estimatedSize -Type DWord
    }
    Show-MarkLensInstallerMessage -Title 'MarkLens' -Message "Installation completed.`r`n`r`nDouble-click a .md or .markdown file to read it with MarkLens."
}
catch {
    if ($Quiet) { Write-Error $_.Exception.Message } else { Show-MarkLensInstallerMessage -Title 'MarkLens installation error' -Kind Error -Message $_.Exception.Message }
    exit 1
}
finally {
    if (Test-Path -LiteralPath $stageRoot) {
        $resolvedStage = (Resolve-Path -LiteralPath $stageRoot).Path
        $tempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
        if ($resolvedStage.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolvedStage).StartsWith('marklens-setup-')) {
            Remove-Item -LiteralPath $resolvedStage -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

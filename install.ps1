<#
.SYNOPSIS
    Registers MarkLens for the current Windows user without administrator rights.
#>
param(
    [string]$ApplicationRoot = $PSScriptRoot,
    [switch]$OpenDefaultApps
)

$ErrorActionPreference = 'Stop'
$ApplicationRoot = [IO.Path]::GetFullPath($ApplicationRoot)
$appDirectory = Join-Path $ApplicationRoot 'app'
$launcherPath = Join-Path $appDirectory 'launch.vbs'
$iconPath = Join-Path $appDirectory 'marklens.ico'
$iconTool = Join-Path $ApplicationRoot 'tools\make-icon.ps1'
$progId = 'MarkLens.Document'
$label = 'Markdown document (MarkLens)'

if (-not (Test-Path -LiteralPath $launcherPath -PathType Leaf)) { throw "Missing launcher: $launcherPath" }
if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) {
    if (-not (Test-Path -LiteralPath $iconTool -PathType Leaf)) { throw "Missing icon and icon generator: $iconPath" }
    & $iconTool | Out-Null
}

$progIdKey = "HKCU:\Software\Classes\$progId"
New-Item -Path $progIdKey -Force | Out-Null
Set-Item -Path $progIdKey -Value $label
New-Item -Path "$progIdKey\DefaultIcon" -Force | Out-Null
Set-Item -Path "$progIdKey\DefaultIcon" -Value ('"' + $iconPath + '"')
New-Item -Path "$progIdKey\Application" -Force | Out-Null
Set-ItemProperty -Path "$progIdKey\Application" -Name ApplicationName -Value 'MarkLens'
Set-ItemProperty -Path "$progIdKey\Application" -Name ApplicationDescription -Value 'A local, customizable Markdown reader.'
Set-ItemProperty -Path "$progIdKey\Application" -Name ApplicationIcon -Value ('"' + $iconPath + '"')
New-Item -Path "$progIdKey\shell\open\command" -Force | Out-Null
Set-Item -Path "$progIdKey\shell\open\command" -Value ('wscript.exe "' + $launcherPath + '" "%1"')

foreach ($extension in @('.md', '.markdown')) {
    $extensionKey = "HKCU:\Software\Classes\$extension"
    New-Item -Path $extensionKey -Force | Out-Null
    Set-Item -Path $extensionKey -Value $progId
    $openWithKey = "$extensionKey\OpenWithProgids"
    New-Item -Path $openWithKey -Force | Out-Null
    New-ItemProperty -Path $openWithKey -Name $progId -Value '' -PropertyType String -Force | Out-Null
}

$capabilitiesKey = 'HKCU:\Software\Clients\MarkLens\Capabilities'
New-Item -Path $capabilitiesKey -Force | Out-Null
Set-ItemProperty -Path $capabilitiesKey -Name ApplicationName -Value 'MarkLens'
Set-ItemProperty -Path $capabilitiesKey -Name ApplicationDescription -Value 'A local, customizable Markdown reader.'
New-Item -Path "$capabilitiesKey\FileAssociations" -Force | Out-Null
Set-ItemProperty -Path "$capabilitiesKey\FileAssociations" -Name '.md' -Value $progId
Set-ItemProperty -Path "$capabilitiesKey\FileAssociations" -Name '.markdown' -Value $progId
$registeredAppsKey = 'HKCU:\Software\RegisteredApplications'
New-Item -Path $registeredAppsKey -Force | Out-Null
Set-ItemProperty -Path $registeredAppsKey -Name MarkLens -Value 'Software\Clients\MarkLens\Capabilities'

if (-not ('MarkLensShell.Notify' -as [type])) {
    Add-Type -Namespace MarkLensShell -Name Notify -MemberDefinition @'
[DllImport("shell32.dll")]
public static extern void SHChangeNotify(int eventId, int flags, IntPtr item1, IntPtr item2);
'@
}
[MarkLensShell.Notify]::SHChangeNotify(0x08000000, 0x1000, [IntPtr]::Zero, [IntPtr]::Zero)

Write-Host 'MarkLens was registered for .md and .markdown files for the current user.' -ForegroundColor Green
Write-Host 'Windows requires you to confirm MarkLens as the default app.' -ForegroundColor Yellow
if ($OpenDefaultApps) {
    Start-Process 'ms-settings:defaultapps?registeredAppUser=MarkLens' | Out-Null
    Write-Host 'Default Apps is open. Choose MarkLens for .md and .markdown.' -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Removes MarkLens registration and optionally its installed files.
.DESCRIPTION
    User settings in %LOCALAPPDATA%\MarkLens are preserved unless
    -RemoveUserData is explicitly supplied.
#>
param([switch]$RemoveFiles, [switch]$RemoveUserData)

$ErrorActionPreference = 'Stop'
$progId = 'MarkLens.Document'
$progIdKey = "HKCU:\Software\Classes\$progId"
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\MarkLens'

if (Test-Path -LiteralPath $progIdKey) { Remove-Item -LiteralPath $progIdKey -Recurse -Force }
foreach ($extension in @('.md', '.markdown')) {
    $extensionKey = "HKCU:\Software\Classes\$extension"
    $openWithKey = "$extensionKey\OpenWithProgids"
    if (Test-Path -LiteralPath $openWithKey) { Remove-ItemProperty -Path $openWithKey -Name $progId -Force -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $extensionKey) {
        $currentDefault = (Get-Item -LiteralPath $extensionKey).GetValue('')
        if ($currentDefault -eq $progId) { Set-Item -Path $extensionKey -Value '' }
    }
}
if (Test-Path -LiteralPath 'HKCU:\Software\Clients\MarkLens') { Remove-Item -LiteralPath 'HKCU:\Software\Clients\MarkLens' -Recurse -Force }
if (Test-Path -LiteralPath 'HKCU:\Software\RegisteredApplications') { Remove-ItemProperty -Path 'HKCU:\Software\RegisteredApplications' -Name MarkLens -Force -ErrorAction SilentlyContinue }
if (Test-Path -LiteralPath $uninstallKey) { Remove-Item -LiteralPath $uninstallKey -Recurse -Force }

if ($RemoveUserData) {
    $expectedDataRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'MarkLens'))
    if (Test-Path -LiteralPath $expectedDataRoot) {
        $resolvedDataRoot = (Resolve-Path -LiteralPath $expectedDataRoot).Path
        if ($resolvedDataRoot -ne $expectedDataRoot) { throw "Refusing to remove unexpected data path: $resolvedDataRoot" }
        Remove-Item -LiteralPath $resolvedDataRoot -Recurse -Force
    }
}

if ($RemoveFiles) {
    $expectedInstallRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs\MarkLens'))
    $currentRoot = [IO.Path]::GetFullPath($PSScriptRoot)
    if ($currentRoot -ne $expectedInstallRoot) { throw "Refusing to remove unexpected application path: $currentRoot" }
    Remove-Item -LiteralPath $currentRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'MarkLens was uninstalled. User settings were preserved unless -RemoveUserData was supplied.' -ForegroundColor Green

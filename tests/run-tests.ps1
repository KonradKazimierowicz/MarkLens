$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent

& (Join-Path $PSScriptRoot 'Test-Core.ps1')
& (Join-Path $PSScriptRoot 'Test-Server.ps1')
& (Join-Path $PSScriptRoot 'Test-BrowserSecurity.ps1')
& (Join-Path $PSScriptRoot 'Test-Installer.ps1')

$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    & $node.Source --check (Join-Path $repoRoot 'app\viewer.js')
    if ($LASTEXITCODE -ne 0) { throw 'viewer.js syntax validation failed.' }
}
else { Write-Warning 'Node.js not found; skipped JavaScript syntax validation.' }

$excludedDirectories = @('.git', 'dist', 'node_modules', 'output', 'work')
$scannableExtensions = @('.css', '.html', '.js', '.json', '.md', '.mjs', '.ps1', '.psm1', '.vbs', '.yaml', '.yml')
$brandingLeaks = Get-ChildItem -LiteralPath $repoRoot -Recurse -File | Where-Object {
    $relativePath = $_.FullName.Substring($repoRoot.Length).TrimStart('\')
    $topDirectory = $relativePath.Split('\')[0]
    $isExcludedDirectory = $excludedDirectories -contains $topDirectory
    $isRunner = $_.FullName -eq $PSCommandPath
    $isScannable = ($scannableExtensions -contains $_.Extension.ToLowerInvariant()) -or $_.Name -in @('.gitignore', 'VERSION')
    -not $isExcludedDirectory -and -not $isRunner -and $isScannable
} | Select-String -Pattern 'Strefa\s*998|Strefa MD|StrefaMd' -CaseSensitive:$false
if ($brandingLeaks) { throw "Source-branding leak detected:`n$($brandingLeaks -join "`n")" }

Write-Host 'All MarkLens tests passed.' -ForegroundColor Green

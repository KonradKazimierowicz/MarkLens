$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent

& (Join-Path $PSScriptRoot 'Test-Core.ps1')
& (Join-Path $PSScriptRoot 'Test-Server.ps1')
& (Join-Path $PSScriptRoot 'Test-BrowserSecurity.ps1')

$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    & $node.Source --check (Join-Path $repoRoot 'app\viewer.js')
    if ($LASTEXITCODE -ne 0) { throw 'viewer.js syntax validation failed.' }
}
else { Write-Warning 'Node.js not found; skipped JavaScript syntax validation.' }

$brandingLeaks = rg -n -i 'Strefa\s*998|Strefa MD|StrefaMd' $repoRoot -g '!work/**' -g '!dist/**' -g '!tests/run-tests.ps1'
if ($LASTEXITCODE -eq 0 -and $brandingLeaks) { throw "Source-branding leak detected:`n$brandingLeaks" }
if ($LASTEXITCODE -gt 1) { throw 'Branding scan failed.' }

Write-Host 'All MarkLens tests passed.' -ForegroundColor Green

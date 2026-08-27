$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
function Assert-True { param([bool]$Condition, [string]$Message) if (-not $Condition) { throw "ASSERTION FAILED: $Message" } }

$edgeCandidates = @(
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
)
$edge = $edgeCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $edge) { throw 'Microsoft Edge is required for the appearance test.' }
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) { throw 'Node.js is required for the appearance test.' }
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'node_modules\playwright-core') -PathType Container)) {
    throw 'Browser test dependency is missing. Run npm ci before running the test suite.'
}

$testRoot = Join-Path $repoRoot ('work\test-appearance-' + [guid]::NewGuid().ToString('N'))
$readyFile = Join-Path $testRoot 'ready.txt'
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$server = $null
try {
    $serverArguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $repoRoot 'app\MarkLens.ps1'),'-Path',(Join-Path $repoRoot 'sample\demo.md'),'-DataRoot',(Join-Path $testRoot 'data'),'-NoBrowser','-ReadyFile',$readyFile)
    $server = Start-Process -FilePath 'powershell.exe' -ArgumentList $serverArguments -WindowStyle Hidden -PassThru
    $deadline = (Get-Date).AddSeconds(12)
    while (-not (Test-Path -LiteralPath $readyFile -PathType Leaf) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 100 }
    Assert-True (Test-Path -LiteralPath $readyFile -PathType Leaf) 'Appearance-test server did not become ready.'
    $url = [IO.File]::ReadAllText($readyFile).Trim()
    & $node.Source (Join-Path $PSScriptRoot 'browser-appearance.mjs') $edge $url
    if ($LASTEXITCODE -ne 0) { throw 'Headless Edge appearance assertions failed.' }
    Write-Host 'Appearance tests passed.' -ForegroundColor Green
}
finally {
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = (Resolve-Path -LiteralPath $testRoot).Path
        $expectedPrefix = [IO.Path]::GetFullPath((Join-Path $repoRoot 'work')).TrimEnd('\') + '\'
        if ($resolved.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $resolved -Recurse -Force }
    }
}

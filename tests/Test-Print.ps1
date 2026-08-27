param([string]$ApplicationRoot)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$runtimeRoot = if ([string]::IsNullOrWhiteSpace($ApplicationRoot)) { $repoRoot } else { [IO.Path]::GetFullPath($ApplicationRoot) }
function Assert-True { param([bool]$Condition, [string]$Message) if (-not $Condition) { throw "ASSERTION FAILED: $Message" } }

$edgeCandidates = @('C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe', 'C:\Program Files\Microsoft\Edge\Application\msedge.exe')
$edge = $edgeCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $edge) { throw 'Microsoft Edge is required for the print test.' }
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) { throw 'Node.js is required for the print test.' }
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'node_modules\playwright-core') -PathType Container)) { throw 'Browser test dependency is missing. Run npm ci before running the test suite.' }

$testRoot = Join-Path $repoRoot ('work\test-print-' + [guid]::NewGuid().ToString('N'))
$readyFile = Join-Path $testRoot 'ready.txt'
$pdfPath = Join-Path $testRoot 'print-preview.pdf'
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$dataRoot = Join-Path $testRoot 'data'
Import-Module (Join-Path $runtimeRoot 'app\MarkLens.Core.psm1') -Force
$testSettings = ConvertTo-MarkLensHashtable (Get-MarkLensDefaultSettings)
$testSettings.behavior.onboardingComplete = $true
Save-MarkLensSettings -Settings $testSettings -DataRoot $dataRoot | Out-Null
$server = $null
try {
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $runtimeRoot 'app\MarkLens.ps1'),'-Path',(Join-Path $runtimeRoot 'sample\demo.md'),'-DataRoot',$dataRoot,'-NoBrowser','-ReadyFile',$readyFile)
    $server = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $deadline = (Get-Date).AddSeconds(12)
    while (-not (Test-Path -LiteralPath $readyFile -PathType Leaf) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 100 }
    Assert-True (Test-Path -LiteralPath $readyFile -PathType Leaf) 'Print-test server did not become ready.'
    $url = [IO.File]::ReadAllText($readyFile).Trim()
    & $node.Source (Join-Path $PSScriptRoot 'browser-print.mjs') $edge $url $pdfPath
    if ($LASTEXITCODE -ne 0) { throw 'Headless Edge print assertions failed.' }
    Write-Host 'Print browser tests passed.' -ForegroundColor Green
}
finally {
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = (Resolve-Path -LiteralPath $testRoot).Path
        $expectedPrefix = [IO.Path]::GetFullPath((Join-Path $repoRoot 'work')).TrimEnd('\') + '\'
        if ($resolved.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $resolved -Recurse -Force }
    }
}

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
function Assert-True { param([bool]$Condition, [string]$Message) if (-not $Condition) { throw "ASSERTION FAILED: $Message" } }

$testRoot = Join-Path $repoRoot ('work\test-server-' + [guid]::NewGuid().ToString('N'))
$readyFile = Join-Path $testRoot 'ready.txt'
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$process = $null
try {
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $repoRoot 'app\MarkLens.ps1'),'-Path',(Join-Path $repoRoot 'sample\security-demo.md'),'-DataRoot',$testRoot,'-NoBrowser','-ReadyFile',$readyFile)
    $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $deadline = (Get-Date).AddSeconds(12)
    while (-not (Test-Path -LiteralPath $readyFile -PathType Leaf) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 100 }
    Assert-True (Test-Path -LiteralPath $readyFile -PathType Leaf) 'Loopback server did not become ready.'
    $url = [IO.File]::ReadAllText($readyFile).Trim()
    Assert-True ($url -match '^http://127\.0\.0\.1:\d+/$') 'Server must bind to the IPv4 loopback interface.'
    $page = Invoke-WebRequest -UseBasicParsing -Uri $url
    Assert-True ($page.StatusCode -eq 200) 'Viewer endpoint should return HTTP 200.'
    Assert-True ($page.Headers['Content-Security-Policy'] -match "default-src 'none'") 'Viewer must send a restrictive CSP.'
    Assert-True ($page.Content -match '"csrfToken":"([^"]+)"') 'Bootstrap token is missing.'
    $token = $Matches[1]

    $badStatus = 0
    try { Invoke-WebRequest -UseBasicParsing -Uri ($url + 'api/settings') -Method Put -Headers @{ 'X-MarkLens-Token'='wrong' } -ContentType 'application/json' -Body '{}' | Out-Null }
    catch { $badStatus = [int]$_.Exception.Response.StatusCode }
    Assert-True ($badStatus -eq 403) 'Mutating APIs must reject invalid CSRF tokens.'

    $body = '{"theme":{"mode":"dark","light":{"background":"not-css"}},"branding":{"title":"Local Reader"}}'
    $saved = Invoke-RestMethod -Uri ($url + 'api/settings') -Method Put -Headers @{ 'X-MarkLens-Token'=$token } -ContentType 'application/json' -Body $body
    Assert-True ($saved.theme.mode -eq 'dark') 'Valid settings should persist through the API.'
    Assert-True ($saved.theme.light.background -eq '#f4f6f8') 'API must validate CSS values server-side.'

    $assetStatus = 0
    try { Invoke-WebRequest -UseBasicParsing -Uri ($url + 'api/document-asset?path=..%2F..%2FWindows%2Fwin.ini') | Out-Null }
    catch { $assetStatus = [int]$_.Exception.Response.StatusCode }
    Assert-True ($assetStatus -eq 404) 'Document assets must not escape the source directory.'

    Invoke-WebRequest -UseBasicParsing -Uri ($url + 'api/shutdown') -Method Post -Headers @{ 'X-MarkLens-Token'=$token } | Out-Null
    $process.WaitForExit(7000) | Out-Null
    Assert-True $process.HasExited 'Loopback server should stop after the viewer closes.'
    Write-Host 'Server security tests passed.' -ForegroundColor Green
}
finally {
    if ($process -and -not $process.HasExited) { Stop-Process -Id $process.Id -Force }
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = (Resolve-Path -LiteralPath $testRoot).Path
        $expectedPrefix = [IO.Path]::GetFullPath((Join-Path $repoRoot 'work')).TrimEnd('\') + '\'
        if ($resolved.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $resolved -Recurse -Force }
    }
}

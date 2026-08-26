$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
function Assert-True { param([bool]$Condition, [string]$Message) if (-not $Condition) { throw "ASSERTION FAILED: $Message" } }

$edgeCandidates = @(
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
)
$edge = $edgeCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $edge) { throw 'Microsoft Edge is required for the browser security test.' }

$testRoot = Join-Path $repoRoot ('work\test-browser-' + [guid]::NewGuid().ToString('N'))
$readyFile = Join-Path $testRoot 'ready.txt'
$domFile = Join-Path $testRoot 'dom.html'
$errorFile = Join-Path $testRoot 'edge-errors.txt'
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$server = $null
try {
    $serverArguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $repoRoot 'app\MarkLens.ps1'),'-Path',(Join-Path $repoRoot 'sample\security-demo.md'),'-DataRoot',(Join-Path $testRoot 'data'),'-NoBrowser','-ReadyFile',$readyFile)
    $server = Start-Process -FilePath 'powershell.exe' -ArgumentList $serverArguments -WindowStyle Hidden -PassThru
    $deadline = (Get-Date).AddSeconds(12)
    while (-not (Test-Path -LiteralPath $readyFile -PathType Leaf) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 100 }
    Assert-True (Test-Path -LiteralPath $readyFile -PathType Leaf) 'Browser-test server did not become ready.'
    $url = [IO.File]::ReadAllText($readyFile).Trim()
    $edgeArguments = @('--headless=new','--disable-gpu','--disable-extensions','--no-first-run',('--user-data-dir=' + (Join-Path $testRoot 'edge-profile')),'--dump-dom',$url)
    $browser = Start-Process -FilePath $edge -ArgumentList $edgeArguments -WindowStyle Hidden -RedirectStandardOutput $domFile -RedirectStandardError $errorFile -Wait -PassThru
    Assert-True ($browser.ExitCode -eq 0) 'Headless Edge failed to render the hostile fixture.'
    $dom = [IO.File]::ReadAllText($domFile, [Text.Encoding]::UTF8)
    $match = [regex]::Match($dom, '(?s)<article[^>]*id="content"[^>]*>(.*?)</article>')
    Assert-True $match.Success 'Rendered Markdown article was not found in the browser DOM.'
    $article = $match.Groups[1].Value
    Assert-True (-not ($dom -match 'data-pwned')) 'Hostile Markdown executed and changed the document.'
    foreach ($blockedPattern in @('(?i)<script','(?i)<iframe','(?i)<svg','(?i)\sonerror=','(?i)\sonload=','(?i)javascript:','(?i)file:///','(?i)example\.com/tracker\.png')) {
        Assert-True (-not ($article -match $blockedPattern)) "Active HTML or unsafe URL survived sanitization: $blockedPattern"
    }
    $articleText = [Net.WebUtility]::HtmlDecode([regex]::Replace($article, '<[^>]+>', ''))
    Assert-True ($articleText.Contains('This is code and must stay visible as text.')) 'Safe code content should remain visible.'
    Assert-True ($articleText.Contains('Unsafe JavaScript link')) 'Unsafe links should remain readable after their navigation is removed.'
    Write-Host 'Browser sanitization tests passed.' -ForegroundColor Green
}
finally {
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = (Resolve-Path -LiteralPath $testRoot).Path
        $expectedPrefix = [IO.Path]::GetFullPath((Join-Path $repoRoot 'work')).TrimEnd('\') + '\'
        if ($resolved.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $resolved -Recurse -Force }
    }
}

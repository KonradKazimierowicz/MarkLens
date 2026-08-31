$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
function Assert-True { param([bool]$Condition, [string]$Message) if (-not $Condition) { throw "ASSERTION FAILED: $Message" } }

$testRoot = Join-Path $repoRoot ('work\test-server-' + [guid]::NewGuid().ToString('N'))
$readyFile = Join-Path $testRoot 'ready.txt'
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$documentRoot = Join-Path $testRoot 'document'
$outsideRoot = Join-Path $testRoot 'outside'
New-Item -ItemType Directory -Path $documentRoot,$outsideRoot -Force | Out-Null
$documentPath = Join-Path $documentRoot 'security-demo.md'
Copy-Item -LiteralPath (Join-Path $repoRoot 'sample\security-demo.md') -Destination $documentPath
Set-Content -LiteralPath (Join-Path $documentRoot 'second.md') -Value '# Second document'
[IO.File]::WriteAllBytes((Join-Path $outsideRoot 'secret.png'), [byte[]](0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a))
New-Item -ItemType Junction -Path (Join-Path $documentRoot 'linked') -Target $outsideRoot | Out-Null
$process = $null
try {
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $repoRoot 'app\MarkLens.ps1'),'-Path',$documentPath,'-DataRoot',$testRoot,'-NoBrowser','-ReadyFile',$readyFile)
    $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $deadline = (Get-Date).AddSeconds(12)
    while (-not (Test-Path -LiteralPath $readyFile -PathType Leaf) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 100 }
    Assert-True (Test-Path -LiteralPath $readyFile -PathType Leaf) 'Loopback server did not become ready.'
    $url = [IO.File]::ReadAllText($readyFile).Trim()
    Assert-True ($url -match '^http://127\.0\.0\.1:\d+/$') 'Server must bind to the IPv4 loopback interface.'
    $page = Invoke-WebRequest -UseBasicParsing -Uri $url
    Assert-True ($page.StatusCode -eq 200) 'Viewer endpoint should return HTTP 200.'
    Assert-True ($page.Content -match '"isFolder":true') 'Opening a Markdown file should automatically enable folder mode.'
    Assert-True ($page.Content -match '"currentFile":"security-demo.md"') 'Opening a Markdown file should keep that file active.'
    $fileListing = Invoke-RestMethod -Uri ($url + 'api/files')
    Assert-True (@($fileListing.files) -contains 'second.md' -and @($fileListing.files) -contains 'security-demo.md') 'Opening a Markdown file should discover sibling Markdown files.'
    # Windows PowerShell exposes a header as a string, while PowerShell 7 may
    # expose the same value as a string collection. Normalize both shapes.
    $contentSecurityPolicy = [string]::Join(', ', [string[]]$page.Headers['Content-Security-Policy'])
    Assert-True ($contentSecurityPolicy -match "default-src 'none'") 'Viewer must send a restrictive CSP.'
    Assert-True ($page.Content -match '"csrfToken":"([^"]+)"') 'Bootstrap token is missing.'
    $token = $Matches[1]

    $favicon = Invoke-WebRequest -UseBasicParsing -Uri ($url + 'favicon.ico')
    Assert-True ($favicon.StatusCode -eq 200) 'Favicon endpoint should return HTTP 200.'
    Assert-True ([string]$favicon.Headers['Content-Type'] -eq 'image/x-icon') 'Favicon endpoint should return an icon content type.'
    Assert-True ($favicon.RawContentLength -gt 1000) 'Favicon endpoint should return the packaged multi-size icon.'

    $badStatus = 0
    try { Invoke-WebRequest -UseBasicParsing -Uri ($url + 'api/settings') -Method Put -Headers @{ 'X-MarkLens-Token'='wrong' } -ContentType 'application/json' -Body '{}' | Out-Null }
    catch { $badStatus = [int]$_.Exception.Response.StatusCode }
    Assert-True ($badStatus -eq 403) 'Mutating APIs must reject invalid CSRF tokens.'

    $defaultAppsStatus = 0
    try { Invoke-WebRequest -UseBasicParsing -Uri ($url + 'api/default-apps') -Method Post -Headers @{ 'X-MarkLens-Token'='wrong' } | Out-Null }
    catch { $defaultAppsStatus = [int]$_.Exception.Response.StatusCode }
    Assert-True ($defaultAppsStatus -eq 403) 'Default Apps launcher must reject invalid CSRF tokens.'

    $body = '{"theme":{"mode":"dark","light":{"background":"not-css"}},"branding":{"title":"Local Reader"}}'
    $saved = Invoke-RestMethod -Uri ($url + 'api/settings') -Method Put -Headers @{ 'X-MarkLens-Token'=$token } -ContentType 'application/json' -Body $body
    Assert-True ($saved.theme.mode -eq 'dark') 'Valid settings should persist through the API.'
    Assert-True ($saved.theme.light.background -eq '#f4f6f8') 'API must validate CSS values server-side.'

    $assetStatus = 0
    try { Invoke-WebRequest -UseBasicParsing -Uri ($url + 'api/document-asset?path=..%2F..%2FWindows%2Fwin.ini') | Out-Null }
    catch { $assetStatus = [int]$_.Exception.Response.StatusCode }
    Assert-True ($assetStatus -eq 404) 'Document assets must not escape the source directory.'

    $junctionStatus = 0
    try { Invoke-WebRequest -UseBasicParsing -Uri ($url + 'api/document-asset?path=linked%2Fsecret.png') | Out-Null }
    catch { $junctionStatus = [int]$_.Exception.Response.StatusCode }
    Assert-True ($junctionStatus -eq 404) 'Document assets must not escape through a junction or symlink.'

    Invoke-WebRequest -UseBasicParsing -Uri ($url + 'api/shutdown') -Method Post -Headers @{ 'X-MarkLens-Token'=$token } | Out-Null
    $process.WaitForExit(7000) | Out-Null
    Assert-True $process.HasExited 'Loopback server should stop after the viewer closes.'
    $process = $null

    # Folder mode: the server should list workspace files, serve them by relative
    # path, pick up newly created files, and refuse to escape the opened folder.
    Set-Content -LiteralPath (Join-Path $outsideRoot 'secret.md') -Value '# Outside'
    $folderReadyFile = Join-Path $testRoot 'ready-folder.txt'
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $repoRoot 'app\MarkLens.ps1'),'-Path',$documentRoot,'-DataRoot',$testRoot,'-NoBrowser','-ReadyFile',$folderReadyFile)
    $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $deadline = (Get-Date).AddSeconds(12)
    while (-not (Test-Path -LiteralPath $folderReadyFile -PathType Leaf) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 100 }
    Assert-True (Test-Path -LiteralPath $folderReadyFile -PathType Leaf) 'Folder-mode loopback server did not become ready.'
    $url = [IO.File]::ReadAllText($folderReadyFile).Trim()

    $page = Invoke-WebRequest -UseBasicParsing -Uri $url
    Assert-True ($page.Content -match '"isFolder":true') 'Folder mode should be announced to the viewer bootstrap.'

    $listing = Invoke-RestMethod -Uri ($url + 'api/files')
    Assert-True ([bool]$listing.isFolder) 'The file listing should report folder mode.'
    Assert-True (@($listing.files) -contains 'second.md' -and @($listing.files) -contains 'security-demo.md') 'The file listing should include every Markdown file in the folder.'
    Assert-True (-not (@($listing.files) -contains 'linked/secret.md')) 'The file listing must not traverse junctions.'

    $switched = Invoke-RestMethod -Uri ($url + 'api/document?path=second.md')
    Assert-True ($switched.fileName -eq 'second.md') 'Workspace documents should be served by relative path.'
    Assert-True ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($switched.markdownBase64)) -match 'Second document') 'Workspace documents should return their Markdown source.'

    foreach ($blocked in @('..%2Fsecret.md', 'linked%2Fsecret.md', 'C%3A%5CWindows%5Cwin.ini')) {
        $documentStatus = 0
        try { Invoke-WebRequest -UseBasicParsing -Uri ($url + 'api/document?path=' + $blocked) | Out-Null }
        catch { $documentStatus = [int]$_.Exception.Response.StatusCode }
        Assert-True ($documentStatus -eq 404) "Workspace documents must not escape the opened folder: $blocked"
    }

    Set-Content -LiteralPath (Join-Path $documentRoot 'created-later.md') -Value '# Created while open'
    $refreshed = Invoke-RestMethod -Uri ($url + 'api/files')
    Assert-True (@($refreshed.files) -contains 'created-later.md') 'New Markdown files should appear in the listing while the folder is open.'

    Assert-True ($page.Content -match '"csrfToken":"([^"]+)"') 'Folder-mode bootstrap token is missing.'
    Invoke-WebRequest -UseBasicParsing -Uri ($url + 'api/shutdown') -Method Post -Headers @{ 'X-MarkLens-Token'=$Matches[1] } | Out-Null
    $process.WaitForExit(7000) | Out-Null
    Assert-True $process.HasExited 'Folder-mode loopback server should stop after the viewer closes.'
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

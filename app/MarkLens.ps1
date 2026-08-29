<#
.SYNOPSIS
    Opens a local Markdown file or a folder of Markdown files in MarkLens.
.DESCRIPTION
    Generates a self-contained viewer snapshot in the per-user cache, serves it only
    on the IPv4 loopback interface, and launches Microsoft Edge in app mode. The
    loopback bridge exists so the settings panel can persist configuration without a
    cloud service or an elevated helper. When a folder is opened, the reader lists
    every Markdown file inside it and lets the viewer switch between them.
.PARAMETER Path
    Path to a .md or .markdown file, or to a folder containing Markdown files.
.PARAMETER NoLaunch
    Generate and print the cached HTML path without starting a browser or server.
.PARAMETER DataRoot
    Override the per-user data directory. Intended for tests.
#>
param(
    [Parameter(Position = 0)]
    [string]$Path,
    [switch]$NoLaunch,
    [string]$DataRoot,
    [ValidateRange(0, 65535)]
    [int]$Port = 0,
    [switch]$NoBrowser,
    [string]$ReadyFile
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'MarkLens.Core.psm1') -Force

function Show-MarkLensError {
    param([string]$Message)
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [Windows.Forms.MessageBox]::Show($Message, 'MarkLens', [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
    catch { Write-Error $Message }
}

function Find-MarkLensEdge {
    $registryPaths = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe'
    )
    foreach ($registryPath in $registryPaths) {
        if (Test-Path -LiteralPath $registryPath) {
            $value = (Get-Item -LiteralPath $registryPath).GetValue('')
            if ($value -and (Test-Path -LiteralPath $value -PathType Leaf)) { return $value }
        }
    }
    foreach ($candidate in @(
        'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
        'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
    )) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return $null
}

function Read-MarkLensHttpRequest {
    param([Parameter(Mandatory = $true)][IO.Stream]$Stream)
    $headerBytes = New-Object Collections.Generic.List[byte]
    $matched = 0
    $terminator = [byte[]](13, 10, 13, 10)
    while ($headerBytes.Count -lt 32768) {
        $value = $Stream.ReadByte()
        if ($value -lt 0) { throw 'Connection closed before the request was complete.' }
        $headerBytes.Add([byte]$value)
        if ($value -eq $terminator[$matched]) { $matched += 1 } else { $matched = if ($value -eq 13) { 1 } else { 0 } }
        if ($matched -eq 4) { break }
    }
    if ($matched -ne 4) { throw 'HTTP headers exceeded the 32 KB limit.' }
    $headerText = [Text.Encoding]::ASCII.GetString($headerBytes.ToArray())
    $lines = $headerText.Split(@("`r`n"), [StringSplitOptions]::None)
    if ($lines[0] -notmatch '^(GET|PUT|POST|DELETE) ([^ ]+) HTTP/1\.[01]$') { throw 'Unsupported HTTP request.' }
    $method = $Matches[1]
    $target = $Matches[2]
    $headers = @{}
    foreach ($line in $lines | Select-Object -Skip 1) {
        if ([string]::IsNullOrEmpty($line)) { break }
        $separator = $line.IndexOf(':')
        if ($separator -le 0) { throw 'Malformed HTTP header.' }
        $headers[$line.Substring(0, $separator).Trim()] = $line.Substring($separator + 1).Trim()
    }
    $contentLength = 0
    if ($headers.ContainsKey('Content-Length')) {
        if (-not [int]::TryParse($headers['Content-Length'], [ref]$contentLength) -or $contentLength -lt 0 -or $contentLength -gt 3MB) {
            throw 'Request body exceeds the 3 MB limit.'
        }
    }
    if ($headers.ContainsKey('Transfer-Encoding')) { throw 'Chunked requests are not supported.' }
    $body = New-Object byte[] $contentLength
    $offset = 0
    while ($offset -lt $contentLength) {
        $read = $Stream.Read($body, $offset, $contentLength - $offset)
        if ($read -le 0) { throw 'Connection closed before the request body was complete.' }
        $offset += $read
    }
    return [ordered]@{ Method = $method; Target = $target; Headers = $headers; Body = $body }
}

function Write-MarkLensHttpResponse {
    param(
        [Parameter(Mandatory = $true)][IO.Stream]$Stream,
        [int]$Status = 200,
        [string]$ContentType = 'text/plain; charset=utf-8',
        [byte[]]$Body = @(),
        [hashtable]$Headers = @{}
    )
    $reason = @{ 200='OK'; 204='No Content'; 400='Bad Request'; 403='Forbidden'; 404='Not Found'; 405='Method Not Allowed'; 413='Payload Too Large'; 415='Unsupported Media Type'; 500='Internal Server Error' }[$Status]
    if (-not $reason) { $reason = 'Error' }
    $allHeaders = [ordered]@{
        'Content-Type' = $ContentType
        'Content-Length' = $Body.Length
        'Connection' = 'close'
        'Cache-Control' = 'no-store'
        'X-Content-Type-Options' = 'nosniff'
        'Referrer-Policy' = 'no-referrer'
        'X-Frame-Options' = 'DENY'
        'Cross-Origin-Opener-Policy' = 'same-origin'
    }
    foreach ($key in $Headers.Keys) { $allHeaders[$key] = $Headers[$key] }
    $builder = New-Object Text.StringBuilder
    [void]$builder.Append("HTTP/1.1 $Status $reason`r`n")
    foreach ($key in $allHeaders.Keys) { [void]$builder.Append($key + ': ' + $allHeaders[$key] + "`r`n") }
    [void]$builder.Append("`r`n")
    $head = [Text.Encoding]::ASCII.GetBytes($builder.ToString())
    $Stream.Write($head, 0, $head.Length)
    if ($Body.Length -gt 0) { $Stream.Write($Body, 0, $Body.Length) }
    $Stream.Flush()
}

function ConvertTo-MarkLensJsonBytes {
    param($Value)
    return [Text.Encoding]::UTF8.GetBytes(($Value | ConvertTo-Json -Depth 20 -Compress))
}

function Test-MarkLensMutationToken {
    param($Request, [string]$Token)
    if (-not $Request.Headers.ContainsKey('X-MarkLens-Token')) { return $false }
    $actual = [Text.Encoding]::UTF8.GetBytes([string]$Request.Headers['X-MarkLens-Token'])
    $expected = [Text.Encoding]::UTF8.GetBytes($Token)
    if ($actual.Length -ne $expected.Length) { return $false }
    $difference = 0
    for ($index = 0; $index -lt $actual.Length; $index += 1) { $difference = $difference -bor ($actual[$index] -bxor $expected[$index]) }
    return $difference -eq 0
}

function Confirm-MarkLensMutationToken {
    param([IO.Stream]$Stream, $Request, [string]$Token)
    if (Test-MarkLensMutationToken $Request $Token) { return $true }
    Write-MarkLensHttpResponse -Stream $Stream -Status 403 -Body ([Text.Encoding]::UTF8.GetBytes('Invalid request token.'))
    return $false
}

function Get-MarkLensMimeType {
    param([string]$Extension)
    switch ($Extension.ToLowerInvariant()) {
        '.png' { 'image/png' } '.jpg' { 'image/jpeg' } '.jpeg' { 'image/jpeg' }
        '.gif' { 'image/gif' } '.webp' { 'image/webp' } default { $null }
    }
}

function Test-MarkLensImageBytes {
    param([byte[]]$Bytes, [string]$MimeType)
    if ($MimeType -eq 'image/png') {
        return $Bytes.Length -ge 8 -and $Bytes[0] -eq 0x89 -and $Bytes[1] -eq 0x50 -and $Bytes[2] -eq 0x4e -and $Bytes[3] -eq 0x47 -and $Bytes[4] -eq 0x0d -and $Bytes[5] -eq 0x0a -and $Bytes[6] -eq 0x1a -and $Bytes[7] -eq 0x0a
    }
    if ($MimeType -eq 'image/jpeg') { return $Bytes.Length -ge 3 -and $Bytes[0] -eq 0xff -and $Bytes[1] -eq 0xd8 -and $Bytes[2] -eq 0xff }
    return $false
}

try {
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'No Markdown file or folder path was provided.' }
    $workspace = Get-MarkLensWorkspace -Path $Path
    $document = Get-MarkLensDocument -Path $workspace.InitialFile
    $dataPaths = Initialize-MarkLensData -DataRoot $DataRoot
    $tokenBytes = New-Object byte[] 32
    $random = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $random.GetBytes($tokenBytes) } finally { $random.Dispose() }
    $token = [Convert]::ToBase64String($tokenBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')

    if ($NoLaunch) {
        $generated = New-MarkLensViewerHtml -DocumentPath $document.FullPath -CsrfToken $token -DataRoot $dataPaths.Root -Workspace $workspace
        Write-Output $generated.CachePath
        exit 0
    }

    $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $Port)
    $listener.Start()
    $actualPort = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    $url = 'http://127.0.0.1:' + $actualPort + '/'
    if (-not [string]::IsNullOrWhiteSpace($ReadyFile)) {
        $readyPath = [IO.Path]::GetFullPath($ReadyFile)
        [IO.File]::WriteAllText($readyPath, $url, (New-Object Text.UTF8Encoding($false)))
    }
    if (-not $NoBrowser) {
        $edge = Find-MarkLensEdge
        if ($edge) { Start-Process -FilePath $edge -ArgumentList ('--app="' + $url + '"') | Out-Null }
        else { Start-Process $url | Out-Null }
    }

    $lastRequest = Get-Date
    $shutdownAfter = $null
    while ($true) {
        if ($shutdownAfter -and (Get-Date) -ge $shutdownAfter) { break }
        if (((Get-Date) - $lastRequest).TotalHours -ge 24) { break }
        if (-not $listener.Pending()) { Start-Sleep -Milliseconds 60; continue }
        $client = $listener.AcceptTcpClient()
        try {
            $client.ReceiveTimeout = 3000
            $client.SendTimeout = 3000
            $stream = $client.GetStream()
            $request = Read-MarkLensHttpRequest -Stream $stream
            $lastRequest = Get-Date
            $targetParts = $request.Target.Split('?', 2)
            $route = $targetParts[0]

            if ($request.Method -eq 'GET' -and $route -eq '/') {
                $shutdownAfter = $null
                if ($workspace.IsFolder) { $workspace.Files = @(Get-MarkLensWorkspaceFiles -Root $workspace.Root) }
                $generated = New-MarkLensViewerHtml -DocumentPath $document.FullPath -CsrfToken $token -DataRoot $dataPaths.Root -Workspace $workspace
                $body = [Text.Encoding]::UTF8.GetBytes($generated.Html)
                $csp = "default-src 'none'; script-src 'nonce-$token'; style-src 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; font-src 'self' data:; base-uri 'none'; form-action 'none'; frame-src 'none'; object-src 'none'"
                Write-MarkLensHttpResponse -Stream $stream -ContentType 'text/html; charset=utf-8' -Body $body -Headers @{ 'Content-Security-Policy' = $csp }
            }
            elseif ($request.Method -eq 'GET' -and $route -eq '/favicon.ico') {
                $faviconPath = Join-Path $PSScriptRoot 'marklens.ico'
                if (-not (Test-Path -LiteralPath $faviconPath -PathType Leaf)) { Write-MarkLensHttpResponse -Stream $stream -Status 404 -Body @(); continue }
                Write-MarkLensHttpResponse -Stream $stream -ContentType 'image/x-icon' -Body ([IO.File]::ReadAllBytes($faviconPath)) -Headers @{ 'Cache-Control' = 'public, max-age=86400' }
            }
            elseif ($request.Method -eq 'GET' -and $route -eq '/api/settings') {
                Write-MarkLensHttpResponse -Stream $stream -ContentType 'application/json; charset=utf-8' -Body (ConvertTo-MarkLensJsonBytes (Read-MarkLensSettings -DataRoot $dataPaths.Root))
            }
            elseif ($request.Method -eq 'PUT' -and $route -eq '/api/settings') {
                if (-not (Confirm-MarkLensMutationToken $stream $request $token)) { continue }
                if ($request.Body.Length -gt 256KB) { Write-MarkLensHttpResponse -Stream $stream -Status 413 -Body ([Text.Encoding]::UTF8.GetBytes('Settings exceed 256 KB.')); continue }
                try {
                    $candidate = ConvertTo-MarkLensHashtable (ConvertFrom-Json ([Text.Encoding]::UTF8.GetString($request.Body)) -ErrorAction Stop)
                    $saved = Save-MarkLensSettings -Settings $candidate -DataRoot $dataPaths.Root
                    Write-MarkLensHttpResponse -Stream $stream -ContentType 'application/json; charset=utf-8' -Body (ConvertTo-MarkLensJsonBytes $saved)
                } catch { Write-MarkLensHttpResponse -Stream $stream -Status 400 -Body ([Text.Encoding]::UTF8.GetBytes('Invalid MarkLens settings JSON.')) }
            }
            elseif ($request.Method -eq 'GET' -and $route -eq '/api/logo') {
                $settings = Read-MarkLensSettings -DataRoot $dataPaths.Root
                $logoName = $settings.branding.logoFile
                if (-not $logoName) { Write-MarkLensHttpResponse -Stream $stream -Status 404 -Body ([Text.Encoding]::UTF8.GetBytes('No logo configured.')); continue }
                $logoPath = Join-Path $dataPaths.Assets $logoName
                if (-not (Test-Path -LiteralPath $logoPath -PathType Leaf)) { Write-MarkLensHttpResponse -Stream $stream -Status 404 -Body ([Text.Encoding]::UTF8.GetBytes('Logo not found.')); continue }
                Write-MarkLensHttpResponse -Stream $stream -ContentType (Get-MarkLensMimeType ([IO.Path]::GetExtension($logoName))) -Body ([IO.File]::ReadAllBytes($logoPath))
            }
            elseif ($request.Method -eq 'POST' -and $route -eq '/api/logo') {
                if (-not (Confirm-MarkLensMutationToken $stream $request $token)) { continue }
                try {
                    $payload = ConvertFrom-Json ([Text.Encoding]::UTF8.GetString($request.Body)) -ErrorAction Stop
                    if ($payload.type -notin @('image/png','image/jpeg')) { throw 'Only PNG and JPEG logos are supported.' }
                    $bytes = [Convert]::FromBase64String([string]$payload.data)
                    if ($bytes.Length -gt 2MB) { throw 'Logo exceeds the 2 MB limit.' }
                    if (-not (Test-MarkLensImageBytes $bytes $payload.type)) { throw 'The logo content does not match its declared image type.' }
                    $fileName = if ($payload.type -eq 'image/png') { 'logo.png' } else { 'logo.jpg' }
                    foreach ($oldName in @('logo.png','logo.jpg','logo.jpeg')) { $oldPath = Join-Path $dataPaths.Assets $oldName; if (Test-Path -LiteralPath $oldPath) { Remove-Item -LiteralPath $oldPath -Force } }
                    [IO.File]::WriteAllBytes((Join-Path $dataPaths.Assets $fileName), $bytes)
                    $settings = ConvertTo-MarkLensHashtable (Read-MarkLensSettings -DataRoot $dataPaths.Root)
                    $settings.branding.logoFile = $fileName; $settings.branding.showLogo = $true
                    $saved = Save-MarkLensSettings -Settings $settings -DataRoot $dataPaths.Root
                    Write-MarkLensHttpResponse -Stream $stream -ContentType 'application/json; charset=utf-8' -Body (ConvertTo-MarkLensJsonBytes $saved)
                } catch { Write-MarkLensHttpResponse -Stream $stream -Status 400 -Body ([Text.Encoding]::UTF8.GetBytes($_.Exception.Message)) }
            }
            elseif ($request.Method -eq 'DELETE' -and $route -eq '/api/logo') {
                if (-not (Confirm-MarkLensMutationToken $stream $request $token)) { continue }
                foreach ($name in @('logo.png','logo.jpg','logo.jpeg')) { $logoPath = Join-Path $dataPaths.Assets $name; if (Test-Path -LiteralPath $logoPath) { Remove-Item -LiteralPath $logoPath -Force } }
                $settings = ConvertTo-MarkLensHashtable (Read-MarkLensSettings -DataRoot $dataPaths.Root)
                $settings.branding.logoFile = $null; $settings.branding.showLogo = $false
                $saved = Save-MarkLensSettings -Settings $settings -DataRoot $dataPaths.Root
                Write-MarkLensHttpResponse -Stream $stream -ContentType 'application/json; charset=utf-8' -Body (ConvertTo-MarkLensJsonBytes $saved)
            }
            elseif ($request.Method -eq 'POST' -and $route -eq '/api/default-apps') {
                if (-not (Confirm-MarkLensMutationToken $stream $request $token)) { continue }
                try {
                    Start-Process 'ms-settings:defaultapps?registeredAppUser=MarkLens' | Out-Null
                    Write-MarkLensHttpResponse -Stream $stream -Status 204 -ContentType 'text/plain' -Body @()
                }
                catch { Write-MarkLensHttpResponse -Stream $stream -Status 500 -Body ([Text.Encoding]::UTF8.GetBytes('Could not open Windows Default Apps.')) }
            }
            elseif ($request.Method -eq 'GET' -and $route -eq '/api/files') {
                if ($workspace.IsFolder) { $workspace.Files = @(Get-MarkLensWorkspaceFiles -Root $workspace.Root) }
                $payload = [ordered]@{ isFolder = [bool]$workspace.IsFolder; root = $workspace.Root; files = @($workspace.Files) }
                Write-MarkLensHttpResponse -Stream $stream -ContentType 'application/json; charset=utf-8' -Body (ConvertTo-MarkLensJsonBytes $payload)
            }
            elseif ($request.Method -eq 'GET' -and $route -eq '/api/document') {
                try {
                    if ($targetParts.Count -ne 2 -or $targetParts[1] -notmatch '^path=(.*)$') { throw 'Missing document path.' }
                    $relative = [Uri]::UnescapeDataString($Matches[1])
                    $switched = Get-MarkLensWorkspaceDocument -Root $workspace.Root -RelativePath $relative
                    $document = $switched
                    $payload = [ordered]@{
                        fileName = $switched.FileName
                        fullPath = $switched.FullPath
                        relativePath = Get-MarkLensRelativePath -Root $workspace.Root -FullPath $switched.FullPath
                        markdownBase64 = $switched.Base64
                    }
                    Write-MarkLensHttpResponse -Stream $stream -ContentType 'application/json; charset=utf-8' -Body (ConvertTo-MarkLensJsonBytes $payload)
                } catch { Write-MarkLensHttpResponse -Stream $stream -Status 404 -Body ([Text.Encoding]::UTF8.GetBytes('Document unavailable.')) }
            }
            elseif ($request.Method -eq 'GET' -and $route -eq '/api/document-asset') {
                try {
                    if ($targetParts.Count -ne 2 -or $targetParts[1] -notmatch '^path=(.*)$') { throw 'Missing asset path.' }
                    $relative = [Uri]::UnescapeDataString($Matches[1]).Replace('/', [IO.Path]::DirectorySeparatorChar)
                    if ([IO.Path]::IsPathRooted($relative)) { throw 'Absolute asset paths are blocked.' }
                    if (Test-MarkLensPathHasReparsePoint -Root $workspace.Root -RelativePath $relative) { throw 'Reparse-point assets are blocked.' }
                    $assetPath = [IO.Path]::GetFullPath((Join-Path $workspace.Root $relative))
                    $documentRoot = [IO.Path]::GetFullPath($workspace.Root).TrimEnd('\') + '\'
                    if (-not $assetPath.StartsWith($documentRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Asset path leaves the opened folder.' }
                    $mime = Get-MarkLensMimeType ([IO.Path]::GetExtension($assetPath))
                    if (-not $mime -or -not (Test-Path -LiteralPath $assetPath -PathType Leaf)) { throw 'Asset type is not allowed or file is missing.' }
                    $assetItem = Get-Item -LiteralPath $assetPath
                    if ($assetItem.Length -gt 10MB) { throw 'Asset exceeds the 10 MB limit.' }
                    Write-MarkLensHttpResponse -Stream $stream -ContentType $mime -Body ([IO.File]::ReadAllBytes($assetPath))
                } catch { Write-MarkLensHttpResponse -Stream $stream -Status 404 -Body ([Text.Encoding]::UTF8.GetBytes('Local image unavailable.')) }
            }
            elseif ($request.Method -eq 'POST' -and $route -eq '/api/shutdown') {
                if (-not (Confirm-MarkLensMutationToken $stream $request $token)) { continue }
                $shutdownAfter = (Get-Date).AddSeconds(2)
                Write-MarkLensHttpResponse -Stream $stream -Status 204 -ContentType 'text/plain' -Body @()
            }
            else { Write-MarkLensHttpResponse -Stream $stream -Status 404 -Body ([Text.Encoding]::UTF8.GetBytes('Not found.')) }
        }
        catch {
            try { Write-MarkLensHttpResponse -Stream $client.GetStream() -Status 400 -Body ([Text.Encoding]::UTF8.GetBytes('Bad request.')) } catch { }
        }
        finally { $client.Close() }
    }
}
catch {
    if ($NoLaunch) { Write-Error $_.Exception.Message }
    else { Show-MarkLensError -Message $_.Exception.Message }
    exit 1
}
finally {
    if ($listener) { $listener.Stop() }
}

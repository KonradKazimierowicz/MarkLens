$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$vendorRoot = Join-Path $repoRoot 'app\vendor'
$manifest = ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $vendorRoot 'VERSIONS.json')))

foreach ($property in $manifest.PSObject.Properties) {
    $path = Join-Path $vendorRoot $property.Name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing vendored dependency: $($property.Name)" }
    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $property.Value.sha256) { throw "Hash mismatch for vendored dependency: $($property.Name)" }
}
Write-Host 'Vendored dependency hashes are valid.' -ForegroundColor Green

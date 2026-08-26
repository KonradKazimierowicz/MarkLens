$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $repoRoot 'app\MarkLens.Core.psm1') -Force

function Assert-True { param([bool]$Condition, [string]$Message) if (-not $Condition) { throw "ASSERTION FAILED: $Message" } }
function Assert-Equal { param($Actual, $Expected, [string]$Message) if ([string]$Actual -ne [string]$Expected) { throw "ASSERTION FAILED: $Message (expected '$Expected', got '$Actual')" } }

$testRoot = Join-Path $repoRoot ('work\test-core-' + [guid]::NewGuid().ToString('N'))
try {
    $paths = Initialize-MarkLensData -DataRoot $testRoot
    Assert-True (Test-Path -LiteralPath $paths.Settings -PathType Leaf) 'Default settings should be created.'
    Assert-True (Test-Path -LiteralPath $paths.CustomPresets -PathType Leaf) 'Custom presets should have a separate theme store.'
    foreach ($directory in @($paths.Config, $paths.Themes, $paths.Assets, $paths.Cache)) { Assert-True (Test-Path -LiteralPath $directory -PathType Container) "Missing data directory: $directory" }

    $candidate = ConvertTo-MarkLensHashtable (Get-MarkLensDefaultSettings)
    $candidate.theme.light.background = 'red; background:url(https://invalid.example)'
    $candidate.typography.fontBody = 'BadFont;src:url(https://invalid.example)'
    $candidate.typography.fontSize = 999
    $candidate.layout.maxWidth = -5
    $candidate.components.quoteStyle = 'script'
    $candidate.branding.logoFile = '..\escape.svg'
    $candidate.branding.title = '<script>alert(1)</script>'
    $candidate.customPresets = @(@{ id = 'custom-security-test'; name = 'Security test'; settings = @{ theme = @{ mode = 'dark' } } })
    $validated = Save-MarkLensSettings -Settings $candidate -DataRoot $testRoot
    Assert-Equal $validated.theme.light.background '#f4f6f8' 'CSS colors must be allowlisted.'
    Assert-Equal $validated.typography.fontBody 'Segoe UI' 'Fonts must be allowlisted.'
    Assert-Equal $validated.typography.fontSize 24 'Font size must be clamped.'
    Assert-Equal $validated.layout.maxWidth 560 'Document width must be clamped.'
    Assert-Equal $validated.components.quoteStyle 'line' 'Component styles must be allowlisted.'
    Assert-True ($null -eq $validated.branding.logoFile) 'Logo paths must not be user-controlled.'
    Assert-True ((ConvertFrom-Json ([IO.File]::ReadAllText($paths.CustomPresets))).Count -eq 1) 'Custom presets should persist in the separate theme store.'

    $samplePath = Join-Path $repoRoot 'sample\security-demo.md'
    $generated = New-MarkLensViewerHtml -DocumentPath $samplePath -CsrfToken 'test_nonce_123' -DataRoot $testRoot
    Assert-True (Test-Path -LiteralPath $generated.CachePath -PathType Leaf) 'Viewer cache should be generated.'
    Assert-True ($generated.Html.Contains('DOMPurify.sanitize')) 'Viewer must sanitize rendered Markdown.'
    Assert-True ($generated.Html.Contains('floatingSettingsButton')) 'Settings must remain reachable when the header is hidden.'
    Assert-True ($generated.Html.Contains("FORBID_TAGS: ['script'")) 'Viewer must explicitly forbid active tags.'
    Assert-True (-not ($generated.Html.Contains('/*__MARKLENS_CSS__*/') -or $generated.Html.Contains('/*__MARKLENS_APP_JS__*/') -or $generated.Html.Contains('/*__MARKLENS_BOOTSTRAP_JSON__*/'))) 'Generated HTML must not contain unresolved placeholders.'
    Assert-True ($generated.Html.Contains('\u003cscript\u003ealert(1)\u003c/script\u003e')) 'Settings embedded in scripts must escape angle brackets.'
    Assert-True ($generated.CachePath -match 'view-[0-9a-f]{16}\.html$') 'Cache keys should use a SHA-256 prefix.'

    $roundTrip = Read-MarkLensSettings -DataRoot $testRoot
    Assert-Equal $roundTrip.typography.fontSize 24 'Saved settings should round-trip.'
    Assert-True ($roundTrip.customPresets.Count -eq 1) 'Custom presets should round-trip with settings.'
    Write-Host 'Core tests passed.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = (Resolve-Path -LiteralPath $testRoot).Path
        $expectedPrefix = [IO.Path]::GetFullPath((Join-Path $repoRoot 'work')).TrimEnd('\') + '\'
        if ($resolved.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $resolved -Recurse -Force }
    }
}

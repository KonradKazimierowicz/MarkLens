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
    Assert-True ($generated.Html.Contains('MarkLensOnboarding')) 'Viewer must include the first-run onboarding component.'
    Assert-True ($generated.Html.Contains("FORBID_TAGS: ['script'")) 'Viewer must explicitly forbid active tags.'
    Assert-True (-not ($generated.Html.Contains('/*__MARKLENS_CSS__*/') -or $generated.Html.Contains('/*__MARKLENS_APP_JS__*/') -or $generated.Html.Contains('/*__MARKLENS_ONBOARDING_JS__*/') -or $generated.Html.Contains('/*__MARKLENS_BOOTSTRAP_JSON__*/'))) 'Generated HTML must not contain unresolved placeholders.'
    Assert-True ($generated.Html.Contains('\u003cscript\u003ealert(1)\u003c/script\u003e')) 'Settings embedded in scripts must escape angle brackets.'
    Assert-True ($generated.CachePath -match 'view-[0-9a-f]{16}\.html$') 'Cache keys should use a SHA-256 prefix.'

    $roundTrip = Read-MarkLensSettings -DataRoot $testRoot
    Assert-Equal $roundTrip.typography.fontSize 24 'Saved settings should round-trip.'
    Assert-True ($roundTrip.customPresets.Count -eq 1) 'Custom presets should round-trip with settings.'

    $workspaceRoot = Join-Path $testRoot 'workspace'
    foreach ($directory in @('docs', 'node_modules\package', '.hidden')) {
        New-Item -ItemType Directory -Path (Join-Path $workspaceRoot $directory) -Force | Out-Null
    }
    Set-Content -LiteralPath (Join-Path $workspaceRoot 'README.md') -Value '# Readme'
    Set-Content -LiteralPath (Join-Path $workspaceRoot 'notes.md') -Value '# Notes'
    Set-Content -LiteralPath (Join-Path $workspaceRoot 'docs\guide.markdown') -Value '# Guide'
    Set-Content -LiteralPath (Join-Path $workspaceRoot 'docs\image.png') -Value 'not markdown'
    Set-Content -LiteralPath (Join-Path $workspaceRoot 'node_modules\package\skipped.md') -Value '# Skipped'
    Set-Content -LiteralPath (Join-Path $workspaceRoot '.hidden\skipped.md') -Value '# Skipped'
    New-Item -ItemType Junction -Path (Join-Path $workspaceRoot 'linked') -Target $testRoot | Out-Null

    $workspace = Get-MarkLensWorkspace -Path $workspaceRoot
    Assert-True $workspace.IsFolder 'A folder path should open in folder mode.'
    Assert-Equal (@($workspace.Files) -join '|') 'docs/guide.markdown|notes.md|README.md' 'Workspace scans must list Markdown files recursively, sorted, and skip hidden, dependency, and junction directories.'
    Assert-Equal ([IO.Path]::GetFileName($workspace.InitialFile)) 'README.md' 'Folder mode should open the README first.'

    $fileWorkspace = Get-MarkLensWorkspace -Path $samplePath
    Assert-True (-not $fileWorkspace.IsFolder) 'A file path should keep single-file mode.'
    Assert-Equal (@($fileWorkspace.Files) -join '|') 'security-demo.md' 'Single-file mode should expose only the opened document.'

    $switched = Get-MarkLensWorkspaceDocument -Root $workspaceRoot -RelativePath 'docs/guide.markdown'
    Assert-Equal $switched.FileName 'guide.markdown' 'Workspace documents should resolve by relative path.'
    foreach ($blocked in @('..\..\Windows\win.ini', 'docs/../../escape.md', 'linked/README.md', 'C:\Windows\win.ini', 'docs/image.png')) {
        $failed = $false
        try { Get-MarkLensWorkspaceDocument -Root $workspaceRoot -RelativePath $blocked | Out-Null } catch { $failed = $true }
        Assert-True $failed "Workspace documents must reject unsafe path: $blocked"
    }

    $folderHtml = New-MarkLensViewerHtml -DocumentPath $workspace.InitialFile -CsrfToken 'test_nonce_123' -DataRoot $testRoot -Workspace $workspace
    Assert-True ($folderHtml.Html.Contains('"isFolder":true')) 'Folder mode should be announced to the viewer bootstrap.'
    Assert-True ($folderHtml.Html.Contains('docs/guide.markdown')) 'Folder mode bootstrap should list workspace files.'
    Assert-True ($generated.Html.Contains('"isFolder":false')) 'Single-file mode should be announced to the viewer bootstrap.'
    Write-Host 'Core tests passed.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = (Resolve-Path -LiteralPath $testRoot).Path
        $expectedPrefix = [IO.Path]::GetFullPath((Join-Path $repoRoot 'work')).TrimEnd('\') + '\'
        if ($resolved.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $resolved -Recurse -Force }
    }
}

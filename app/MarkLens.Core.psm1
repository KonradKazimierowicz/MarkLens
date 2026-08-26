Set-StrictMode -Version 2.0

$script:ApplicationName = 'MarkLens'
$script:MaxDocumentBytes = 10MB
$script:MaxSettingsBytes = 256KB

function ConvertTo-MarkLensHashtable {
    param([Parameter(ValueFromPipeline = $true)]$InputObject)

    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($key in $InputObject.Keys) {
            $result[[string]$key] = ConvertTo-MarkLensHashtable $InputObject[$key]
        }
        return $result
    }
    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        $items = @()
        foreach ($item in $InputObject) { $items += ,(ConvertTo-MarkLensHashtable $item) }
        return $items
    }
    if ($InputObject -is [psobject] -and @($InputObject.PSObject.Properties).Count -gt 0 -and
        -not ($InputObject -is [ValueType]) -and -not ($InputObject -is [string])) {
        $result = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $result[$property.Name] = ConvertTo-MarkLensHashtable $property.Value
        }
        return $result
    }
    return $InputObject
}

function Get-MarkLensNestedValue {
    param([hashtable]$Source, [string[]]$Path, $Fallback)

    $current = $Source
    foreach ($segment in $Path) {
        if ($current -isnot [System.Collections.IDictionary] -or -not $current.ContainsKey($segment)) {
            return $Fallback
        }
        $current = $current[$segment]
    }
    if ($null -eq $current) { return $Fallback }
    return $current
}

function Test-MarkLensColor {
    param($Value, [string]$Fallback)
    $text = [string]$Value
    if ($text -match '^#[0-9a-fA-F]{6}$') { return $text.ToLowerInvariant() }
    return $Fallback
}

function Get-MarkLensNumber {
    param($Value, [double]$Fallback, [double]$Minimum, [double]$Maximum, [switch]$Integer)
    $number = 0.0
    if (-not [double]::TryParse([string]$Value, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
        return $Fallback
    }
    $number = [Math]::Max($Minimum, [Math]::Min($Maximum, $number))
    if ($Integer) { return [int][Math]::Round($number) }
    return [Math]::Round($number, 2)
}

function Get-MarkLensEnum {
    param($Value, [string]$Fallback, [string[]]$Allowed)
    $text = [string]$Value
    if ($Allowed -contains $text) { return $text }
    return $Fallback
}

function Get-MarkLensBoolean {
    param($Value, [bool]$Fallback)
    if ($Value -is [bool]) { return $Value }
    if ([string]$Value -eq 'true') { return $true }
    if ([string]$Value -eq 'false') { return $false }
    return $Fallback
}

function Get-MarkLensText {
    param($Value, [string]$Fallback, [int]$MaximumLength)
    if ($null -eq $Value) { return $Fallback }
    $text = ([string]$Value).Trim()
    $text = $text -replace '[\x00-\x1f\x7f]', ''
    if ([string]::IsNullOrWhiteSpace($text)) { return $Fallback }
    if ($text.Length -gt $MaximumLength) { $text = $text.Substring(0, $MaximumLength) }
    return $text
}

function Get-MarkLensDefaultSettings {
    $path = Join-Path $PSScriptRoot 'default-settings.json'
    $json = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    return ConvertTo-MarkLensHashtable (ConvertFrom-Json $json)
}

function Get-MarkLensValidatedSettings {
    param([hashtable]$Candidate, [switch]$SkipCustomPresets)

    if ($null -eq $Candidate) { $Candidate = @{} }
    $defaults = Get-MarkLensDefaultSettings
    $fontChoices = @('Segoe UI', 'Arial', 'Calibri', 'Georgia', 'Times New Roman', 'Verdana', 'Trebuchet MS', 'Cascadia Mono', 'Consolas')
    $paletteKeys = @('background', 'surface', 'surfaceAlt', 'text', 'muted', 'heading', 'link', 'accent', 'border', 'codeBackground', 'codeText', 'inlineCodeBackground', 'quoteBackground', 'tableStripe', 'scrollbar')

    $result = [ordered]@{
        schemaVersion = 1
        theme = [ordered]@{
            mode = Get-MarkLensEnum (Get-MarkLensNestedValue $Candidate @('theme','mode') $defaults.theme.mode) $defaults.theme.mode @('auto','light','dark')
            light = [ordered]@{}
            dark = [ordered]@{}
        }
        typography = [ordered]@{
            fontBody = Get-MarkLensEnum (Get-MarkLensNestedValue $Candidate @('typography','fontBody') $defaults.typography.fontBody) $defaults.typography.fontBody $fontChoices
            fontHeading = Get-MarkLensEnum (Get-MarkLensNestedValue $Candidate @('typography','fontHeading') $defaults.typography.fontHeading) $defaults.typography.fontHeading $fontChoices
            fontCode = Get-MarkLensEnum (Get-MarkLensNestedValue $Candidate @('typography','fontCode') $defaults.typography.fontCode) $defaults.typography.fontCode $fontChoices
            fontSize = Get-MarkLensNumber (Get-MarkLensNestedValue $Candidate @('typography','fontSize') $defaults.typography.fontSize) $defaults.typography.fontSize 12 24 -Integer
            lineHeight = Get-MarkLensNumber (Get-MarkLensNestedValue $Candidate @('typography','lineHeight') $defaults.typography.lineHeight) $defaults.typography.lineHeight 1.2 2.2
            headingScale = Get-MarkLensNumber (Get-MarkLensNestedValue $Candidate @('typography','headingScale') $defaults.typography.headingScale) $defaults.typography.headingScale 0.85 1.35
        }
        layout = [ordered]@{
            maxWidth = Get-MarkLensNumber (Get-MarkLensNestedValue $Candidate @('layout','maxWidth') $defaults.layout.maxWidth) $defaults.layout.maxWidth 560 1600 -Integer
            contentPadding = Get-MarkLensNumber (Get-MarkLensNestedValue $Candidate @('layout','contentPadding') $defaults.layout.contentPadding) $defaults.layout.contentPadding 12 72 -Integer
            blockSpacing = Get-MarkLensNumber (Get-MarkLensNestedValue $Candidate @('layout','blockSpacing') $defaults.layout.blockSpacing) $defaults.layout.blockSpacing 0.6 2.5
        }
        components = [ordered]@{
            radius = Get-MarkLensNumber (Get-MarkLensNestedValue $Candidate @('components','radius') $defaults.components.radius) $defaults.components.radius 0 28 -Integer
            shadow = Get-MarkLensEnum (Get-MarkLensNestedValue $Candidate @('components','shadow') $defaults.components.shadow) $defaults.components.shadow @('none','soft','medium')
            quoteStyle = Get-MarkLensEnum (Get-MarkLensNestedValue $Candidate @('components','quoteStyle') $defaults.components.quoteStyle) $defaults.components.quoteStyle @('line','card','italic')
            tableStyle = Get-MarkLensEnum (Get-MarkLensNestedValue $Candidate @('components','tableStyle') $defaults.components.tableStyle) $defaults.components.tableStyle @('lines','striped','minimal')
            separatorStyle = Get-MarkLensEnum (Get-MarkLensNestedValue $Candidate @('components','separatorStyle') $defaults.components.separatorStyle) $defaults.components.separatorStyle @('solid','dashed','fade')
            scrollbarWidth = Get-MarkLensEnum (Get-MarkLensNestedValue $Candidate @('components','scrollbarWidth') $defaults.components.scrollbarWidth) $defaults.components.scrollbarWidth @('thin','regular','wide')
        }
        branding = [ordered]@{
            showHeader = Get-MarkLensBoolean (Get-MarkLensNestedValue $Candidate @('branding','showHeader') $defaults.branding.showHeader) $defaults.branding.showHeader
            showLogo = Get-MarkLensBoolean (Get-MarkLensNestedValue $Candidate @('branding','showLogo') $defaults.branding.showLogo) $defaults.branding.showLogo
            showFileName = Get-MarkLensBoolean (Get-MarkLensNestedValue $Candidate @('branding','showFileName') $defaults.branding.showFileName) $defaults.branding.showFileName
            showFilePath = Get-MarkLensBoolean (Get-MarkLensNestedValue $Candidate @('branding','showFilePath') $defaults.branding.showFilePath) $defaults.branding.showFilePath
            title = Get-MarkLensText (Get-MarkLensNestedValue $Candidate @('branding','title') $defaults.branding.title) $defaults.branding.title 80
            workspace = Get-MarkLensText (Get-MarkLensNestedValue $Candidate @('branding','workspace') $defaults.branding.workspace) $defaults.branding.workspace 80
            logoFile = $null
            useLogoAsFavicon = Get-MarkLensBoolean (Get-MarkLensNestedValue $Candidate @('branding','useLogoAsFavicon') $defaults.branding.useLogoAsFavicon) $defaults.branding.useLogoAsFavicon
        }
        behavior = [ordered]@{
            showTableOfContents = Get-MarkLensBoolean (Get-MarkLensNestedValue $Candidate @('behavior','showTableOfContents') $defaults.behavior.showTableOfContents) $defaults.behavior.showTableOfContents
            autoHideToolbar = Get-MarkLensBoolean (Get-MarkLensNestedValue $Candidate @('behavior','autoHideToolbar') $defaults.behavior.autoHideToolbar) $defaults.behavior.autoHideToolbar
        }
        customPresets = @()
    }

    foreach ($mode in @('light','dark')) {
        foreach ($key in $paletteKeys) {
            $fallback = $defaults.theme[$mode][$key]
            $result.theme[$mode][$key] = Test-MarkLensColor (Get-MarkLensNestedValue $Candidate @('theme',$mode,$key) $fallback) $fallback
        }
    }

    $logoFile = Get-MarkLensNestedValue $Candidate @('branding','logoFile') $null
    if ($logoFile -in @('logo.png','logo.jpg','logo.jpeg')) { $result.branding.logoFile = $logoFile }

    if (-not $SkipCustomPresets) {
        $presets = Get-MarkLensNestedValue $Candidate @('customPresets') @()
        $seen = @{}
        foreach ($preset in @($presets) | Select-Object -First 20) {
            $presetTable = ConvertTo-MarkLensHashtable $preset
            if ($presetTable -isnot [hashtable]) { continue }
            $name = Get-MarkLensText $presetTable.name '' 40
            $id = Get-MarkLensText $presetTable.id '' 48
            if ($id -notmatch '^custom-[a-z0-9-]{1,40}$' -or [string]::IsNullOrWhiteSpace($name) -or $seen.ContainsKey($id)) { continue }
            $settingsCandidate = if ($presetTable.settings -is [hashtable]) { $presetTable.settings } else { @{} }
            $validated = Get-MarkLensValidatedSettings -Candidate $settingsCandidate -SkipCustomPresets
            $result.customPresets += [ordered]@{
                id = $id
                name = $name
                settings = [ordered]@{
                    theme = $validated.theme
                    typography = $validated.typography
                    layout = $validated.layout
                    components = $validated.components
                }
            }
            $seen[$id] = $true
        }
    }

    return $result
}

function Get-MarkLensPaths {
    param([string]$DataRoot)
    if ([string]::IsNullOrWhiteSpace($DataRoot)) {
        if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { throw 'LOCALAPPDATA is unavailable.' }
        $DataRoot = Join-Path $env:LOCALAPPDATA $script:ApplicationName
    }
    $root = [IO.Path]::GetFullPath($DataRoot)
    return [ordered]@{
        Root = $root
        Config = Join-Path $root 'config'
        Settings = Join-Path $root 'config\settings.json'
        Themes = Join-Path $root 'themes'
        CustomPresets = Join-Path $root 'themes\custom-presets.json'
        Assets = Join-Path $root 'assets'
        Cache = Join-Path $root 'cache'
    }
}

function Initialize-MarkLensData {
    param([string]$DataRoot)
    $paths = Get-MarkLensPaths -DataRoot $DataRoot
    foreach ($key in @('Root','Config','Themes','Assets','Cache')) {
        New-Item -ItemType Directory -Path $paths[$key] -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $paths.Settings -PathType Leaf)) {
        Save-MarkLensSettings -Settings (Get-MarkLensDefaultSettings) -DataRoot $paths.Root | Out-Null
    }
    return $paths
}

function Read-MarkLensSettings {
    param([string]$DataRoot)
    $paths = Initialize-MarkLensData -DataRoot $DataRoot
    try {
        $item = Get-Item -LiteralPath $paths.Settings -ErrorAction Stop
        if ($item.Length -gt $script:MaxSettingsBytes) { throw 'Settings file is too large.' }
        $json = [IO.File]::ReadAllText($paths.Settings, [Text.Encoding]::UTF8)
        $candidate = ConvertTo-MarkLensHashtable (ConvertFrom-Json $json -ErrorAction Stop)
    }
    catch {
        $backup = $paths.Settings + '.invalid-' + (Get-Date -Format 'yyyyMMddHHmmss')
        if (Test-Path -LiteralPath $paths.Settings) { Copy-Item -LiteralPath $paths.Settings -Destination $backup -Force }
        $defaults = Get-MarkLensValidatedSettings -Candidate @{}
        Save-MarkLensSettings -Settings $defaults -DataRoot $paths.Root | Out-Null
        $candidate = ConvertTo-MarkLensHashtable $defaults
    }
    if (Test-Path -LiteralPath $paths.CustomPresets -PathType Leaf) {
        try {
            $presetItem = Get-Item -LiteralPath $paths.CustomPresets -ErrorAction Stop
            if ($presetItem.Length -gt $script:MaxSettingsBytes) { throw 'Custom presets file is too large.' }
            $presetJson = [IO.File]::ReadAllText($paths.CustomPresets, [Text.Encoding]::UTF8)
            $candidate.customPresets = @(ConvertTo-MarkLensHashtable (ConvertFrom-Json $presetJson -ErrorAction Stop))
        }
        catch {
            $presetBackup = $paths.CustomPresets + '.invalid-' + (Get-Date -Format 'yyyyMMddHHmmss')
            Copy-Item -LiteralPath $paths.CustomPresets -Destination $presetBackup -Force -ErrorAction SilentlyContinue
            $candidate.customPresets = @()
        }
    }
    return Get-MarkLensValidatedSettings -Candidate $candidate
}

function Save-MarkLensSettings {
    param([Parameter(Mandatory = $true)]$Settings, [string]$DataRoot)
    $paths = Get-MarkLensPaths -DataRoot $DataRoot
    New-Item -ItemType Directory -Path $paths.Config -Force | Out-Null
    $candidate = ConvertTo-MarkLensHashtable $Settings
    $validated = Get-MarkLensValidatedSettings -Candidate $candidate
    New-Item -ItemType Directory -Path $paths.Themes -Force | Out-Null
    $settingsDocument = ConvertTo-MarkLensHashtable $validated
    $presetDocument = @($settingsDocument.customPresets)
    $settingsDocument.customPresets = @()
    $json = $settingsDocument | ConvertTo-Json -Depth 20
    $presetJson = ConvertTo-Json -InputObject $presetDocument -Depth 20
    $tempPath = $paths.Settings + '.tmp-' + [guid]::NewGuid().ToString('N')
    $presetTempPath = $paths.CustomPresets + '.tmp-' + [guid]::NewGuid().ToString('N')
    $utf8NoBom = New-Object Text.UTF8Encoding($false)
    try {
        [IO.File]::WriteAllText($tempPath, $json + [Environment]::NewLine, $utf8NoBom)
        [IO.File]::WriteAllText($presetTempPath, $presetJson + [Environment]::NewLine, $utf8NoBom)
        Move-Item -LiteralPath $tempPath -Destination $paths.Settings -Force
        Move-Item -LiteralPath $presetTempPath -Destination $paths.CustomPresets -Force
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $presetTempPath) { Remove-Item -LiteralPath $presetTempPath -Force -ErrorAction SilentlyContinue }
    }
    return $validated
}

function ConvertTo-MarkLensSafeJson {
    param($Value, [int]$Depth = 20)
    $json = $Value | ConvertTo-Json -Depth $Depth -Compress
    return $json.Replace('&', '\u0026').Replace('<', '\u003c').Replace('>', '\u003e').Replace([string][char]0x2028, '\u2028').Replace([string][char]0x2029, '\u2029')
}

function Get-MarkLensDocument {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'The Markdown file does not exist.' }
    $fullPath = (Resolve-Path -LiteralPath $Path).Path
    if ([IO.Path]::GetExtension($fullPath).ToLowerInvariant() -notin @('.md','.markdown')) { throw 'Only .md and .markdown files are supported.' }
    $item = Get-Item -LiteralPath $fullPath
    if ($item.Length -gt $script:MaxDocumentBytes) { throw 'The Markdown file exceeds the 10 MB safety limit.' }
    $bytes = [IO.File]::ReadAllBytes($fullPath)
    return [ordered]@{
        FullPath = $fullPath
        Directory = [IO.Path]::GetDirectoryName($fullPath)
        FileName = [IO.Path]::GetFileName($fullPath)
        Base64 = [Convert]::ToBase64String($bytes)
    }
}

function Get-MarkLensCachePath {
    param([Parameter(Mandatory = $true)][string]$DocumentPath, [string]$DataRoot)
    $paths = Initialize-MarkLensData -DataRoot $DataRoot
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($DocumentPath.ToLowerInvariant())) }
    finally { $sha.Dispose() }
    $hex = -join ($hash | ForEach-Object { $_.ToString('x2') })
    return Join-Path $paths.Cache ('view-' + $hex.Substring(0, 16) + '.html')
}

function New-MarkLensViewerHtml {
    param(
        [Parameter(Mandatory = $true)][string]$DocumentPath,
        [Parameter(Mandatory = $true)][string]$CsrfToken,
        [string]$DataRoot
    )
    $document = Get-MarkLensDocument -Path $DocumentPath
    $settings = Read-MarkLensSettings -DataRoot $DataRoot
    $template = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'viewer.template.html'), [Text.Encoding]::UTF8)
    $css = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'viewer.css'), [Text.Encoding]::UTF8)
    $appJs = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'viewer.js'), [Text.Encoding]::UTF8)
    $marked = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'vendor\marked.umd.js'), [Text.Encoding]::UTF8)
    $purify = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'vendor\purify.min.js'), [Text.Encoding]::UTF8)
    $highlight = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'vendor\highlight.min.js'), [Text.Encoding]::UTF8)
    $presets = ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'presets.json'), [Text.Encoding]::UTF8))
    $bootstrap = [pscustomobject]@{
        csrfToken = $CsrfToken
        document = [ordered]@{ fileName = $document.FileName; fullPath = $document.FullPath; directory = $document.Directory; markdownBase64 = $document.Base64 }
        settings = $settings
        defaultSettings = Get-MarkLensValidatedSettings -Candidate @{}
        builtInPresets = @($presets)
        limits = [ordered]@{ logoBytes = 2MB }
    }
    $bootstrapJson = ConvertTo-MarkLensSafeJson $bootstrap
    $html = $template.
        Replace('__MARKLENS_NONCE__', $CsrfToken).
        Replace('/*__MARKLENS_CSS__*/', $css).
        Replace('/*__MARKED_JS__*/', $marked).
        Replace('/*__DOMPURIFY_JS__*/', $purify).
        Replace('/*__HIGHLIGHT_JS__*/', $highlight).
        Replace('/*__MARKLENS_BOOTSTRAP_JSON__*/', $bootstrapJson).
        Replace('/*__MARKLENS_APP_JS__*/', $appJs)
    $cachePath = Get-MarkLensCachePath -DocumentPath $document.FullPath -DataRoot $DataRoot
    $utf8NoBom = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($cachePath, $html, $utf8NoBom)
    return [ordered]@{ Html = $html; CachePath = $cachePath; Document = $document; Settings = $settings }
}

Export-ModuleMember -Function @(
    'ConvertTo-MarkLensHashtable', 'Get-MarkLensDefaultSettings', 'Get-MarkLensValidatedSettings',
    'Get-MarkLensPaths', 'Initialize-MarkLensData', 'Read-MarkLensSettings', 'Save-MarkLensSettings',
    'Get-MarkLensDocument', 'Get-MarkLensCachePath', 'New-MarkLensViewerHtml'
)

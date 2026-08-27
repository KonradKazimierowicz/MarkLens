$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
function Assert-True { param([bool]$Condition, [string]$Message) if (-not $Condition) { throw "ASSERTION FAILED: $Message" } }

$testRoot = Join-Path $repoRoot ('work\test-installer-' + [guid]::NewGuid().ToString('N'))
$payloadRoot = Join-Path $testRoot 'payload'
$packageRoot = Join-Path $testRoot 'package'
$installRoot = Join-Path $testRoot 'installed'
New-Item -ItemType Directory -Path $payloadRoot,$packageRoot -Force | Out-Null

try {
    foreach ($item in @('app','install.ps1','uninstall.ps1','VERSION')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot $item) -Destination $payloadRoot -Recurse -Force
    }
    $payloadZip = Join-Path $packageRoot 'payload.zip'
    Compress-Archive -Path (Join-Path $payloadRoot '*') -DestinationPath $payloadZip -CompressionLevel Fastest
    Copy-Item -LiteralPath (Join-Path $repoRoot 'installer\Install-MarkLens.ps1') -Destination $packageRoot
    Copy-Item -LiteralPath (Join-Path $repoRoot 'installer\install.vbs') -Destination $packageRoot

    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $arguments = @('//nologo',(Join-Path $packageRoot 'install.vbs'),'/quiet','/skipregistration',('/installroot:' + $installRoot))
    $process = Start-Process -FilePath 'cscript.exe' -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
    $stopwatch.Stop()

    Assert-True ($process.ExitCode -eq 0) 'Quiet installer wrapper should return a successful exit code.'
    Assert-True ($stopwatch.Elapsed.TotalSeconds -lt 20) 'Quiet installation must not wait for a hidden completion dialog.'
    Assert-True (Test-Path -LiteralPath (Join-Path $installRoot 'app\MarkLens.ps1') -PathType Leaf) 'Installed payload is incomplete.'
    Assert-True (([IO.File]::ReadAllText((Join-Path $installRoot 'VERSION')).Trim()) -eq ([IO.File]::ReadAllText((Join-Path $repoRoot 'VERSION')).Trim())) 'Installed version should match the source payload.'
    $installedRegistration = [IO.File]::ReadAllText((Join-Path $installRoot 'install.ps1'))
    Assert-True ($installedRegistration.Contains('ms-settings:defaultapps?registeredAppUser=MarkLens')) 'Installer should provide the MarkLens-specific Windows Default Apps flow.'
    Assert-True ($installedRegistration.Contains("ApplicationName -Value 'MarkLens'")) 'File chooser registration should display the MarkLens application name instead of the script host name.'
    Assert-True ($installedRegistration.Contains('ApplicationIcon')) 'File chooser registration should use the MarkLens application icon.'
    $installerSource = [IO.File]::ReadAllText((Join-Path $repoRoot 'installer\Install-MarkLens.ps1'))
    Assert-True ($installerSource.Contains('-OpenDefaultApps:(-not $Quiet)')) 'Interactive install should open Default Apps while quiet install stays non-interactive.'
    Write-Host 'Installer tests passed.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = (Resolve-Path -LiteralPath $testRoot).Path
        $expectedPrefix = [IO.Path]::GetFullPath((Join-Path $repoRoot 'work')).TrimEnd('\') + '\'
        if ($resolved.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $resolved -Recurse -Force }
    }
}

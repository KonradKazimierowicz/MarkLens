param([switch]$KeepBuildFiles)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$version = [IO.File]::ReadAllText((Join-Path $repoRoot 'VERSION')).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'VERSION must use semantic versioning (X.Y.Z).' }
$distRoot = Join-Path $repoRoot 'dist'
$buildRoot = Join-Path $repoRoot 'work\installer-build'
$payloadRoot = Join-Path $buildRoot 'payload'
$sourceRoot = Join-Path $buildRoot 'iexpress-source'
$payloadZip = Join-Path $sourceRoot 'payload.zip'
$setupName = 'MarkLens-Setup-v' + $version + '.exe'
$setupPath = Join-Path $distRoot $setupName
$sedPath = Join-Path $buildRoot 'package.sed'

if (Test-Path -LiteralPath $buildRoot) {
    $resolvedBuild = (Resolve-Path -LiteralPath $buildRoot).Path
    $resolvedRepo = (Resolve-Path -LiteralPath $repoRoot).Path
    if (-not $resolvedBuild.StartsWith($resolvedRepo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe build path: $resolvedBuild" }
    Remove-Item -LiteralPath $resolvedBuild -Recurse -Force
}
New-Item -ItemType Directory -Path $payloadRoot -Force | Out-Null
New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null
New-Item -ItemType Directory -Path $distRoot -Force | Out-Null

if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'app\marklens.ico'))) { & (Join-Path $repoRoot 'tools\make-icon.ps1') | Out-Null }
foreach ($item in @('app','sample','docs','install.ps1','uninstall.ps1','README.md','CHANGELOG.md','CONTRIBUTING.md','PRIVACY.md','LICENSE','THIRD_PARTY_NOTICES.md','VERSION')) {
    Copy-Item -LiteralPath (Join-Path $repoRoot $item) -Destination $payloadRoot -Recurse -Force
}
$payloadTools = Join-Path $payloadRoot 'tools'
New-Item -ItemType Directory -Path $payloadTools -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repoRoot 'tools\make-icon.ps1') -Destination $payloadTools
Copy-Item -LiteralPath (Join-Path $repoRoot 'installer\Install-MarkLens.ps1') -Destination $sourceRoot
Copy-Item -LiteralPath (Join-Path $repoRoot 'installer\install.vbs') -Destination $sourceRoot
Compress-Archive -Path (Join-Path $payloadRoot '*') -DestinationPath $payloadZip -CompressionLevel Optimal -Force

$sourceWithSlash = $sourceRoot.TrimEnd('\') + '\'
$sed = @"
[Version]
Class=IEXPRESS
SEDVersion=3

[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=%InstallPrompt%
DisplayLicense=%DisplayLicense%
FinishMessage=%FinishMessage%
TargetName=%TargetName%
FriendlyName=%FriendlyName%
AppLaunched=%AppLaunched%
PostInstallCmd=%PostInstallCmd%
AdminQuietInstCmd=%AdminQuietInstCmd%
UserQuietInstCmd=%UserQuietInstCmd%
SourceFiles=SourceFiles

[Strings]
InstallPrompt=
DisplayLicense=
FinishMessage=
TargetName=$setupPath
FriendlyName=MarkLens Setup
AppLaunched=wscript.exe install.vbs
PostInstallCmd=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
FILE0="install.vbs"
FILE1="Install-MarkLens.ps1"
FILE2="payload.zip"

[SourceFiles]
SourceFiles0=$sourceWithSlash

[SourceFiles0]
%FILE0%=
%FILE1%=
%FILE2%=
"@
$utf8NoBom = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($sedPath, $sed, $utf8NoBom)
if (Test-Path -LiteralPath $setupPath) { Remove-Item -LiteralPath $setupPath -Force }
$process = Start-Process -FilePath "$env:SystemRoot\System32\iexpress.exe" -ArgumentList @('/N','/Q',$sedPath) -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $setupPath -PathType Leaf)) { throw "IExpress build failed with exit code $($process.ExitCode)." }
$hash = Get-FileHash -LiteralPath $setupPath -Algorithm SHA256
[IO.File]::WriteAllText($setupPath + '.sha256', $hash.Hash.ToLowerInvariant() + '  ' + $setupName + [Environment]::NewLine, $utf8NoBom)
if (-not $KeepBuildFiles -and (Test-Path -LiteralPath $buildRoot)) { Remove-Item -LiteralPath $buildRoot -Recurse -Force }
Get-Item -LiteralPath $setupPath | Select-Object FullName, Length, LastWriteTime
Write-Output ('SHA256: ' + $hash.Hash)

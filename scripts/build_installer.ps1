# Exports the Windows build and wraps it in an Inno Setup installer.
# Output: build/CardBattlePrototype-Setup-<version>.exe and build/CardBattlePrototype-Setup-<version>.exe.sha256
# Needs the Godot 4.7.2 export templates and Inno Setup 6 (see docs/INSTALLER.md).
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$godot = if ($env:GODOT_EXE) { $env:GODOT_EXE } else { Join-Path $root 'Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path $godot)) { throw "Godot console exe not found: $godot" }

$iscc = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 (ISCC.exe) not found. Install it: winget install JRSoftware.InnoSetup' }

$version = (Select-String -Path 'project.godot' -Pattern '^config/version="([^"]+)"').Matches.Groups[1].Value
if (-not $version) { throw 'config/version not found in project.godot' }
Write-Host "Building version $version"

New-Item -ItemType Directory -Force build | Out-Null
$exe = Join-Path $root 'build\CardBattlePrototype.exe'
if (Test-Path $exe) { Remove-Item $exe }

& $godot --headless --path . --import | Out-Null
& $godot --headless --path . --export-release 'Windows Desktop' $exe
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $exe)) { throw 'Godot export failed' }

& $iscc "/DAppVersion=$version" 'installer\setup.iss'
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compile failed' }

$setup = Join-Path $root "build\CardBattlePrototype-Setup-$version.exe"
if (-not (Test-Path $setup)) { throw "Installer not found: $setup" }
# Standard "<hash>  <filename>" format (two spaces), readable by sha256sum -c; ASCII, no BOM.
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $setup).Hash.ToLowerInvariant()
$sumFile = "$setup.sha256"
[System.IO.File]::WriteAllText($sumFile, "$hash  $(Split-Path -Leaf $setup)`n", (New-Object System.Text.UTF8Encoding($false)))
Write-Host "SHA-256 $hash"

Get-Item $setup, $sumFile | Select-Object Name, Length

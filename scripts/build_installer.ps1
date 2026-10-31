# Exports the Windows build and wraps it in an Inno Setup installer.
# Output: build/CardBattlePrototype-Setup-<version>.exe, its .sha256 and, when a signing key is configured, its .sig
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

# Fail before the long build if a signing key is configured but cannot be used (docs/UPDATE_SIGNING.md).
$publicPem = ([regex]::Match((Get-Content -Raw -LiteralPath 'run\update_verifier.gd'), '-----BEGIN PUBLIC KEY-----[\s\S]*?-----END PUBLIC KEY-----')).Value -replace '\n', "`n" -replace "`r", ''
$openssl = $null
if ($publicPem) {
    if (-not $env:UPDATE_SIGNING_KEY -or -not (Test-Path -LiteralPath $env:UPDATE_SIGNING_KEY)) {
        throw 'run/update_verifier.gd has a public key, so set $env:UPDATE_SIGNING_KEY to the path of the (temporarily extracted) private key file. See docs/UPDATE_SIGNING.md.'
    }
    $openssl = @((Get-Command openssl -ErrorAction SilentlyContinue).Source, "$env:ProgramFiles\Git\usr\bin\openssl.exe") | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
    if (-not $openssl) { throw 'openssl not found (it ships with Git for Windows: Program Files\Git\usr\bin).' }
}

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

# In-game updates: sign the installer's SHA-256 with the maintainer's private key (RSA, PKCS#1 v1.5)
# so the game will install it. The public half is the PEM in run/update_verifier.gd; with none
# embedded there is nothing to sign for and the game just offers the download page.
$sigFile = "$setup.sig"
if ($publicPem) {
    $pubFile = Join-Path ([IO.Path]::GetTempPath()) "update_pub_$PID.pem"
    try {
        [System.IO.File]::WriteAllText($pubFile, $publicPem + "`n", (New-Object System.Text.UTF8Encoding($false)))
        # The passphrase comes from UPDATE_SIGNING_PASS when set (the interactive prompt does not work in every
        # PowerShell host); otherwise openssl asks for it.
        $passArgs = if ($env:UPDATE_SIGNING_PASS) { @("-passin", "env:UPDATE_SIGNING_PASS") } else { @() }
        & $openssl dgst -sha256 -sign $env:UPDATE_SIGNING_KEY @passArgs -out $sigFile $setup
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $sigFile)) { throw 'Signing failed (wrong passphrase or key?)' }
        & $openssl dgst -sha256 -verify $pubFile -signature $sigFile $setup
        if ($LASTEXITCODE -ne 0) { throw 'The signature does not verify against the public key in run/update_verifier.gd: wrong private key?' }
    } finally { Remove-Item -LiteralPath $pubFile -ErrorAction SilentlyContinue }
    Write-Host "Signed: $sigFile"
} else {
    Write-Warning 'No public key in run/update_verifier.gd: no .sig written, so in-game updates stay off (see docs/UPDATE_SIGNING.md).'
}

$outputs = @($setup, $sumFile)
if ($publicPem) { $outputs += $sigFile }
Get-Item $outputs | Select-Object Name, Length

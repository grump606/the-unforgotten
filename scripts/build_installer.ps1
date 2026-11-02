# Exports the Windows build and wraps it in an Inno Setup installer.
# Output: build/TheUnforgotten-Setup-<version>.exe, its .sha256 and, when a signing key is configured, its .sig
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
        throw 'run/update_verifier.gd has a public key, so set $env:UPDATE_SIGNING_KEY to the path of the private key file (.pfx or .pem). See docs/UPDATE_SIGNING.md.'
    }
    $openssl = @((Get-Command openssl -ErrorAction SilentlyContinue).Source, "$env:ProgramFiles\Git\usr\bin\openssl.exe") | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
    if (-not $openssl) { throw 'openssl not found (it ships with Git for Windows: Program Files\Git\usr\bin).' }
}

New-Item -ItemType Directory -Force build | Out-Null
$exe = Join-Path $root 'build\TheUnforgotten.exe'
if (Test-Path $exe) { Remove-Item $exe }

& $godot --headless --path . --import | Out-Null
& $godot --headless --path . --export-release 'Windows Desktop' $exe
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $exe)) { throw 'Godot export failed' }

& $iscc "/DAppVersion=$version" 'installer\setup.iss'
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compile failed' }

$setup = Join-Path $root "build\TheUnforgotten-Setup-$version.exe"
if (-not (Test-Path $setup)) { throw "Installer not found: $setup" }
# Standard "<hash>  <filename>" format (two spaces), readable by sha256sum -c; ASCII, no BOM.
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $setup).Hash.ToLowerInvariant()
$sumFile = "$setup.sha256"
[System.IO.File]::WriteAllText($sumFile, "$hash  $(Split-Path -Leaf $setup)`n", (New-Object System.Text.UTF8Encoding($false)))
Write-Host "SHA-256 $hash"

# In-game updates (docs/UPDATE_SIGNING.md). Two things are signed with the maintainer's private key (RSA,
# PKCS#1 v1.5, SHA-256), and the public half is the PEM in run/update_verifier.gd:
#   <installer>.manifest(.sig)  the format current games read: a small text file naming the installer, its
#                               version and its SHA-256, so an old signed installer cannot be replayed as an update
#   <installer>.sig             a signature over the bare installer, kept only for v0.6.1 and earlier, which know
#                               nothing else (drop it once nobody runs those)
# With no public key embedded there is nothing to sign for and the game just offers the download page.
$sigFile = "$setup.sig"
$manifestFile = "$setup.manifest"
$manifestSigFile = "$setup.manifest.sig"
. (Join-Path $PSScriptRoot 'update_signing.ps1')
if ($publicPem) {
    # Must match UpdateCheck.make_manifest in run/update_check.gd byte for byte: LF endings, UTF-8 without BOM.
    $manifest = "the-unforgotten-update 1`nname=$(Split-Path -Leaf $setup)`nversion=$version`nsha256=$hash`n"
    [System.IO.File]::WriteAllText($manifestFile, $manifest, (New-Object System.Text.UTF8Encoding($false)))

    $pubFile = Join-Path ([IO.Path]::GetTempPath()) "update_pub_$PID.pem"
    try {
        [System.IO.File]::WriteAllText($pubFile, $publicPem + "`n", (New-Object System.Text.UTF8Encoding($false)))
        # The passphrase comes from UPDATE_SIGNING_PASS when set (the interactive prompt does not work in every
        # PowerShell host); otherwise openssl asks for it.
        $passArgs = if ($env:UPDATE_SIGNING_PASS) { @("-passin", "env:UPDATE_SIGNING_PASS") } else { @() }
        $signKey = $env:UPDATE_SIGNING_KEY
        # Signs $file into $sig, then checks it against the public key the game ships with.
        function Sign-AndVerify([string]$file, [string]$sig) {
            if ($signKey -match '\.(pfx|p12)$') {
                # SigningKeyMaker output: sign in memory with .NET (scripts/update_signing.ps1); the private key is never written to disk.
                Sign-FileWithPfx -PfxPath $signKey -Passphrase $env:UPDATE_SIGNING_PASS -FilePath $file -SigPath $sig
            } else {
                & $openssl dgst -sha256 -sign $signKey @passArgs -out $sig $file
                if ($LASTEXITCODE -ne 0 -or -not (Test-Path $sig)) { throw 'Signing failed (wrong passphrase or key?)' }
            }
            & $openssl dgst -sha256 -verify $pubFile -signature $sig $file
            if ($LASTEXITCODE -ne 0) { throw "The signature for $(Split-Path -Leaf $file) does not verify against the public key in run/update_verifier.gd: wrong private key?" }
        }
        Sign-AndVerify $manifestFile $manifestSigFile
        Sign-AndVerify $setup $sigFile
    } finally {
        Remove-Item -LiteralPath $pubFile -ErrorAction SilentlyContinue
    }
    Write-Host "Signed: $manifestSigFile, $sigFile"
} else {
    Write-Warning 'No public key in run/update_verifier.gd: nothing signed, so in-game updates stay off (see docs/UPDATE_SIGNING.md).'
}

$outputs = @($setup, $sumFile)
if ($publicPem) { $outputs += @($sigFile, $manifestFile, $manifestSigFile) }
Get-Item $outputs | Select-Object Name, Length

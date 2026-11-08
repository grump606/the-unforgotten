# Exports the Windows build and wraps it in an Inno Setup installer.
# Output: build/TheUnforgotten-Setup-<version>.exe, its .sha256 and, when a signing key is configured, its .manifest and .manifest.sig
# Needs the Godot export templates and the Inno Setup version named in scripts/engine_version.txt (see docs/INSTALLER.md).
# -NoSign builds everything except the signature (no private key needed; CI uses it to prove the export and the
# installer still build). Its output must never be released: release.ps1 never passes it.
param([switch]$NoSign)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
. (Join-Path $PSScriptRoot 'engine_version.ps1')
. (Join-Path $PSScriptRoot 'update_signing.ps1')

$godot = if ($env:GODOT_EXE) { $env:GODOT_EXE } else { Join-Path $root (Join-Path $GodotFolder $GodotConsole) }
if (-not (Test-Path $godot)) { throw "Godot console exe not found: $godot" }

# Newest "Inno Setup*" install folder (a 6.x pinned in scripts/engine_version.txt, but a newer major version is
# found too, so the failure is a clear version message and not "not found").
$innoRoots = @("$env:LOCALAPPDATA\Programs", ${env:ProgramFiles(x86)}, $env:ProgramFiles) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
# The compiler exe carries no version resource (0.0.0.0); the uninstaller in the same folder carries the product
# version, with the folder name ("Inno Setup 6") as the fallback.
function Get-InnoFolderVersion([string]$folder) {
    $unins = Join-Path $folder 'unins000.exe'
    $text = if (Test-Path -LiteralPath $unins) { [string](Get-Item -LiteralPath $unins).VersionInfo.ProductVersion } else { '' }
    if ($text -notmatch '^\d+(\.\d+)*') { $text = (Split-Path -Leaf $folder) -replace '[^0-9.]', '' }
    try { return [version]($text.Trim('.')) } catch { return [version]'0.0' }
}
$isccCandidates = @()
foreach ($r in $innoRoots) {
    foreach ($d in Get-ChildItem -LiteralPath $r -Directory -Filter 'Inno Setup*' -ErrorAction SilentlyContinue) {
        if (Test-Path -LiteralPath (Join-Path $d.FullName 'ISCC.exe')) { $isccCandidates += [pscustomobject]@{ Folder = $d.FullName; Version = (Get-InnoFolderVersion $d.FullName) } }
    }
}
$innoPick = $isccCandidates | Sort-Object Version -Descending | Select-Object -First 1
$iscc = if ($innoPick) { Join-Path $innoPick.Folder 'ISCC.exe' } else { $null }
if (-not $iscc) { throw "Inno Setup (ISCC.exe) not found. Install the pinned version: winget install JRSoftware.InnoSetup --version $($EngineVersion.INNO_SETUP_VERSION)" }
Write-Host "Inno Setup $($innoPick.Version) ($iscc); pinned version is $($EngineVersion.INNO_SETUP_VERSION)"

$version = (Select-String -Path 'project.godot' -Pattern '^config/version="([^"]+)"').Matches.Groups[1].Value
if (-not $version) { throw 'config/version not found in project.godot' }
Write-Host "Building version $version"

# Fail before the long build if a signing key is configured but cannot be used (docs/UPDATE_SIGNING.md).
$publicPems = @(Get-EmbeddedPublicKeyPems)
$signing = $publicPems.Count -gt 0 -and -not $NoSign
$openssl = $null
if ($signing) {
    if (-not $env:UPDATE_SIGNING_KEY -or -not (Test-Path -LiteralPath $env:UPDATE_SIGNING_KEY)) {
        throw 'run/update_verifier.gd has a public key, so set $env:UPDATE_SIGNING_KEY to the path of the private key file (.pfx or .pem). See docs/UPDATE_SIGNING.md.'
    }
    $openssl = Get-OpenSslPath
    if (-not $openssl) { throw 'openssl not found (it ships with Git for Windows: Program Files\Git\usr\bin).' }
}

New-Item -ItemType Directory -Force build | Out-Null
$exe = Join-Path $root 'build\TheUnforgotten.exe'
if (Test-Path $exe) { Remove-Item $exe }

# A failed import means the export below would package stale or missing resources, so it stops the build. The
# output is shown only when it fails. One retry: a first import in a fresh checkout has been seen to crash once.
$imported = $false
foreach ($attempt in 1, 2) {
    $importLog = & $godot --headless --path . --import
    if ($LASTEXITCODE -eq 0) { $imported = $true; break }
    Write-Warning "Godot --import exited with code $LASTEXITCODE (attempt $attempt of 2)."
    $importLog | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
}
if (-not $imported) { throw 'Godot --import failed: fix the project before building an installer.' }
& $godot --headless --path . --export-release 'Windows Desktop' $exe
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $exe)) { throw 'Godot export failed' }

# The exported exe must carry this version (export_presets.cfg file_version/product_version), or the installer
# would ship a game that reports an old version in its properties.
$exeInfo = (Get-Item -LiteralPath $exe).VersionInfo
foreach ($pair in @(@('FileVersion', $exeInfo.FileVersion), @('ProductVersion', $exeInfo.ProductVersion))) {
    if ($pair[1] -ne "$version.0") { throw "The exported exe has $($pair[0]) '$($pair[1])' but project.godot has config/version $version (expected '$version.0'): update export_presets.cfg." }
}
Write-Host "Exported exe version $($exeInfo.FileVersion)"

& $iscc "/DAppVersion=$version" 'installer\setup.iss'
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compile failed' }

$setup = Join-Path $root "build\TheUnforgotten-Setup-$version.exe"
if (-not (Test-Path $setup)) { throw "Installer not found: $setup" }
$setupVersion = ([string](Get-Item -LiteralPath $setup).VersionInfo.FileVersion).Trim()
if ($setupVersion -ne $version -and $setupVersion -ne "$version.0") { throw "The installer reports FileVersion '$setupVersion' but project.godot has config/version $version." }
# In-game updates refuse a download past UpdateCheck.MAX_INSTALLER_BYTES, so an installer that has grown past 2/3
# of that cap fails the build now, while there is still room to raise the cap (docs/UPDATE_CHECK.md).
$capMatch = Select-String -Path 'run/update_check.gd' -Pattern '^const MAX_INSTALLER_BYTES := (\d+) \* 1024 \* 1024'
if (-not $capMatch) { throw 'MAX_INSTALLER_BYTES not found in run/update_check.gd (the size guard in build_installer.ps1 reads it).' }
$capBytes = [int64]$capMatch.Matches.Groups[1].Value * 1024 * 1024
$setupBytes = (Get-Item -LiteralPath $setup).Length
Write-Host "Installer size $setupBytes bytes (in-game download cap $capBytes)"
if ($setupBytes * 3 -gt $capBytes * 2) { throw "The installer ($setupBytes bytes) is over 2/3 of the in-game download cap ($capBytes bytes): raise MAX_INSTALLER_BYTES in run/update_check.gd, or in-game updates will soon fail." }
# Standard "<hash>  <filename>" format (two spaces), readable by sha256sum -c; ASCII, no BOM.
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $setup).Hash.ToLowerInvariant()
$sumFile = "$setup.sha256"
[System.IO.File]::WriteAllText($sumFile, "$hash  $(Split-Path -Leaf $setup)`n", (New-Object System.Text.UTF8Encoding($false)))
Write-Host "SHA-256 $hash"

# In-game updates (docs/UPDATE_SIGNING.md). The update manifest is signed with the maintainer's private key (RSA,
# PKCS#1 v1.5, SHA-256), and the public half is the PEM in run/update_verifier.gd:
#   <installer>.manifest(.sig)  a small text file naming the installer, its
#                               version and its SHA-256, so an old signed installer cannot be replayed as an update
# With no public key embedded there is nothing to sign for and the game just offers the download page.
$manifestFile = "$setup.manifest"
$manifestSigFile = "$setup.manifest.sig"
if ($signing) {
    # New-UpdateManifestText (scripts/update_signing.ps1) must match UpdateCheck.make_manifest in run/update_check.gd
    # byte for byte: LF endings, UTF-8 without BOM. tests/golden/update_manifest.txt pins both; check.ps1 runs the test.
    $manifest = New-UpdateManifestText -Name (Split-Path -Leaf $setup) -Version $version -Sha256 $hash
    [System.IO.File]::WriteAllText($manifestFile, $manifest, (New-Object System.Text.UTF8Encoding($false)))

    # The passphrase comes from UPDATE_SIGNING_PASS when set (the interactive prompt does not work in every
    # PowerShell host); otherwise openssl asks for it.
    $passArgs = if ($env:UPDATE_SIGNING_PASS) { @("-passin", "env:UPDATE_SIGNING_PASS") } else { @() }
    $signKey = $env:UPDATE_SIGNING_KEY
    # Signs $file into $sig, then checks it against every trusted key the game ships with (run/update_verifier.gd):
    # the signature must verify against at least one.
    function Sign-AndVerify([string]$file, [string]$sig) {
        if ($signKey -match '\.(pfx|p12)$') {
            # SigningKeyMaker output: sign in memory with .NET (scripts/update_signing.ps1); the private key is never written to disk.
            Sign-FileWithPfx -PfxPath $signKey -Passphrase $env:UPDATE_SIGNING_PASS -FilePath $file -SigPath $sig
        } else {
            & $openssl dgst -sha256 -sign $signKey @passArgs -out $sig $file
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path $sig)) { throw 'Signing failed (wrong passphrase or key?)' }
        }
        $matched = Find-MatchingPublicKey -OpenSsl $openssl -PublicPems $publicPems -FilePath $file -SigPath $sig
        if ($matched -lt 0) { throw "The signature for $(Split-Path -Leaf $file) does not verify against any public key in run/update_verifier.gd: wrong private key?" }
        Write-Host "$(Split-Path -Leaf $sig): verified against embedded key #$($matched + 1) of $($publicPems.Count)"
    }
    Sign-AndVerify $manifestFile $manifestSigFile
    Write-Host "Signed: $manifestSigFile"
} elseif ($NoSign) {
    Write-Warning '-NoSign: nothing signed. This build must not be released.'
} else {
    Write-Warning 'No public keys in run/update_verifier.gd: nothing signed, so in-game updates stay off (see docs/UPDATE_SIGNING.md).'
}

$outputs = @($setup, $sumFile)
if ($signing) { $outputs += @($manifestFile, $manifestSigFile) }
Get-Item $outputs | Select-Object Name, Length

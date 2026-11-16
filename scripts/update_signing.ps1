# Signing helper for build_installer.ps1 (dot-source it). Kept separate so it can be tested without a Godot/Inno build.

# The exact text of the update manifest that gets signed. It must match UpdateCheck.make_manifest in
# run/update_check.gd byte for byte: LF line endings and a trailing LF (the caller writes it as UTF-8 without a
# BOM). tests/golden/update_manifest.txt holds the expected bytes for a fixed input; both sides are tested against it.
function New-UpdateManifestText {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Sha256,
        # Optional fifth line: the oldest running game allowed to install this release in game (docs/UPDATE_SIGNING.md).
        [string]$MinVersion = ''
    )
    $text = "the-unforgotten-update 1`nname=$Name`nversion=$Version`nsha256=$Sha256`n"
    if ($MinVersion) {
        # Same rule as UpdateCheck.parse_manifest: a valid version without a leading v.
        if ($MinVersion -notmatch '^[0-9]{1,4}(\.[0-9]{1,4}){0,3}$') { throw "Invalid minimum version '$MinVersion' (use digits and dots, no leading v)." }
        # A floor above the release would make every game refuse it (UpdateVerifier.verify_manifest).
        if (-not (Test-MinVersionAllowed -MinVersion $MinVersion -Version $Version)) { throw "Minimum version $MinVersion is above the release version $Version, so no game could install it." }
        $text += "min_version=$MinVersion`n"
    }
    return $text
}

# True when a min_version floor is allowed for a release of $Version: not above it (equal is fine). The same rule as
# UpdateVerifier.floor_allowed in the game: dotted numbers, missing groups count as 0 (0.9 < 0.10.1, 0.10.1.0 == 0.10.1).
# Both sides are tested against tests/golden/min_version_cases.txt.
function Test-MinVersionAllowed {
    param([Parameter(Mandatory)][string]$MinVersion, [Parameter(Mandatory)][string]$Version)
    $a = @($MinVersion.TrimStart('v', 'V').Split('.') | ForEach-Object { [int]$_ })
    $b = @($Version.TrimStart('v', 'V').Split('.') | ForEach-Object { [int]$_ })
    for ($i = 0; $i -lt [Math]::Max($a.Count, $b.Count); $i++) {
        $left = if ($i -lt $a.Count) { $a[$i] } else { 0 }
        $right = if ($i -lt $b.Count) { $b[$i] } else { 0 }
        if ($left -ne $right) { return $left -lt $right }
    }
    return $true
}

# Signs $FilePath with the private key in a .pfx/.p12, entirely in memory: RSA PKCS#1 v1.5 over SHA-256, the same
# bytes as `openssl dgst -sha256 -sign`. The key is loaded ephemerally (never persisted to a key container or
# a file) and disposed afterwards. Writes the raw signature to $SigPath.
function Sign-FileWithPfx {
    param(
        [Parameter(Mandatory)][string]$PfxPath,
        [string]$Passphrase,
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string]$SigPath
    )
    Add-Type -AssemblyName System.Security
    $flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
    $cert = $null; $rsa = $null; $stream = $null
    try {
        try {
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList (Resolve-Path -LiteralPath $PfxPath).ProviderPath, $Passphrase, $flags
        } catch {
            throw "Could not open the PFX (wrong passphrase?): $($_.Exception.Message)"
        }
        $rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
        if (-not $rsa) { throw 'The PFX has no RSA private key.' }
        $stream = [System.IO.File]::OpenRead((Resolve-Path -LiteralPath $FilePath).ProviderPath)
        $sig = $rsa.SignData($stream, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        [System.IO.File]::WriteAllBytes($SigPath, $sig)
    } finally {
        if ($stream) { $stream.Dispose() }
        if ($rsa) { $rsa.Dispose() }
        if ($cert) { $cert.Dispose() }
    }
}

# The trusted public keys the game ships with, as PEM strings (LF endings): every -----BEGIN PUBLIC KEY----- block in
# run/update_verifier.gd. build_installer.ps1 and verify_release.ps1 both read this list, so it has one source.
function Get-EmbeddedPublicKeyPems {
    param([string]$VerifierPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'run\update_verifier.gd'))
    $source = Get-Content -Raw -LiteralPath $VerifierPath
    return @([regex]::Matches($source, '-----BEGIN PUBLIC KEY-----[\s\S]*?-----END PUBLIC KEY-----') | ForEach-Object { $_.Value -replace "`r", '' })
}

# Path of an OpenSSL that can verify RSA signatures (it ships with Git for Windows), or $null.
function Get-OpenSslPath {
    return @((Get-Command openssl -ErrorAction SilentlyContinue).Source, "$env:ProgramFiles\Git\usr\bin\openssl.exe") | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

# Index (0-based) of the first PEM in $PublicPems that verifies $SigPath over $FilePath (RSA PKCS#1 v1.5, SHA-256,
# the same check as `openssl dgst -sha256 -verify`), or -1. The temporary key files are removed before returning.
function Find-MatchingPublicKey {
    param(
        [Parameter(Mandatory)][string]$OpenSsl,
        [Parameter(Mandatory)][string[]]$PublicPems,
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string]$SigPath
    )
    $files = @()
    # openssl prints its reason to stderr when a key does not match; that is an expected "no", not an error, so it
    # must not stop a caller running with $ErrorActionPreference = 'Stop' (Windows PowerShell 5.1 turns native stderr
    # into a terminating error then).
    $ErrorActionPreference = 'Continue'
    try {
        for ($i = 0; $i -lt $PublicPems.Count; $i++) {
            $f = Join-Path ([IO.Path]::GetTempPath()) "update_pub_${PID}_$i.pem"
            [System.IO.File]::WriteAllText($f, $PublicPems[$i] + "`n", (New-Object System.Text.UTF8Encoding($false)))
            $files += $f
        }
        for ($i = 0; $i -lt $files.Count; $i++) {
            & $OpenSsl dgst -sha256 -verify $files[$i] -signature $SigPath $FilePath 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { return $i }
        }
        return -1
    } finally {
        foreach ($f in $files) { Remove-Item -LiteralPath $f -ErrorAction SilentlyContinue }
    }
}

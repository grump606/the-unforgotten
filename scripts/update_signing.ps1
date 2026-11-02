# Signing helper for build_installer.ps1 (dot-source it). Kept separate so it can be tested without a Godot/Inno build.

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

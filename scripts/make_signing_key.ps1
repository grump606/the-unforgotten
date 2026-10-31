# Creates the update-signing key pair (see docs/UPDATE_SIGNING.md). Run it in a normal Windows
# PowerShell window, NOT inside an editor or assistant prompt, and not from the repo folder.
#
# By default it makes a random passphrase and prints it once, so no hidden prompt is needed (the
# OpenSSL that ships with Git often cannot read one from PowerShell). Pass -Prompt to type your own.
#
# Output (in -OutDir, default %TEMP%\signing):
#   update_signing_private.pem   SECRET: move it into your password manager, then delete it here
#   update_signing_public.pem    not secret: embed it in run/update_verifier.gd
param(
    [string]$OutDir = (Join-Path $env:TEMP 'signing'),
    [switch]$Prompt
)
# Continue, not Stop: Windows PowerShell 5.1 turns openssl's progress output on stderr into a
# terminating error under Stop. Every native call below is checked through $LASTEXITCODE instead.
$ErrorActionPreference = 'Continue'

$openssl = @((Get-Command openssl -ErrorAction SilentlyContinue).Source, "$env:ProgramFiles\Git\usr\bin\openssl.exe") |
    Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $openssl) { throw 'openssl not found. It ships with Git for Windows (C:\Program Files\Git\usr\bin).' }

New-Item -ItemType Directory -Force $OutDir -ErrorAction Stop | Out-Null
$private = Join-Path $OutDir 'update_signing_private.pem'
$public = Join-Path $OutDir 'update_signing_public.pem'
if (Test-Path $private) { throw "$private already exists. Refusing to overwrite a key; move or delete it first." }

if ($Prompt) {
    $secure = Read-Host 'Choose a passphrase' -AsSecureString
    $pass = [System.Net.NetworkCredential]::new('', $secure).Password
    if ($pass.Length -lt 12) { throw 'Use a passphrase of at least 12 characters.' }
    $shown = $false
} else {
    $chars = [char[]]('ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789')
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $pass = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
    $shown = $true
}

$env:KEYGEN_PASS = $pass
try {
    & $openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -aes-256-cbc -pass env:KEYGEN_PASS -out $private 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $private)) { throw 'Generating the private key failed.' }
    & $openssl pkey -in $private -passin env:KEYGEN_PASS -pubout -out $public 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $public)) { throw 'Deriving the public key failed.' }

    # Prove the pair works before you rely on it: sign something and verify it with the public half.
    $probe = Join-Path $OutDir 'probe.txt'; $probeSig = Join-Path $OutDir 'probe.sig'
    Set-Content -LiteralPath $probe -Value 'probe' -Encoding ascii
    & $openssl dgst -sha256 -sign $private -passin env:KEYGEN_PASS -out $probeSig $probe 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Test signature failed.' }
    & $openssl dgst -sha256 -verify $public -signature $probeSig $probe | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Test signature did not verify.' }
    Remove-Item -LiteralPath $probe, $probeSig
} finally {
    Remove-Item Env:KEYGEN_PASS -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host 'Key pair created and tested.' -ForegroundColor Green
Write-Host "  Private key (SECRET): $private"
Write-Host "  Public key:           $public"
if ($shown) {
    Write-Host ''
    Write-Host 'PASSPHRASE (shown once; copy it into your password manager entry now):' -ForegroundColor Yellow
    Write-Host "  $pass"
}
Write-Host ''
Write-Host 'Next:'
Write-Host '  1. In your password manager, attach the private key file and save the passphrase with it.'
Write-Host '  2. Make an offline backup copy of the private key file (USB stick).'
Write-Host '  3. Delete the private key file from this folder, then clear this window (cls).'
Write-Host '  4. Share ONLY the public key below (it is not secret):'
Write-Host ''
Get-Content -LiteralPath $public

# Builds the update manifest with the release script's own code (New-UpdateManifestText in update_signing.ps1,
# as build_installer.ps1 calls it) for a fixed input and compares the bytes with tests/golden/update_manifest.txt.
# The GDScript side (UpdateCheck.make_manifest) is compared with the same file by
# tests/update_manifest_golden_tests.gd, so both writers are pinned to one byte string.
# Run alone: powershell -ExecutionPolicy Bypass -File scripts\check_manifest_golden.ps1
# Exit code 0 on a match, 1 on a mismatch. The fixed input must stay equal to the constants in the GDScript test.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'update_signing.ps1')

$text = New-UpdateManifestText -Name 'TheUnforgotten-Setup-1.2.3.exe' -Version '1.2.3' -Sha256 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
# Same encoding build_installer.ps1 writes: UTF-8 without a byte order mark.
$made = (New-Object System.Text.UTF8Encoding($false)).GetBytes($text)
$golden = [System.IO.File]::ReadAllBytes((Join-Path $root 'tests\golden\update_manifest.txt'))

$same = $made.Length -eq $golden.Length
if ($same) {
    for ($i = 0; $i -lt $made.Length; $i++) { if ($made[$i] -ne $golden[$i]) { $same = $false; break } }
}
if (-not $same) {
    Write-Host "MANIFEST GOLDEN MISMATCH: PowerShell wrote $($made.Length) bytes, tests/golden/update_manifest.txt has $($golden.Length)."
    Write-Host ("PowerShell: " + (($made | ForEach-Object { '{0:x2}' -f $_ }) -join ''))
    Write-Host ("Golden:     " + (($golden | ForEach-Object { '{0:x2}' -f $_ }) -join ''))
    exit 1
}
Write-Host "Manifest golden OK ($($made.Length) bytes)."
exit 0

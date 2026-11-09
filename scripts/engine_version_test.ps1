# Tests the pinned versions and the legacy installer cap in scripts/engine_version.txt (run by scripts/check.ps1):
# engine_version.ps1 exposes LEGACY_CLIENT_CAP_MIB as an int, refuses a missing or non-numeric value, and the two
# scripts that use the cap read it from there instead of hard-coding a copy.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$script:failures = 0
function Check([bool]$ok, [string]$what) { if (-not $ok) { $script:failures++; Write-Host "FAIL: $what" } }
function Throws([scriptblock]$block) { try { & $block | Out-Null; return $null } catch { return "$($_.Exception.Message)" } }

. (Join-Path $PSScriptRoot 'engine_version.ps1')
Check ($LEGACY_CLIENT_CAP_MIB -is [int] -and $LEGACY_CLIENT_CAP_MIB -gt 0) 'LEGACY_CLIENT_CAP_MIB is a positive int'
$newCap = [int](Select-String -Path (Join-Path $root 'run/update_check.gd') -Pattern '^const MAX_INSTALLER_BYTES := (\d+) \* 1024 \* 1024').Matches.Groups[1].Value
Check ($LEGACY_CLIENT_CAP_MIB -lt $newCap) "the legacy cap ($LEGACY_CLIENT_CAP_MIB MiB) is below the current cap ($newCap MiB); if not, the legacy check and setting can go"

# The reader refuses a file without the key or with a bad value (copy of the script next to a doctored txt).
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("engine_version_test_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    Copy-Item (Join-Path $PSScriptRoot 'engine_version.ps1') $tmp
    $good = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'engine_version.txt')
    $reader = Join-Path $tmp 'engine_version.ps1'
    $good | Where-Object { $_ -notmatch '^LEGACY_CLIENT_CAP_MIB=' } | Set-Content (Join-Path $tmp 'engine_version.txt')
    $msg = Throws { . $reader }
    Check ($null -ne $msg -and $msg -match 'LEGACY_CLIENT_CAP_MIB is missing') 'a missing LEGACY_CLIENT_CAP_MIB is refused'
    ($good | ForEach-Object { $_ -replace '^LEGACY_CLIENT_CAP_MIB=.*', 'LEGACY_CLIENT_CAP_MIB=lots' }) | Set-Content (Join-Path $tmp 'engine_version.txt')
    $msg = Throws { . $reader }
    Check ($null -ne $msg -and $msg -match 'whole number') 'a non-numeric LEGACY_CLIENT_CAP_MIB is refused'
    $good | Set-Content (Join-Path $tmp 'engine_version.txt')
    $msg = Throws { . $reader }
    Check ($null -eq $msg) 'the real file is accepted by the copied reader'
} finally { Remove-Item -Recurse -Force $tmp }

# One copy only: neither script assigns its own number, and the 2/3 rule only warns (it can never fire first).
foreach ($name in 'build_installer.ps1', 'release.ps1') {
    $text = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot $name)
    Check ($text -match 'LEGACY_CLIENT_CAP_MIB') "$name uses LEGACY_CLIENT_CAP_MIB"
    Check ($text -notmatch '(?im)^\s*\$(legacyCapMiB|LEGACY_CLIENT_CAP_MIB)\s*=\s*\d+') "$name does not hard-code the legacy cap"
}
$build = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'build_installer.ps1')
Check ($build -match 'Write-Warning "The installer[^"]*2/3') 'the 2/3-of-cap rule in build_installer.ps1 is a warning'
Check ($build -notmatch 'throw "The installer[^"]*2/3') 'the 2/3-of-cap rule in build_installer.ps1 does not throw'

if ($script:failures -gt 0) { Write-Host "$($script:failures) engine version check(s) failed"; exit 1 }
Write-Host 'engine version checks passed'
exit 0

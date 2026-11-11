# Tests the pinned versions in scripts/engine_version.txt (run by scripts/check.ps1): engine_version.ps1 exposes the
# derived names and refuses a file with a missing key.
$ErrorActionPreference = 'Stop'
$script:failures = 0
function Check([bool]$ok, [string]$what) { if (-not $ok) { $script:failures++; Write-Host "FAIL: $what" } }
function Throws([scriptblock]$block) { try { & $block | Out-Null; return $null } catch { return "$($_.Exception.Message)" } }

. (Join-Path $PSScriptRoot 'engine_version.ps1')
Check ($GodotFolder -like 'Godot_v*_win64.exe') 'GodotFolder is derived from GODOT_VERSION'
Check ($GodotConsole -like 'Godot_v*_win64_console.exe') 'GodotConsole is derived from GODOT_VERSION'

# The reader refuses a file without a key (copy of the script next to a doctored txt).
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("engine_version_test_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    Copy-Item (Join-Path $PSScriptRoot 'engine_version.ps1') $tmp
    $good = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'engine_version.txt')
    $reader = Join-Path $tmp 'engine_version.ps1'
    $good | Where-Object { $_ -notmatch '^INNO_SETUP_VERSION=' } | Set-Content (Join-Path $tmp 'engine_version.txt')
    $msg = Throws { . $reader }
    Check ($null -ne $msg -and $msg -match 'INNO_SETUP_VERSION is missing') 'a missing key is refused'
    $good | Set-Content (Join-Path $tmp 'engine_version.txt')
    $msg = Throws { . $reader }
    Check ($null -eq $msg) 'the real file is accepted by the copied reader'
} finally { Remove-Item -Recurse -Force $tmp }

# The 2/3-of-cap rule only warns (it never fails a build).
$build = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'build_installer.ps1')
Check ($build -match 'Write-Warning "The installer[^"]*2/3') 'the 2/3-of-cap rule in build_installer.ps1 is a warning'
Check ($build -notmatch 'throw "The installer \(\$setupBytes') 'build_installer.ps1 has no hard installer size limit'

if ($script:failures -gt 0) { Write-Host "$($script:failures) engine version check(s) failed"; exit 1 }
Write-Host 'engine version checks passed'
exit 0

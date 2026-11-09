# Tests the Inno Setup choice in scripts/inno_setup.ps1 with fake folder lists (run by scripts/check.ps1).
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'inno_setup.ps1')
$script:failures = 0
function Check([bool]$ok, [string]$what) { if (-not $ok) { $script:failures++; Write-Host "FAIL: $what" } }
function Fake([string]$folder, [string]$version) { [pscustomobject]@{ Folder = $folder; Version = [version]$version } }
function Throws([scriptblock]$block) { try { & $block | Out-Null; return $null } catch { return "$($_.Exception.Message)" } }

Check ((Select-InnoSetup @((Fake 'C:\a\Inno Setup 6' '6.2.0'), (Fake 'D:\b\Inno Setup 6' '6.7.3'))).Folder -eq 'D:\b\Inno Setup 6') 'the newest 6.x wins'
Check ((Select-InnoSetup @((Fake 'C:\a\Inno Setup 6' '6.7.3'), (Fake 'C:\a\Inno Setup 7' '7.0.1'))).Folder -eq 'C:\a\Inno Setup 6') 'a 6.x is used even when a 7.x is installed too'
Check ((Select-InnoSetup (Fake 'C:\a\Inno Setup 6' '6.1')).Version.Major -eq 6) 'a single candidate (not an array) works'
$msg = Throws { Select-InnoSetup @((Fake 'C:\a\Inno Setup 7' '7.0.1')) '6.7.3' }
Check ($null -ne $msg -and $msg -match 'Inno Setup 6 is required' -and $msg -match '7\.0\.1') 'only a 7.x: throws and names the version it found'
$msg = Throws { Select-InnoSetup @((Fake 'C:\a\Inno Setup 5' '5.6.1')) '6.7.3' }
Check ($null -ne $msg -and $msg -match 'Inno Setup 6 is required') 'only a 5.x: throws'
$msg = Throws { Select-InnoSetup @() '6.7.3' }
Check ($null -ne $msg -and $msg -match 'not found' -and $msg -match '6\.7\.3') 'no candidates: throws, with the pinned version in the hint'

# Real folders: the version comes from the folder name when there is no uninstaller to read.
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("inno_test_" + [guid]::NewGuid().ToString('N'))
try {
    foreach ($n in 'Inno Setup 6', 'Inno Setup 7', 'Inno Setup Other') { New-Item -ItemType Directory -Force (Join-Path $tmp $n) | Out-Null }
    foreach ($n in 'Inno Setup 6', 'Inno Setup 7') { Set-Content -LiteralPath (Join-Path $tmp "$n\ISCC.exe") -Value 'x' }
    $found = @(Get-InnoCandidates @($tmp, 'Z:\no_such_root'))
    Check ($found.Count -eq 2) 'folders without ISCC.exe and missing roots are skipped'
    Check ((@($found | Where-Object { $_.Version.Major -eq 7 }).Count) -eq 1) 'the folder name gives the major version when there is no uninstaller'
    Check ((Select-InnoSetup $found).Folder -like '*Inno Setup 6') 'real folders: the 6.x is chosen over the 7.x'
} finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }

if ($script:failures -gt 0) { Write-Host "inno_setup_test: $($script:failures) failures"; exit 1 }
Write-Host 'inno_setup_test: all checks passed'
exit 0

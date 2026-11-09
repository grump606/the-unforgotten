# Tests scripts/check_floor_record.ps1 (run by scripts/check.ps1): the 5% rule between the committed record and the
# live total, the log parser and the record-file reader.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'check_floor_record.ps1')
$script:failures = 0
function Check([bool]$ok, [string]$what) { if (-not $ok) { $script:failures++; Write-Host "FAIL: $what" } }

Check ((Get-CheckRecordStatus 15000 15000) -eq 'ok') 'equal totals are ok'
Check ((Get-CheckRecordStatus 15000 15750) -eq 'ok') 'exactly 5% above the record is still ok'
Check ((Get-CheckRecordStatus 15000 15751) -eq 'stale') 'one check past 5% above the record is stale'
Check ((Get-CheckRecordStatus 15000 20000) -eq 'stale') 'far above the record is stale'
Check ((Get-CheckRecordStatus 15000 14900) -eq 'ok') 'a slightly lower live total is ok here (run_tests.gd owns the 1.5% floor)'
Check ((Get-CheckRecordStatus 0 15000) -eq 'missing') 'no record is missing'
Check ((Get-CheckRecordStatus 15000 0) -eq 'missing') 'no live total is missing'

Check ((Get-LiveCheckTotal @('TEST FILE: a.gd', 'CHECKS: 15572', 'FAILURES: 0')) -eq 15572) 'the live total is read from the CHECKS line'
Check ((Get-LiveCheckTotal @('CHECKS: 10', 'CHECKS: 20')) -eq 20) 'the last CHECKS line wins'
Check ((Get-LiveCheckTotal @('no total here', 'xCHECKS: 5')) -eq 0) 'no CHECKS line gives 0'

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("floor_record_" + [guid]::NewGuid().ToString('N') + '.txt')
try {
    Set-Content -LiteralPath $tmp -Value @('# c', 'TOTAL_CHECKS=123', 'UI_STEPS=7')
    Check ((Get-CheckRecord $tmp 'TOTAL_CHECKS') -eq 123 -and (Get-CheckRecord $tmp 'UI_STEPS') -eq 7) 'the record file is parsed'
    Check ((Get-CheckRecord $tmp 'NOPE') -eq 0 -and (Get-CheckRecord "$tmp.missing" 'TOTAL_CHECKS') -eq 0) 'a missing key or file reads as 0'
} finally { Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue }

$real = Get-CheckRecord (Join-Path (Split-Path -Parent $PSScriptRoot) 'tests\golden\min_checks.txt') 'TOTAL_CHECKS'
Check ($real -gt 0) 'the committed record has a TOTAL_CHECKS'

if ($script:failures -gt 0) { Write-Host "$($script:failures) check floor record test(s) failed"; exit 1 }
Write-Host 'check floor record tests passed'
exit 0

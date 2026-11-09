# The record of the check floor (tests/golden/min_checks.txt) against the live total of a full run. Dot-source it.
# tests/run_tests.gd already fails a run that is more than 1.5% BELOW the record (a suite stopped checking). This is
# the other direction: a record that has fallen far behind the live total gives the floor no teeth, so
#   - check.ps1 prints a NOTE when the live total is more than 5% ABOVE the record;
#   - release.ps1 refuses to release when the record is more than 5% BELOW the live total (refresh it first).
# scripts/check_floor_record_test.ps1 proves the rules.

# One KEY=number value of the record file (0 when the file or key is missing).
function Get-CheckRecord([string]$Path, [string]$Key) {
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    $m = [regex]::Match((Get-Content -Raw -LiteralPath $Path), '(?m)^' + [regex]::Escape($Key) + '=(\d+)\s*$')
    if ($m.Success) { return [int]$m.Groups[1].Value }
    return 0
}

# The "CHECKS: n" total printed by tests/run_tests.gd in a log (0 when absent). The last one wins.
function Get-LiveCheckTotal([string[]]$Lines) {
    $total = 0
    foreach ($line in $Lines) {
        $m = [regex]::Match("$line", '^CHECKS: (\d+)\s*$')
        if ($m.Success) { $total = [int]$m.Groups[1].Value }
    }
    return $total
}

# 'stale' when the live total is more than 5% above the record (check.ps1 prints a NOTE, release.ps1 refuses),
# 'missing' when the record or the live total is absent, else 'ok'. A record far ABOVE the live total is not handled
# here: run_tests.gd fails that run.
function Get-CheckRecordStatus([int]$Recorded, [int]$Live) {
    if ($Recorded -le 0 -or $Live -le 0) { return 'missing' }
    if ($Live * 100 -gt $Recorded * 105) { return 'stale' }
    return 'ok'
}

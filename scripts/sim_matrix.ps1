# Route-strategy balance matrix: runs tools/run_sim.gd in map mode for every class x policy x route, several
# processes at a time, and writes one CSV plus a Markdown summary (docs/MAP_DESIGN.md, "Phase 4e").
#   .\scripts\sim_matrix.ps1 -OutDir .\sim_out                      # 100 runs, seed 1, 4 parallel processes
#   .\scripts\sim_matrix.ps1 -OutDir .\sim_out -Runs 300 -Seed 7 -Jobs 8
#   .\scripts\sim_matrix.ps1 -OutDir .\sim_out -Characters thief,medium -Policies smart -Routes fighter,mixed
# Matrix: classes deserter,thief,medium,stray x policies greedy,smart x routes fighter,cautious,mixed,random
# (override with -Characters, -Policies, -Routes). Each cell is one run_sim process (--map --route R).
# -Jobs caps how many run at once (default 4); with more CPUs than cells use a bigger -Jobs.
# Output in -OutDir: matrix.csv (class, policy, route, runs, escapes, rate, ci_low, ci_high, death bands by
# row, visits per run, HP at the bosses), summary.md (escape-rate table with the best and worst route per row)
# and raw\<class>_<policy>_<route>.txt (the full run_sim report of each cell).
# Engine lookup: -Godot, $env:GODOT_EXE, $env:GODOT, then the winget console install.
param(
    [Parameter(Mandatory = $true)][string]$OutDir,
    [int]$Runs = 100,
    [int]$Seed = 1,
    [int]$Jobs = 4,
    [string[]]$Characters = @('deserter', 'thief', 'medium', 'stray'),
    [string[]]$Policies = @('greedy', 'smart'),
    [string[]]$Routes = @('fighter', 'cautious', 'mixed', 'random'),
    [string]$Godot
)
$ErrorActionPreference = 'Stop'
# powershell -File passes "a,b" as one string: accept comma lists either way.
$Characters = @($Characters | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$Policies = @($Policies | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$Routes = @($Routes | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$root = Split-Path -Parent $PSScriptRoot
$winget = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe'
$exe = if ($Godot) { $Godot } elseif ($env:GODOT_EXE) { $env:GODOT_EXE } elseif ($env:GODOT) { $env:GODOT } else { $winget }
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Godot not found at '$exe'. Pass -Godot or set GODOT_EXE (the console executable)." }
if ($Jobs -lt 1) { throw '-Jobs must be at least 1.' }
$inv = [Globalization.CultureInfo]::InvariantCulture
$null = New-Item -ItemType Directory -Force -Path $OutDir
$rawDir = Join-Path $OutDir 'raw'
$null = New-Item -ItemType Directory -Force -Path $rawDir

# One job per matrix cell.
$cells = @()
foreach ($c in $Characters) { foreach ($p in $Policies) { foreach ($r in $Routes) {
    $cells += [pscustomobject]@{ Character = $c; Policy = $p; Route = $r; Out = (Join-Path $rawDir "${c}_${p}_${r}.txt"); Proc = $null }
} } }
$clock = [Diagnostics.Stopwatch]::StartNew()
$queue = [System.Collections.Queue]::new($cells)
$running = @()
$done = 0
while ($queue.Count -gt 0 -or $running.Count -gt 0) {
    while ($queue.Count -gt 0 -and $running.Count -lt $Jobs) {
        $cell = $queue.Dequeue()
        $engineArgs = @('--headless', '--path', "`"$root`"", '-s', 'res://tools/run_sim.gd', '--', '--map', '--runs', $Runs, '--seed', $Seed,
            '--policy', $cell.Policy, '--character', $cell.Character, '--route', $cell.Route)
        $cell.Proc = Start-Process -FilePath $exe -ArgumentList $engineArgs -PassThru -WindowStyle Hidden -RedirectStandardOutput $cell.Out -RedirectStandardError "$($cell.Out).err"
        $null = $cell.Proc.Handle  # Windows PowerShell 5.1 drops ExitCode unless the handle is cached
        $running += $cell
    }
    Start-Sleep -Milliseconds 500
    $still = @()
    foreach ($cell in $running) {
        if ($cell.Proc.HasExited) {
            $done++
            Write-Host ("[{0}/{1}] {2} {3} {4} done ({5:N0} s)" -f $done, $cells.Count, $cell.Character, $cell.Policy, $cell.Route, $clock.Elapsed.TotalSeconds)
        } else { $still += $cell }
    }
    $running = $still
}

# Parse the reports.
function Pull([string]$text, [string]$pattern) {
    $m = [regex]::Match($text, $pattern)
    if (-not $m.Success) { return $null }
    return $m
}
$bandNames = @('0_4', '5_9', '10_14', '15_19', '20_24', '25_29')
$rows = @()
foreach ($cell in $cells) {
    $text = Get-Content -LiteralPath $cell.Out -Raw
    $esc = Pull $text 'Escape rate: (\d+)/(\d+) \(([\d.]+)%\)'
    $ci = Pull $text 'Wilson\): ([\d.]+)% to ([\d.]+)%'
    $bands = Pull $text 'Deaths by row band: rows 0-4 (\d+), rows 5-9 (\d+), rows 10-14 (\d+), rows 15-19 (\d+), rows 20-24 (\d+), rows 25-29 (\d+)'
    $visits = Pull $text 'Visits per run: fights ([\d.]+), elites ([\d.]+), rests ([\d.]+), shops ([\d.]+), chests ([\d.]+), events ([\d.]+)'
    $hp = Pull $text 'mid-boss: ([\d.]+|n/a) \(\d+ runs reached it\), at the final boss: ([\d.]+|n/a)'
    if (-not ($esc -and $ci -and $bands -and $visits -and $hp)) { throw "Could not read the report of $($cell.Character) $($cell.Policy) $($cell.Route): see $($cell.Out) and $($cell.Out).err" }
    $row = [ordered]@{
        class = $cell.Character; policy = $cell.Policy; route = $cell.Route; runs = [int]$esc.Groups[2].Value
        escapes = [int]$esc.Groups[1].Value; rate = $esc.Groups[3].Value; ci_low = $ci.Groups[1].Value; ci_high = $ci.Groups[2].Value
    }
    for ($i = 0; $i -lt 6; $i++) { $row["deaths_rows_$($bandNames[$i])"] = [int]$bands.Groups[$i + 1].Value }
    $row['fights'] = $visits.Groups[1].Value; $row['elites'] = $visits.Groups[2].Value; $row['rests'] = $visits.Groups[3].Value
    $row['shops'] = $visits.Groups[4].Value; $row['chests'] = $visits.Groups[5].Value; $row['events'] = $visits.Groups[6].Value
    $row['hp_mid_boss'] = $hp.Groups[1].Value; $row['hp_final_boss'] = $hp.Groups[2].Value
    $rows += [pscustomobject]$row
}
$csv = Join-Path $OutDir 'matrix.csv'
$rows | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding ASCII

# Markdown: one line per class and policy, one column per route, "rate% (CI low-high)".
$md = @()
$md += "# Route strategy matrix: $Runs runs per cell, seed $Seed"
$md += ''
$md += 'Escape rate per route (95% Wilson interval in brackets).'
$md += ''
$md += '| class | policy | ' + ($Routes -join ' | ') + ' | best | worst | spread |'
$md += '|---|---|' + (($Routes | ForEach-Object { '---' }) -join '|') + '|---|---|---|'
foreach ($c in $Characters) { foreach ($p in $Policies) {
    $line = "| $c | $p |"
    $best = $null; $worst = $null
    foreach ($r in $Routes) {
        $row = $rows | Where-Object { $_.class -eq $c -and $_.policy -eq $p -and $_.route -eq $r }
        $rate = [double]::Parse($row.rate, $inv)
        $line += " $($row.rate)% ($($row.ci_low)-$($row.ci_high)) |"
        if ($null -eq $best -or $rate -gt $best.rate) { $best = @{ route = $r; rate = $rate } }
        if ($null -eq $worst -or $rate -lt $worst.rate) { $worst = @{ route = $r; rate = $rate } }
    }
    $line += " $($best.route) | $($worst.route) | " + [string]::Format($inv, '{0:N1}', $best.rate - $worst.rate) + ' pts |'
    $md += $line
} }
$md += ''
$md += 'Visits per run (fights / rests / shops / chests / events).'
$md += ''
$md += '| class | policy | route | fights | rests | shops | chests | events | HP at mid-boss | HP at final boss |'
$md += '|---|---|---|---|---|---|---|---|---|---|'
foreach ($row in $rows) {
    $md += "| $($row.class) | $($row.policy) | $($row.route) | $($row.fights) | $($row.rests) | $($row.shops) | $($row.chests) | $($row.events) | $($row.hp_mid_boss) | $($row.hp_final_boss) |"
}
Set-Content -LiteralPath (Join-Path $OutDir 'summary.md') -Value $md -Encoding ASCII
Write-Host ("Wrote {0} and summary.md in {1} ({2} cells, {3:N0} s)" -f $csv, $OutDir, $cells.Count, $clock.Elapsed.TotalSeconds)

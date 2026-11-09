# End-to-end exit codes of the sim tools: with THE_UNFORGOTTEN_SIM_FAIL=1 (a seam in SimPolicy.play_turn) balance_sim
# and run_sim must exit 1; without it both must exit 0. Engine: -Godot, $env:GODOT_EXE, $env:GODOT, else the local binary.
param([string]$Godot)
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'engine_version.ps1')
$local = Join-Path $root (Join-Path $GodotFolder $GodotConsole)
$godot = if ($Godot) { $Godot } elseif ($env:GODOT_EXE) { $env:GODOT_EXE } elseif ($env:GODOT) { $env:GODOT } else { $local }
if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) { Write-Host "check_sim_exit: Godot not found at '$godot'"; exit 2 }

function Get-SimExit([string]$script, [string[]]$simArgs, [bool]$forceFail) {
    $before = $env:THE_UNFORGOTTEN_SIM_FAIL
    if ($forceFail) { $env:THE_UNFORGOTTEN_SIM_FAIL = '1' } else { Remove-Item Env:THE_UNFORGOTTEN_SIM_FAIL -ErrorAction SilentlyContinue }
    $outFile = [IO.Path]::GetTempFileName()
    $errFile = [IO.Path]::GetTempFileName()
    try {
        $engineArgs = @('--headless', '--path', '.', '-s', $script, '--') + $simArgs
        $proc = Start-Process -FilePath $godot -ArgumentList $engineArgs -PassThru -WindowStyle Hidden -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        $null = $proc.Handle  # Windows PowerShell 5.1 drops ExitCode unless the handle is cached
        if (-not $proc.WaitForExit(120000)) { $proc.Kill(); return -99 }
        $proc.WaitForExit()
        return $proc.ExitCode
    } finally {
        Remove-Item -LiteralPath $outFile, $errFile -ErrorAction SilentlyContinue
        if ($null -eq $before) { Remove-Item Env:THE_UNFORGOTTEN_SIM_FAIL -ErrorAction SilentlyContinue } else { $env:THE_UNFORGOTTEN_SIM_FAIL = $before }
    }
}

$cases = @(
    @{ name = 'balance_sim'; script = 'res://tools/balance_sim.gd'; args = @('--fights', '3', '--seed', '1') },
    @{ name = 'run_sim'; script = 'res://tools/run_sim.gd'; args = @('--runs', '2', '--seed', '1') }
)
$failed = $false
Push-Location $root
try {
    foreach ($c in $cases) {
        foreach ($force in @($true, $false)) {
            $want = if ($force) { 1 } else { 0 }
            $got = Get-SimExit $c.script $c.args $force
            $ok = ($got -eq $want)
            $mode = if ($force) { 'with forced failure' } else { 'normally' }
            $verdict = if ($ok) { 'ok' } else { 'WRONG' }
            Write-Host "$($c.name) ${mode}: exit $got, expected $want $verdict"
            if (-not $ok) { $failed = $true }
        }
    }
} finally { Pop-Location }
if ($failed) { Write-Host 'check_sim_exit: FAILED'; exit 1 }
Write-Host 'check_sim_exit: ok'
exit 0

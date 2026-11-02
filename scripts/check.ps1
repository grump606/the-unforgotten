# Full validation: import, headless tests, main-scene smoke load, UI tests.
# Engine: $env:GODOT, else the repo-local Godot_v4.7.2-stable_win64.exe console binary.
# Optional: $env:CHECK_TESTS_SCRIPT overrides the test script and $env:CHECK_STEP_TIMEOUT_MS the
# per-step timeout (both used to prove the failure paths).
# Every step has a timeout: a script error or an infinite loop would otherwise hang
# headless Godot forever instead of failing the check.
param([string]$Godot)
# Engine lookup order: -Godot parameter, $env:GODOT_EXE (used by CI), $env:GODOT, local path.
$root = Split-Path -Parent $PSScriptRoot
$local = Join-Path $root 'Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
$godot = if ($Godot) { $Godot } elseif ($env:GODOT_EXE) { $env:GODOT_EXE } elseif ($env:GODOT) { $env:GODOT } else { $local }
if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) {
    Write-Host "CHECK FAILED: Godot not found at '$godot'. Pass -Godot, or set GODOT_EXE (or GODOT) to the Godot 4.7 console executable, or place it at '$local'."
    exit 2
}
$testScript = if ($env:CHECK_TESTS_SCRIPT) { $env:CHECK_TESTS_SCRIPT } else { 'res://tests/run_tests.gd' }
$errPattern = 'SCRIPT ERROR|Parse Error|ERROR: Failed to load'
$stepTimeoutMs = if ($env:CHECK_STEP_TIMEOUT_MS) { [int]$env:CHECK_STEP_TIMEOUT_MS } else { 300000 }

function Invoke-Step([string]$name, [string[]]$engineArgs) {
    Write-Host "== $name =="
    $outFile = [IO.Path]::GetTempFileName()
    $errFile = [IO.Path]::GetTempFileName()
    try {
        $proc = Start-Process -FilePath $godot -ArgumentList $engineArgs -PassThru -WindowStyle Hidden -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        $null = $proc.Handle  # Windows PowerShell 5.1 drops ExitCode unless the handle is cached
        if (-not $proc.WaitForExit($stepTimeoutMs)) {
            $proc.Kill()
            Write-Host "CHECK FAILED: $name (timed out after $($stepTimeoutMs / 1000) s)"
            exit 1
        }
        $proc.WaitForExit()  # let redirected output finish flushing
        $code = $proc.ExitCode
        $out = @(Get-Content -LiteralPath $outFile) + @(Get-Content -LiteralPath $errFile) | ForEach-Object { "$_" }
    } finally {
        Remove-Item -LiteralPath $outFile, $errFile -ErrorAction SilentlyContinue
    }
    $out | ForEach-Object { Write-Host $_ }
    if ($code -ne 0) { Write-Host "CHECK FAILED: $name (exit code $code)"; exit 1 }
    if ($out -match $errPattern) { Write-Host "CHECK FAILED: $name (script errors in output)"; exit 1 }
}

Push-Location $root
try {
    Invoke-Step 'import' @('--headless', '--path', '.', '--import')
    Invoke-Step 'tests' @('--headless', '--path', '.', '-s', $testScript)
    Invoke-Step 'smoke' @('--headless', '--path', '.', '-s', 'res://tests/smoke_main.gd')
    Invoke-Step 'ui battle' @('--headless', '--path', '.', '-s', 'res://tests/ui_battle_test.gd')
    Invoke-Step 'ui flow' @('--headless', '--path', '.', '-s', 'res://tests/ui_flow_test.gd')
    Invoke-Step 'ui card view' @('--headless', '--path', '.', '-s', 'res://tests/ui_card_view_test.gd')
    Invoke-Step 'ui stage' @('--headless', '--path', '.', '-s', 'res://tests/ui_stage_test.gd')
    Invoke-Step 'ui battle backdrop' @('--headless', '--path', '.', '-s', 'res://tests/ui_battle_backdrop_test.gd')
    Invoke-Step 'ui vendor scene' @('--headless', '--path', '.', '-s', 'res://tests/ui_vendor_scene_test.gd')
    Invoke-Step 'ui screen scenes' @('--headless', '--path', '.', '-s', 'res://tests/ui_screen_scenes_test.gd')
    Invoke-Step 'ui relic view' @('--headless', '--path', '.', '-s', 'res://tests/ui_relic_view_test.gd')
    Invoke-Step 'ui update notice' @('--headless', '--path', '.', '-s', 'res://tests/ui_update_notice_test.gd')
    Invoke-Step 'reskin restoration' @('--headless', '--path', '.', '-s', 'res://tests/reskin_presentation_test.gd')
} finally { Pop-Location }
Write-Host 'CHECK PASSED'
exit 0

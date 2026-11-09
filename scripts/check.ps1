# Full validation: import, headless tests, main-scene smoke load, UI tests.
# Engine: $env:GODOT, else the repo-local console binary of the version in scripts/engine_version.txt.
# Optional: $env:CHECK_TESTS_SCRIPT overrides the test script and $env:CHECK_STEP_TIMEOUT_MS the
# per-step timeout (both used to prove the failure paths).
# Every step has a timeout: a script error or an infinite loop would otherwise hang
# headless Godot forever instead of failing the check.
param([string]$Godot)
# Engine lookup order: -Godot parameter, $env:GODOT_EXE (used by CI), $env:GODOT, local path.
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'engine_version.ps1')  # $GodotFolder / $GodotConsole come from scripts/engine_version.txt
$local = Join-Path $root (Join-Path $GodotFolder $GodotConsole)
$godot = if ($Godot) { $Godot } elseif ($env:GODOT_EXE) { $env:GODOT_EXE } elseif ($env:GODOT) { $env:GODOT } else { $local }
if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) {
    Write-Host "CHECK FAILED: Godot not found at '$godot'. Pass -Godot, or set GODOT_EXE (or GODOT) to the Godot 4.7 console executable, or place it at '$local'."
    exit 2
}
$testScript = if ($env:CHECK_TESTS_SCRIPT) { $env:CHECK_TESTS_SCRIPT } else { 'res://tests/run_tests.gd' }
# What counts as a script error in a step's output (scripts/check_log_patterns.ps1, proven by check_log_patterns_test.ps1).
. (Join-Path $PSScriptRoot 'check_log_patterns.ps1')
$stepTimeoutMs = if ($env:CHECK_STEP_TIMEOUT_MS) { [int]$env:CHECK_STEP_TIMEOUT_MS } else { 300000 }

# NOTE: lines of any step (for example "record is more than 5% behind"), repeated just before the verdict so they are seen.
$script:notes = @()

function Invoke-Step([string]$name, [string[]]$engineArgs) {
    Write-Host "== $name =="
    $outFile = [IO.Path]::GetTempFileName()
    $errFile = [IO.Path]::GetTempFileName()
    try {
        $proc = Start-Process -FilePath $godot -ArgumentList $engineArgs -PassThru -WindowStyle Hidden -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        $null = $proc.Handle  # Windows PowerShell 5.1 drops ExitCode unless the handle is cached
        if (-not $proc.WaitForExit($stepTimeoutMs)) {
            $proc.Kill()
            Start-Sleep -Milliseconds 500  # let the killed process release its output files
            # A hang is exactly when the log matters (locally and in CI): show the last of what it printed.
            $partial = @(@(Get-Content -LiteralPath $outFile -ErrorAction SilentlyContinue) + @(Get-Content -LiteralPath $errFile -ErrorAction SilentlyContinue) | ForEach-Object { "$_" })
            Write-Host "---- last of the output of '$name' before it was killed ($($partial.Count) lines in all) ----"
            $partial | Select-Object -Last 60 | ForEach-Object { Write-Host $_ }
            Write-Host '---- end of output ----'
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
    $script:notes += @($out | Where-Object { $_ -cmatch '^NOTE: ' })
    if ($code -ne 0) { Write-Host "CHECK FAILED: $name (exit code $code)"; exit 1 }
    $bad = @(Get-CheckLogFailures $out)
    if ($bad.Count -gt 0) {
        Write-Host "CHECK FAILED: $name (script errors in output; first of $($bad.Count) below)"
        $bad | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" }
        exit 1
    }
}

Push-Location $root
try {
    Invoke-Step 'import' @('--headless', '--path', '.', '--import')
    Invoke-Step 'tests' @('--headless', '--path', '.', '-s', $testScript)
    Invoke-Step 'smoke' @('--headless', '--path', '.', '-s', 'res://tests/smoke_main.gd')
    Invoke-Step 'battle seed' @('--headless', '--path', '.', '-s', 'res://tests/battle_seed_test.gd')
    Invoke-Step 'audio runtime' @('--headless', '--audio-driver', 'Dummy', '--path', '.', '-s', 'res://tests/audio_runtime_test.gd')
    # Every tests/ui_*_test.gd is a step of its own, in name order: a new UI test needs no edit here.
    # (tests/test_wiring_tests.gd fails if a test-looking file is neither picked up by this glob nor
    # one of the named steps in this script.)
    $uiTests = @(Get-ChildItem -LiteralPath (Join-Path $root 'tests') -Filter 'ui_*_test.gd' -File | Sort-Object Name)
    if ($uiTests.Count -eq 0) { Write-Host 'CHECK FAILED: no tests/ui_*_test.gd files found'; exit 1 }
    # The recorded minimum (tests/golden/min_checks.txt, UI_STEPS): a UI test that was deleted or stopped being found fails the check.
    $uiFloor = [int](([regex]::Match((Get-Content -Raw -LiteralPath (Join-Path $root 'tests\golden\min_checks.txt')), '(?m)^UI_STEPS=(\d+)\s*$')).Groups[1].Value)
    if ($uiFloor -le 0) { Write-Host 'CHECK FAILED: UI_STEPS is missing from tests/golden/min_checks.txt'; exit 1 }
    if ($uiTests.Count -lt $uiFloor) { Write-Host "CHECK FAILED: only $($uiTests.Count) tests/ui_*_test.gd files, fewer than the recorded UI_STEPS ($uiFloor)"; exit 1 }
    $uiRan = 0
    foreach ($ui in $uiTests) {
        $stepName = ($ui.BaseName -replace '_test$', '') -replace '_', ' '
        Invoke-Step $stepName @('--headless', '--path', '.', '-s', "res://tests/$($ui.Name)")
        $uiRan++
    }
    if ($uiRan -lt $uiFloor) { Write-Host "CHECK FAILED: only $uiRan ui test steps ran, fewer than the recorded UI_STEPS ($uiFloor)"; exit 1 }
    Invoke-Step 'reskin restoration' @('--headless', '--path', '.', '-s', 'res://tests/reskin_presentation_test.gd')
    # The rules that decide what a clean log is: bad logs must fail, the suite's known noise must pass.
    Write-Host '== check log patterns =='
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'check_log_patterns_test.ps1')
    if ($LASTEXITCODE -ne 0) { Write-Host 'CHECK FAILED: check log patterns'; exit 1 }
    # The choice of the Inno Setup compiler (newest 6.x; any other major version stops the build).
    Write-Host '== inno setup choice =='
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'inno_setup_test.ps1')
    if ($LASTEXITCODE -ne 0) { Write-Host 'CHECK FAILED: inno setup choice'; exit 1 }
    # The pinned versions and the legacy installer cap (one copy, in scripts/engine_version.txt).
    Write-Host '== engine version =='
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'engine_version_test.ps1')
    if ($LASTEXITCODE -ne 0) { Write-Host 'CHECK FAILED: engine version'; exit 1 }
    # The 5% rule between tests/golden/min_checks.txt and the live total (release.ps1 enforces it; tests/run_tests.gd prints the NOTE).
    Write-Host '== check floor record =='
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'check_floor_record_test.ps1')
    if ($LASTEXITCODE -ne 0) { Write-Host 'CHECK FAILED: check floor record'; exit 1 }
    # PowerShell side of the update manifest golden test (the GDScript side runs inside 'tests').
    Write-Host '== manifest golden =='
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'check_manifest_golden.ps1')
    if ($LASTEXITCODE -ne 0) { Write-Host 'CHECK FAILED: manifest golden'; exit 1 }
    # verify_release.ps1 against the committed signing fixture (good set passes, every kind of damage fails).
    Write-Host '== verify release =='
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'check_verify_release.ps1')
    if ($LASTEXITCODE -ne 0) { Write-Host 'CHECK FAILED: verify release'; exit 1 }
} finally { Pop-Location }
foreach ($note in $script:notes) { Write-Host "$note" }
Write-Host 'CHECK PASSED'
exit 0

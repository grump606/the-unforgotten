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
    Invoke-Step 'battle seed' @('--headless', '--path', '.', '-s', 'res://tests/battle_seed_test.gd')
    Invoke-Step 'audio runtime' @('--headless', '--audio-driver', 'Dummy', '--path', '.', '-s', 'res://tests/audio_runtime_test.gd')
    # Every tests/ui_*_test.gd is a step of its own, in name order: a new UI test needs no edit here.
    # (tests/test_wiring_tests.gd fails if a test-looking file is neither picked up by this glob nor
    # one of the named steps in this script.)
    $uiTests = @(Get-ChildItem -LiteralPath (Join-Path $root 'tests') -Filter 'ui_*_test.gd' -File | Sort-Object Name)
    if ($uiTests.Count -eq 0) { Write-Host 'CHECK FAILED: no tests/ui_*_test.gd files found'; exit 1 }
    foreach ($ui in $uiTests) {
        $stepName = ($ui.BaseName -replace '_test$', '') -replace '_', ' '
        Invoke-Step $stepName @('--headless', '--path', '.', '-s', "res://tests/$($ui.Name)")
    }
    Invoke-Step 'reskin restoration' @('--headless', '--path', '.', '-s', 'res://tests/reskin_presentation_test.gd')
    # PowerShell side of the update manifest golden test (the GDScript side runs inside 'tests').
    Write-Host '== manifest golden =='
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'check_manifest_golden.ps1')
    if ($LASTEXITCODE -ne 0) { Write-Host 'CHECK FAILED: manifest golden'; exit 1 }
    # verify_release.ps1 against the committed signing fixture (good set passes, every kind of damage fails).
    Write-Host '== verify release =='
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'check_verify_release.ps1')
    if ($LASTEXITCODE -ne 0) { Write-Host 'CHECK FAILED: verify release'; exit 1 }
} finally { Pop-Location }
Write-Host 'CHECK PASSED'
exit 0

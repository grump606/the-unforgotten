# End-to-end test of what the installer does to an old install (installer/setup.iss: MigrateOldSaves and
# RemoveOldInstallDir), with the real built setup, on a throwaway CI runner. It writes a fake "Card Battle Prototype"
# install, its uninstall registry entry and old saves into the current user's profile, runs the setup silently and
# checks the result, so it REFUSES to run outside CI (on a desktop it would touch the real profile and registry).
#   powershell -ExecutionPolicy Bypass -File scripts\installer_migration_test.ps1   (after build_installer.ps1)
# Exit code 0 when every check passes, 1 otherwise.
param([switch]$IUnderstandThisChangesMyProfile)
$ErrorActionPreference = 'Stop'
if (-not $env:CI -and -not $IUnderstandThisChangesMyProfile) {
    Write-Host 'installer_migration_test: refusing to run outside CI (it changes the user profile and registry).'
    exit 1
}
$root = Split-Path -Parent $PSScriptRoot
$version = (Select-String -Path (Join-Path $root 'project.godot') -Pattern '^config/version="([^"]+)"').Matches.Groups[1].Value
$setup = Join-Path $root "build\TheUnforgotten-Setup-$version.exe"
if (-not (Test-Path -LiteralPath $setup)) { Write-Host "installer_migration_test: $setup not found (build it first)."; exit 1 }

$programs = Join-Path $env:LOCALAPPDATA 'Programs'
$oldInstall = Join-Path $programs 'Card Battle Prototype'
$newInstall = Join-Path $programs 'The Unforgotten'
$dataBase = Join-Path $env:APPDATA 'Godot\app_userdata'
$oldData = Join-Path $dataBase 'Card Battle Prototype'
$newData = Join-Path $dataBase 'The Unforgotten'
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{7B1E5C52-3D0A-4F6B-9C41-6A2D8E0F1B73}_is1'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$script:problems = 0

function Put([string]$path, [string]$text) {
    New-Item -ItemType Directory -Force (Split-Path -Parent $path) | Out-Null
    [System.IO.File]::WriteAllText($path, $text, $utf8)
}
function Text([string]$path) { if (Test-Path -LiteralPath $path) { [System.IO.File]::ReadAllText($path) } else { '<missing>' } }
function Expect([bool]$ok, [string]$what) {
    if ($ok) { Write-Host "ok   $what" } else { Write-Host "FAIL $what"; $script:problems++ }
}
function Set-PreviousInstall([string]$dir, [string]$displayVersion) {
    New-Item -Force $uninstallKey | Out-Null
    Set-ItemProperty $uninstallKey -Name 'Inno Setup: App Path' -Value $dir
    Set-ItemProperty $uninstallKey -Name 'DisplayVersion' -Value $displayVersion
}
function Run-Setup([string]$label) {
    $log = Join-Path $env:RUNNER_TEMP "setup_$label.log"
    if (-not $env:RUNNER_TEMP) { $log = Join-Path ([IO.Path]::GetTempPath()) "setup_$label.log" }
    $proc = Start-Process -FilePath $setup -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/LOG=`"$log`"") -PassThru -Wait
    Expect ($proc.ExitCode -eq 0) "$label`: setup exits 0 (got $($proc.ExitCode))"
    if ($proc.ExitCode -ne 0 -and (Test-Path -LiteralPath $log)) { Get-Content -LiteralPath $log -Tail 40 | ForEach-Object { Write-Host "  | $_" } }
}

# --- Run 1: an old install with a file of the player's in it; old saves, and a NEWER, different settings file. -------
foreach ($d in @($oldInstall, $newInstall, $oldData, $newData)) { Remove-Item -Recurse -Force -LiteralPath $d -ErrorAction SilentlyContinue }
Put (Join-Path $oldInstall 'CardBattlePrototype.exe') 'old exe'
Put (Join-Path $oldInstall 'unins000.exe') 'old uninstaller'
Put (Join-Path $oldInstall 'unins000.dat') 'old uninstaller data'
Put (Join-Path $oldInstall 'player notes.txt') 'mine'
Put (Join-Path $oldData 'run_save.json') 'OLD SAVE'
Put (Join-Path $oldData 'run_save.json.bak') 'OLD SAVE BACKUP'
Put (Join-Path $oldData 'settings.json') 'OLD SETTINGS'
Put (Join-Path $oldData 'godot.log') 'log'
Put (Join-Path $newData 'settings.json') 'NEWER SETTINGS'
Set-PreviousInstall $oldInstall '0.6.6'
Run-Setup 'run 1'
Expect (Test-Path -LiteralPath (Join-Path $newInstall 'TheUnforgotten.exe')) 'run 1: the game is installed in the folder named after it'
Expect ((Text (Join-Path $newData 'run_save.json')) -eq 'OLD SAVE') 'run 1: the old run save is copied to the new data folder'
Expect ((Text (Join-Path $newData 'run_save.json.bak')) -eq 'OLD SAVE BACKUP') 'run 1: and its backup'
Expect ((Text (Join-Path $newData 'settings.json')) -eq 'NEWER SETTINGS') 'run 1: the newer settings are not overwritten'
Expect ((Text (Join-Path $oldData 'settings.json')) -eq 'OLD SETTINGS') 'run 1: the old data folder is KEPT (its settings differ and exist nowhere else)'
Expect (-not (Test-Path -LiteralPath (Join-Path $oldInstall 'CardBattlePrototype.exe'))) 'run 1: the old exe is removed'
Expect (-not (Test-Path -LiteralPath (Join-Path $oldInstall 'unins000.exe')) -and -not (Test-Path -LiteralPath (Join-Path $oldInstall 'unins000.dat'))) 'run 1: the old uninstaller files are removed'
Expect ((Text (Join-Path $oldInstall 'player notes.txt')) -eq 'mine') "run 1: a file of the player's in the old install folder stays (and so does the folder)"

# --- Run 2: the settings now match, and the old install folder holds only what old setups put there. ----------------
Put (Join-Path $newData 'settings.json') 'OLD SETTINGS'
Remove-Item -Force -LiteralPath (Join-Path $oldInstall 'player notes.txt')
Put (Join-Path $oldInstall 'CardBattlePrototype.exe') 'old exe'
Put (Join-Path $oldInstall 'unins000.exe') 'old uninstaller'
Set-PreviousInstall $oldInstall '0.6.6'
Run-Setup 'run 2'
Expect (-not (Test-Path -LiteralPath $oldData)) 'run 2: with every data file safe in the new folder, the old data folder (log included) is removed'
Expect ((Text (Join-Path $newData 'run_save.json')) -eq 'OLD SAVE' -and (Text (Join-Path $newData 'settings.json')) -eq 'OLD SETTINGS') 'run 2: the new data folder is intact'
Expect (-not (Test-Path -LiteralPath $oldInstall)) 'run 2: an old install folder left empty is removed'
Expect (Test-Path -LiteralPath (Join-Path $newInstall 'TheUnforgotten.exe')) 'run 2: the game is still installed'

if ($script:problems -gt 0) { Write-Host "installer migration: $($script:problems) check(s) FAILED"; exit 1 }
Write-Host 'installer migration: all checks passed'
exit 0

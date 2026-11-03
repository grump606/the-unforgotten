# Starts the game straight in a chosen fight (developer option, see run/debug_launch.gd).
#   .\scripts\debug_fight.ps1 eraser
#   .\scripts\debug_fight.ps1 wisp,crow,hound -Character medium -Hp 20
#   .\scripts\debug_fight.ps1 list            # prints the accepted enemy names
# Engine lookup: -Godot, $env:GODOT_EXE, $env:GODOT, then the winget install, then PATH.
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Fight,
    [string]$Character,
    [int]$Hp,
    [string]$Godot
)
$root = Split-Path -Parent $PSScriptRoot
$winget = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe'
$exe = if ($Godot) { $Godot } elseif ($env:GODOT_EXE) { $env:GODOT_EXE } elseif ($env:GODOT) { $env:GODOT } elseif (Test-Path -LiteralPath $winget) { $winget } else { 'godot' }
$userArgs = @("--fight=$Fight")
if ($Character) { $userArgs += "--character=$Character" }
if ($Hp -gt 0) { $userArgs += "--hp=$Hp" }
& $exe --path $root -- @userArgs

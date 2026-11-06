# Starts the game straight in a chosen fight, shop or rest stop (developer option, see run/debug_launch.gd).
#   .\scripts\debug_fight.ps1 eraser
#   .\scripts\debug_fight.ps1 wisp,crow,hound -Character medium -Hp 20
#   .\scripts\debug_fight.ps1 list                      # prints the accepted enemy names
#   .\scripts\debug_fight.ps1 -Screen vendor            # the first shop, 100 gold, player at 55% HP
#   .\scripts\debug_fight.ps1 -Screen rest -Character thief -Hp 10 -Gold 0
#   .\scripts\debug_fight.ps1 -Screen vendor:2          # the second shop on the line
# Engine lookup: -Godot, $env:GODOT_EXE, $env:GODOT, then the winget install, then PATH.
param(
    [Parameter(Position = 0)][string]$Fight,
    [string]$Screen,
    [string]$Character,
    [int]$Hp,
    [int]$Gold = -1,
    [string]$Godot
)
if (-not $Fight -and -not $Screen) { throw "Give an enemy list (e.g. eraser) or -Screen vendor|rest." }
$root = Split-Path -Parent $PSScriptRoot
$winget = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe'
$exe = if ($Godot) { $Godot } elseif ($env:GODOT_EXE) { $env:GODOT_EXE } elseif ($env:GODOT) { $env:GODOT } elseif (Test-Path -LiteralPath $winget) { $winget } else { 'godot' }
$userArgs = @()
if ($Fight) { $userArgs += "--fight=$Fight" }
if ($Screen) { $userArgs += "--screen=$Screen" }
if ($Character) { $userArgs += "--character=$Character" }
if ($Hp -gt 0) { $userArgs += "--hp=$Hp" }
if ($Gold -ge 0) { $userArgs += "--gold=$Gold" }
& $exe --path $root -- @userArgs

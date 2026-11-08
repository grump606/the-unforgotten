# Reads scripts/engine_version.txt (the one place the engine and Inno Setup versions are written down).
# Dot-source it: . (Join-Path $PSScriptRoot 'engine_version.ps1'). It defines $EngineVersion (a hashtable with
# GODOT_VERSION, GODOT_ZIP_SHA512 and INNO_SETUP_VERSION) and these derived names:
#   $GodotFolder   Godot_v<GODOT_VERSION>_win64.exe          (the unzipped folder name in the repo root)
#   $GodotConsole  Godot_v<GODOT_VERSION>_win64_console.exe  (the console binary inside it)
$EngineVersion = @{}
$engineVersionFile = Join-Path $PSScriptRoot 'engine_version.txt'
foreach ($line in Get-Content -LiteralPath $engineVersionFile) {
    if ($line -match '^\s*([A-Z][A-Z0-9_]*)=(\S+)\s*$') { $EngineVersion[$Matches[1]] = $Matches[2] }
}
foreach ($key in 'GODOT_VERSION', 'GODOT_ZIP_SHA512', 'INNO_SETUP_VERSION') {
    if (-not $EngineVersion.ContainsKey($key)) { throw "$key is missing from scripts/engine_version.txt" }
}
$GodotFolder = "Godot_v$($EngineVersion.GODOT_VERSION)_win64.exe"
$GodotConsole = "Godot_v$($EngineVersion.GODOT_VERSION)_win64_console.exe"

# Reads scripts/engine_version.txt (the one place the engine and Inno Setup versions are written down).
# Dot-source it: . (Join-Path $PSScriptRoot 'engine_version.ps1'). It defines $EngineVersion (a hashtable with
# GODOT_VERSION, GODOT_ZIP_SHA512, GODOT_TEMPLATES_SHA512, INNO_SETUP_VERSION and LEGACY_CLIENT_CAP_MIB) and these derived names:
#   $GodotFolder   Godot_v<GODOT_VERSION>_win64.exe          (the unzipped folder name in the repo root)
#   $GodotConsole  Godot_v<GODOT_VERSION>_win64_console.exe  (the console binary inside it)
$EngineVersion = @{}
$engineVersionFile = Join-Path $PSScriptRoot 'engine_version.txt'
foreach ($line in Get-Content -LiteralPath $engineVersionFile) {
    if ($line -match '^\s*([A-Z][A-Z0-9_]*)=(\S+)\s*$') { $EngineVersion[$Matches[1]] = $Matches[2] }
}
foreach ($key in 'GODOT_VERSION', 'GODOT_ZIP_SHA512', 'GODOT_TEMPLATES_SHA512', 'INNO_SETUP_VERSION', 'LEGACY_CLIENT_CAP_MIB') {
    if (-not $EngineVersion.ContainsKey($key)) { throw "$key is missing from scripts/engine_version.txt" }
}
if ($EngineVersion.LEGACY_CLIENT_CAP_MIB -notmatch '^\d+$') { throw "LEGACY_CLIENT_CAP_MIB in scripts/engine_version.txt must be a whole number of MiB" }
#   $LEGACY_CLIENT_CAP_MIB  the download cap (MiB, an int) of already-released clients
$LEGACY_CLIENT_CAP_MIB = [int]$EngineVersion.LEGACY_CLIENT_CAP_MIB
$GodotFolder = "Godot_v$($EngineVersion.GODOT_VERSION)_win64.exe"
$GodotConsole = "Godot_v$($EngineVersion.GODOT_VERSION)_win64_console.exe"

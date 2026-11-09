# Proves scripts/check_log_patterns.ps1 on sample logs: logs with real engine error shapes must be flagged, logs with
# the intentional noise of our own negative tests must not. The "bad" samples are what Godot 4.7.2 printed for
# scratch scripts that misbehaved; the "noisy" ones are lines copied from a passing full check. A step of check.ps1.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'check_log_patterns.ps1')

$failures = 0
function Expect([string]$name, [string[]]$lines, [bool]$shouldFail) {
    $bad = @(Get-CheckLogFailures $lines)
    $failed = $bad.Count -gt 0
    if ($failed -eq $shouldFail) { Write-Host "ok   $name" }
    else { $script:failures++; Write-Host "FAIL $name (flagged $($bad.Count) line(s), expected $(if ($shouldFail) { 'at least one' } else { 'none' }))" }
}

$bad = [ordered]@{
    'invalid call on null'      = @('A', 'SCRIPT ERROR: Invalid call. Nonexistent function ''foo'' in base ''Nil''.', '   at: _initialize (res://x.gd:10)')
    'invalid call, bare'        = @('Invalid call. Nonexistent function ''bar'' in base ''RefCounted''.')
    'invalid access'            = @('SCRIPT ERROR: Invalid access to property or key ''x'' on a base object of type ''Nil''.')
    'invalid access, bare'      = @('Invalid access to property or key ''hp'' on a base object of type ''Dictionary''.')
    'out of bounds script error' = @('SCRIPT ERROR: Out of bounds get index ''5'' (on base: ''Array'')')
    'cannot call method'        = @('Cannot call method ''free'' on a null value.')
    'null instance'             = @('Attempt to call function ''x'' in base ''null instance'' on a null instance.')
    'parse error'               = @('SCRIPT ERROR: Parse Error: Cannot find member "call" in base "String".')
    'failed to load'            = @('ERROR: Failed to load script "res://x.gd" with error "Parse error".')
    'engine: required object null' = @('ERROR: Required object "rp_child" is null.', '   at: add_child (scene/main/node.cpp:1715)')
    'engine: parameter null'    = @('ERROR: Parameter "p_node" is null.', '   at: remove_child (scene/main/node.cpp:1)')
    'engine: index out of bounds' = @('ERROR: Index p_index = 7 is out of bounds (size = 3).', '   at: get (core/templates/cowdata.h:1)')
    'engine: method failed'     = @('ERROR: Method/function failed. Returning: false', '   at: x (core/y.cpp:2)')
    'bad line after a push_error' = @('ERROR: pushed on purpose', '   at: push_error (core/variant/variant_utility.cpp:1023)', 'ERROR: Parameter "p" is null.', '   at: add_child (scene/main/node.cpp:9)')
    'bad line at the end of the log' = @('fine', 'ERROR: Required object "x" is null.')
    'unknown engine error'      = @('ERROR: Something the allowlist has never seen.', '   at: foo (core/io/thing.cpp:12)')
    'unknown error with no at line' = @('ERROR: Something odd happened', 'TEST FILE: x_tests.gd')
    'known message at another location' = @('ERROR: Condition "len == 0" is true. Returning: FAILED', '   at: elsewhere (core/other/file.cpp:9)')
    'known message, then a bad line' = @('ERROR: Error parsing key ''5''.', 'ERROR: Parameter "p" is null.', '   at: add_child (scene/main/node.cpp:9)')
    'failed to open outside the installer tests' = @('ERROR: Failed to open ''C:/x/save.json''.', '   at: copy (core/io/dir_access.cpp:426)')
    'leaked at exit, wrong shape' = @('ERROR: 3 nodes were leaked at exit.', '   at: cleanup (core/object/object.cpp:1)')
    'script error, exact case' = @('SCRIPT ERROR: Parse Error: Expected expression.')
}
$noisy = [ordered]@{
    'push_error from a negative test' = @('ERROR: Combat.create: the deck is empty', '   at: push_error (core/variant/variant_utility.cpp:1023)', '   GDScript backtrace (most recent call first):', '       [0] create (res://combat/combat.gd:10)')
    'push_error naming a null'      = @('ERROR: Combat.create: an enemy entry is null (its data failed to load)', '   at: push_error (core/variant/variant_utility.cpp:1023)')
    'push_error that mimics the engine wording' = @('ERROR: Parameter "x" is null', '   at: push_error (core/variant/variant_utility.cpp:1023)')
    'push_warning'                  = @('WARNING: pushed warning', '   at: push_warning (core/variant/variant_utility.cpp:1033)')
    'resources still in use at exit' = @('ERROR: 198 resources still in use at exit (run with --verbose for details).', '   at: clear (core/io/resource.cpp:822)', 'ERROR: 1 RID allocations of type ''PN13RendererDummy14TextureStorage12DummyTextureE'' were leaked at exit.', 'WARNING: 3 RIDs of type "CanvasItem" were leaked.')
    'known bad-argument engine errors' = @('ERROR: Condition "len == 0" is true. Returning: FAILED', '   at: update (core/crypto/hashing_context.cpp:54)', 'ERROR: Error parsing key ''-15714''.', '   at: load_from_string (modules/mbedtls/crypto_mbedtls.cpp:109)', 'ERROR: Failed to open ''C:/x/TheUnforgotten-Setup-0.3.9.exe''.', '   at: copy (core/io/dir_access.cpp:426)')
    'lowercase prose is not an engine error' = @('the script error handler reset, parse error text in a log line', 'invalid call to nothing')
    'ordinary output'               = @('TEST FILE: combat_core_tests.gd', 'CHECKS: 9000', 'FAILURES: 0', 'Unicode parsing error, some characters were replaced with U+FFFD: Invalid UTF-8 leading byte (fe)')
    'empty log'                     = @()
}
# Lines copied from a real passing full check (and the CI run of the same commit): every distinct ERROR and WARNING
# shape with the line after it. Nothing in it may be flagged. Refresh it when a new kind of noise is allowed.
$real = @(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'check_log_samples\passing_noise.txt'))
if ($real.Count -lt 40) { $failures++; Write-Host 'FAIL the real-log fixture is missing or too short' }
$noisy['real passing-log lines (scripts/check_log_samples/passing_noise.txt)'] = $real
foreach ($k in $bad.Keys) { Expect "flags: $k" $bad[$k] $true }
foreach ($k in $noisy.Keys) { Expect "passes: $k" $noisy[$k] $false }

if ($failures -gt 0) { Write-Host "check log patterns: $failures sample(s) wrong"; exit 1 }
Write-Host 'check log patterns OK'
exit 0

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
    'bad line after a push_error' = @('ERROR: Combat.create: the deck is empty', '   at: push_error (core/variant/variant_utility.cpp:1023)', 'ERROR: Parameter "p" is null.', '   at: add_child (scene/main/node.cpp:9)')
    'bad line at the end of the log' = @('fine', 'ERROR: Required object "x" is null.')
    'unknown engine error'      = @('ERROR: Something the allowlist has never seen.', '   at: foo (core/io/thing.cpp:12)')
    'unknown error with no at line' = @('ERROR: Something odd happened', 'TEST FILE: x_tests.gd')
    'known message at another location' = @('ERROR: Condition "len == 0" is true. Returning: FAILED', '   at: elsewhere (core/other/file.cpp:9)')
    'known message, then a bad line' = @('ERROR: Error parsing key ''5''.', 'ERROR: Parameter "p" is null.', '   at: add_child (scene/main/node.cpp:9)')
    'failed to open outside the installer tests' = @('ERROR: Failed to open ''C:/x/save.json''.', '   at: copy (core/io/dir_access.cpp:426)')
    'leaked at exit, wrong shape' = @('ERROR: 3 nodes were leaked at exit.', '   at: cleanup (core/object/object.cpp:1)')
    'unknown push_error'        = @('ERROR: Combat.apply_damage: negative amount on a real fight', '   at: push_error (core/variant/variant_utility.cpp:1023)')
    'push_error that mimics the engine wording' = @('ERROR: Parameter "x" is null', '   at: push_error (core/variant/variant_utility.cpp:1023)')
    'known push_error text with other trailing text' = @('ERROR: Combat.create: the deck is empty after the update', '   at: push_error (core/variant/variant_utility.cpp:1023)')
    'known push_error text at a non-push_error location' = @('ERROR: Combat.create: the deck is empty', '   at: elsewhere (core/io/thing.cpp:12)')
    'unknown push_error between known ones' = @('ERROR: Combat.create: the deck is empty', '   at: push_error (core/variant/variant_utility.cpp:1023)', 'ERROR: Brand new failure', '   at: push_error (core/variant/variant_utility.cpp:1023)', 'ERROR: Combat.start: the fight was already started or has ended', '   at: push_error (core/variant/variant_utility.cpp:1023)')
    'script error, exact case' = @('SCRIPT ERROR: Parse Error: Expected expression.')
}
$noisy = [ordered]@{
    'push_error from a negative test' = @('ERROR: Combat.create: the deck is empty', '   at: push_error (core/variant/variant_utility.cpp:1023)', '   GDScript backtrace (most recent call first):', '       [0] create (res://combat/combat.gd:10)')
    'push_error naming a null'      = @('ERROR: Combat.create: an enemy entry is null (its data failed to load)', '   at: push_error (core/variant/variant_utility.cpp:1023)')
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
# Every known push_error pattern must be matched by an example line below, and every example must be allowed.
$knownExamples = @(
    'ERROR: Combat._apply: ADD_CARD effect has no card'
    'ERROR: Combat.create: an enemy entry is null (its data failed to load)'
    'ERROR: Combat.create: needs 1 to 3 enemies, got 4'
    'ERROR: Combat.create: the deck is empty'
    'ERROR: Combat.create: the player is already dead'
    'ERROR: Combat.start: the fight was already started or has ended'
    'ERROR: RunState.complete_combat: not at a combat stop awaiting a result'
    'ERROR: RunState.complete_combat: the caller reported a defeat but the fight ended in a victory'
    'ERROR: RunState.complete_combat: the caller reported a victory but the fight ended in a defeat'
    'ERROR: RunState.resolve_reward: card was not offered'
    'ERROR: RunState.resolve_reward_remove: card is not in the deck'
    'ERROR: RunState.start_combat: not at a fresh combat stop'
    'ERROR: sim_exit_tests: deliberate bot error (expected in this log)'
    'ERROR: sim_engine_error_tests: deliberate engine error (expected in this log)'
    'ERROR: Combat._apply: no handler for CardEffect kind 9999'
    'ERROR: SmartPolicy._effect_score: no valuation for CardEffect.Kind 9999'
    'ERROR: StarterContent.character: unknown character ''nobody'''
    'ERROR: StarterContent.character: unknown character ''no_such_character'''
    'ERROR: StarterContent.created_card: unknown created card id dread'
    'ERROR: StarterContent.created_card: unknown created card id no_such_card'
    'ERROR: StarterContent: missing or non-CardData resource: res://data/enemies/gate_warden.tres'
    'ERROR: StarterContent: missing or non-EnemyData resource: res://data/cards/shove.tres'
    'ERROR: StoryContent.beat: no beat at index -1'
    'ERROR: UserDataMigration: refusing to migrate ''C:/Users/x/app_userdata/The Unforgotten/migration_test_33092/refuse/Something Else'''
    'ERROR: Vendor.buy_card: bad offer index 3'
    'ERROR: Vendor.buy_relic: player is required'
    'ERROR: Vendor.gold_for_win: enemy_count must be >= 1, got 0'
    'ERROR: Vendor.remove_card: bad deck index -1'
    'ERROR: Vendor: starting gold must be >= 0, got -5'
)
foreach ($pattern in $script:CheckKnownPushErrors) {
    $hit = @($knownExamples | Where-Object { $_ -cmatch $pattern })
    if ($hit.Count -eq 0) { $failures++; Write-Host "FAIL no example line in this test matches the known push_error pattern $pattern" }
}
foreach ($example in $knownExamples) { Expect "passes: known push_error '$example'" @($example, '   at: push_error (core/variant/variant_utility.cpp:1023)') $false }
foreach ($k in $bad.Keys) { Expect "flags: $k" $bad[$k] $true }
foreach ($k in $noisy.Keys) { Expect "passes: $k" $noisy[$k] $false }

if ($failures -gt 0) { Write-Host "check log patterns: $failures sample(s) wrong"; exit 1 }
Write-Host 'check log patterns OK'
exit 0

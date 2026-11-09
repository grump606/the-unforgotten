# What scripts/check.ps1 treats as a failure inside a step's output even when the engine exits 0.
# Dot-source this file; scripts/check_log_patterns_test.ps1 proves the rules against sample logs.
#
# Godot prints every GDScript runtime error as "SCRIPT ERROR: <message>" (Invalid call, Invalid access,
# Nonexistent function, Cannot call method, Out of bounds ...) and a parse failure as "SCRIPT ERROR: Parse Error"
# or "ERROR: Failed to load script". The script then stops, which in a headless -s run usually means the step hangs
# (check.ps1's timeout catches that) or ends early. These strings are fixed by the engine, so the rules are
# case-sensitive. The second shape is an engine-side error, "ERROR: <message>" followed by an
# "   at: <function> (<engine source file>:<line>)" line, for example
#   ERROR: Required object "rp_child" is null.        at: add_child (scene/main/node.cpp:1715)
#   ERROR: Parameter "p_shape" is null.                at: ... (servers/...)
# Every such ERROR line fails the step unless it is known test noise, an ALLOWLIST keyed on where the engine says it
# came from (the "at:" line), not on a broad message shape:
#   - push_error() with one of the KNOWN messages that a test provokes on purpose ($script:CheckKnownPushErrors,
#     "at: push_error (core/variant/...)"). A push_error with any other message is unknown, so a real regression that
#     reports through push_error fails the check;
#   - the few engine complaints about a deliberately bad argument that the suite makes on purpose;
#   - the engine's own exit-time leak report.
# An ERROR line that is none of those is unknown, and an unknown error is a failure: either fix the code, or add it
# to $script:CheckKnownEngineErrors (or, for a push_error, $script:CheckKnownPushErrors) with a comment on which test
# causes it. WARNING: lines never fail a step.
# The allowlist was built from a real full passing log (and the CI log of the same commit); the samples in
# scripts/check_log_patterns_test.ps1 pin it.

# Lines that are failures by themselves (case-sensitive).
$script:CheckFailLinePattern = 'SCRIPT ERROR|Parse Error|ERROR: Failed to load|Invalid call\. Nonexistent function|Invalid access to property or key|Cannot call method|Null instance|Attempt to call function|Stack overflow|handle_crash|Program crashed'

# "at:" location of a push_error() call.
$script:CheckPushErrorAt = '^\s*at: push_error \(core/variant/'

# push_error() messages the test suite provokes on purpose (negative tests of the game's own guards), collected from a
# real full passing log. Anchored regexes on the whole ERROR line; numbers and the scratch folder are wildcards.
$script:CheckKnownPushErrors = @(
    '^ERROR: Combat\._apply: ADD_CARD effect has no card$'                                   # tests/cycling_tests.gd
    '^ERROR: Combat\.create: an enemy entry is null \(its data failed to load\)$'            # tests/combat_core_tests.gd
    '^ERROR: Combat\.create: needs 1 to 3 enemies, got \d+$'                                 # combat_core_tests.gd, engine_review_tests.gd
    '^ERROR: Combat\.create: the deck is empty$'
    '^ERROR: Combat\.create: the player is already dead$'
    '^ERROR: Combat\.start: the fight was already started or has ended$'                     # combat_core_tests.gd, mechanics_tests.gd
    '^ERROR: RunState\.complete_combat: not at a combat stop awaiting a result$'             # tests/run_state_flow_tests.gd
    '^ERROR: RunState\.complete_combat: the caller reported a (defeat but the fight ended in a victory|victory but the fight ended in a defeat)$' # run_state_outcome_tests.gd
    '^ERROR: RunState\.resolve_reward: card was not offered$'                                # run_state_reward_tests.gd
    '^ERROR: RunState\.resolve_reward_remove: card is not in the deck$'
    '^ERROR: RunState\.start_combat: not at a fresh combat stop$'                            # run_state_flow_tests.gd
    '^ERROR: sim_exit_tests: deliberate bot error \(expected in this log\)$'                 # tests/sim_exit_tests.gd
    '^ERROR: SmartPolicy\._effect_score: no valuation for CardEffect\.Kind -?\d+$'          # tests/sim_exit_tests.gd
    '^ERROR: StarterContent\.character: unknown character ''nobody''$'                       # content_tests.gd, run_state_flow_tests.gd
    '^ERROR: StarterContent\.created_card: unknown created card id (dread|no_such_card)$'    # tests/starter_tests.gd
    '^ERROR: StarterContent: missing or non-(CardData|EnemyData) resource: res://data/(cards|enemies)/[a-z_]+\.tres$' # combat_core_tests.gd
    '^ERROR: StoryContent\.beat: no beat at index -?\d+$'                                    # run_state_stop_tests.gd
    '^ERROR: UserDataMigration: refusing to migrate ''[^'']+/migration_test_\d+/refuse/(Card Battle Prototype|Something Else)''$' # tests/migration_tests.gd
    '^ERROR: Vendor\.buy_card: bad offer index -?\d+$'                                       # tests/vendor_tests.gd
    '^ERROR: Vendor\.buy_relic: player is required$'                                         # tests/relic_tests.gd
    '^ERROR: Vendor\.gold_for_win: enemy_count must be >= 1, got -?\d+$'
    '^ERROR: Vendor\.remove_card: bad deck index -?\d+$'
    '^ERROR: Vendor: starting gold must be >= 0, got -?\d+$'
)

# Known engine-side noise: @{ Message = <regex on the ERROR line>; At = <regex on the next line, or '' when the
# engine prints no "at:" line> }.
$script:CheckKnownEngineErrors = @(
    # tests/update_verifier_tests.gd: hashing an empty/absent buffer on purpose.
    @{ Message = '^ERROR: Condition "len == 0" is true\. Returning: FAILED$'; At = '^\s*at: update \(core/crypto/hashing_context\.cpp:\d+\)' }
    # tests/update_verifier_tests.gd: a garbage public key on purpose.
    @{ Message = '^ERROR: Error parsing key ''-?\d+''\.$'; At = '^\s*at: load_from_string \(modules/mbedtls/crypto_mbedtls\.cpp:\d+\)' }
    # tests/update_installer_edge_tests.gd: a launch copy of an installer that is gone (the swapped-file and discard cases).
    @{ Message = '^ERROR: Failed to open ''[^'']+TheUnforgotten-Setup-[0-9.]+\.exe''\.$'; At = '^\s*at: copy \(core/io/dir_access\.cpp:\d+\)' }
    # The engine's leak report when the process exits (a headless script never frees every resource).
    @{ Message = '^ERROR: \d+ resources still in use at exit'; At = '^\s*at: clear \(core/io/resource\.cpp:\d+\)' }
    @{ Message = '^ERROR: \d+ RID allocations of type ''[^'']+'' were leaked at exit\.$'; At = '' }
)

# Returns the lines of $Lines that make the step fail (empty array: the output is clean).
function Get-CheckLogFailures([string[]]$Lines) {
    $bad = @()
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        if ($line -cmatch $script:CheckFailLinePattern) { $bad += $line; continue }
        if ($line -cnotmatch '^ERROR: ') { continue }
        $next = if ($i + 1 -lt $Lines.Count) { $Lines[$i + 1] } else { '' }
        $known = $false
        if ($next -cmatch $script:CheckPushErrorAt) {
            foreach ($pattern in $script:CheckKnownPushErrors) {
                if ($line -cmatch $pattern) { $known = $true; break }
            }
            if (-not $known) { $bad += $line }
            continue
        }
        foreach ($rule in $script:CheckKnownEngineErrors) {
            if ($line -cmatch $rule.Message -and ($rule.At -eq '' -or $next -cmatch $rule.At)) { $known = $true; break }
        }
        if (-not $known) { $bad += $line }
    }
    return $bad
}

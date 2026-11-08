# What scripts/check.ps1 treats as a failure inside a step's output even when the engine exits 0.
# Dot-source this file; scripts/check_log_patterns_test.ps1 proves the rules against sample logs.
#
# Godot prints every GDScript runtime error as "SCRIPT ERROR: <message>" (Invalid call, Invalid access,
# Nonexistent function, Cannot call method, Out of bounds ...) and a parse failure as "SCRIPT ERROR: Parse Error"
# or "ERROR: Failed to load script". The script then stops, which in a headless -s run usually means the step hangs
# (check.ps1's timeout catches that) or ends early. The second shape is an engine-side error, "ERROR: <message>"
# followed by an "   at: <function> (<engine source file>:<line>)" line, for example
#   ERROR: Required object "rp_child" is null.        at: add_child (scene/main/node.cpp:1715)
#   ERROR: Parameter "p_shape" is null.                at: ... (servers/...)
#   ERROR: Index p_index = 7 is out of bounds (size = 3).
# Those are a game or test calling the engine wrongly, so they fail too, with ONE exception: push_error() from a
# test that deliberately feeds bad input prints "ERROR: <text>" with "at: push_error (core/variant/...)". That
# noise never fails a step, and neither do the engine's own complaints about a deliberately bad argument that the
# suite already knows about ("Condition ... is true", "Failed to open", "Error parsing key"), nor WARNING: lines,
# leaked-object and "resources still in use" lines at exit.

# Lines that are failures by themselves.
$script:CheckFailLinePattern = 'SCRIPT ERROR|Parse Error|ERROR: Failed to load|Invalid call\. Nonexistent function|Invalid access to property or key|Cannot call method|Null instance|Attempt to call function|Stack overflow|handle_crash|Program crashed'

# "ERROR: <message>" lines whose message says the engine rejected a call, kept only when the next line is not a
# push_error() location.
$script:CheckEngineErrorMessage = '^ERROR: (Required object ".+" is null|Parameter ".+" is null|Index .+ is out of bounds|Method/function failed|Cannot call|Invalid (call|access|assignment|get index|set index))'

# Returns the lines of $Lines that make the step fail (empty array: the output is clean).
function Get-CheckLogFailures([string[]]$Lines) {
    $bad = @()
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        if ($line -match $script:CheckFailLinePattern) { $bad += $line; continue }
        if ($line -match $script:CheckEngineErrorMessage) {
            $next = if ($i + 1 -lt $Lines.Count) { $Lines[$i + 1] } else { '' }
            if ($next -match '^\s*at: push_error\b') { continue }
            $bad += $line
        }
    }
    return $bad
}

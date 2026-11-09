extends RefCounted
## Source scan used by ui_reduced_motion_test.gd: finds every function that starts a tween, a timer, an
## AnimationPlayer or a particle node, or that is a per-frame callback, and says whether that function honours
## Motion.reduced. The check is per function, so one mention of Motion.reduced in a file no longer clears every
## animation in it. A function that animates for a reason that needs no motion setting carries a marker comment
## inside it: `# motion-ok: <reason of at least ten characters>`. Not a test itself (see test_wiring_tests.gd).

## What starts or is an animation. Only calls and per-frame callbacks count; a Tween type annotation does not.
const MARKERS := [
	"create_timer", "Timer.new", "create_tween(", "func _process(", "func _physics_process(",
	"AnimationPlayer", "GPUParticles", "CPUParticles",
]
const OK_MARKER := "# motion-ok:"
const MIN_REASON := 10


## One entry per function that contains a marker: {"name", "line" (1-based, of the func line), "hits" (marker
## count), "honoured" (mentions Motion.reduced in code, or carries a motion-ok marker with a reason)}.
static func sites(src: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var lines := src.split("\n")
	var start := 0
	var name := "<top level>"
	for i in range(lines.size() + 1):
		var at_end := i == lines.size()
		if at_end or _starts_function(lines[i]):
			_close(found, lines, start, i, name)
			if not at_end:
				start = i
				name = _function_name(lines[i])
	return found


static func _starts_function(line: String) -> bool:
	if line.begins_with("\t\t"):
		return false # a nested lambda or a block inside a function
	var text := line.strip_edges()
	return text.begins_with("func ") or text.begins_with("static func ")


static func _function_name(line: String) -> String:
	var text := line.strip_edges().trim_prefix("static ").trim_prefix("func ")
	return text.get_slice("(", 0)


## Adds an entry for lines[from, to) when it contains a marker.
static func _close(found: Array[Dictionary], lines: PackedStringArray, from: int, to: int, name: String) -> void:
	var hits := 0
	var mentions := false
	var marked := false
	for i in range(from, to):
		var raw := lines[i]
		var text := raw.strip_edges()
		if text.contains(OK_MARKER):
			var reason := text.substr(text.find(OK_MARKER) + OK_MARKER.length()).strip_edges()
			marked = marked or reason.length() >= MIN_REASON
		if text.begins_with("#"):
			continue
		var code := raw.get_slice(" # ", 0) # what follows a trailing comment mark is prose
		for m in MARKERS:
			hits += code.count(m)
		mentions = mentions or code.contains("Motion.reduced")
	if hits > 0:
		found.append({"name": name, "line": from + 1, "hits": hits, "honoured": mentions or marked})


## The functions of `src` that animate without honouring Motion.reduced (names with line numbers).
static func unguarded(src: String) -> Array[String]:
	var bad: Array[String] = []
	for site in sites(src):
		if not site.honoured:
			bad.append("%s (line %d)" % [site.name, site.line])
	return bad

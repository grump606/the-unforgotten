extends "res://tests/test_base.gd"
## Everything under run/ talks to the Battle screen only through its public methods: no private member
## (`_battle._x`) is reached, directly or through an alias (`var bt := _battle; bt._x`), and no reflection reaches one
## either (`.get("_x")`, `.set("_x", ...)`, `.call("_x")`). battle.gd itself is the owner and is not scanned. A renamed
## field or a reordered setup in battle.gd must not break the helpers silently.

## Names that hold the Battle in the helpers; any other variable typed or assigned from one of these joins them.
const SEED_NAMES := ["_battle", "battle"]


## Offences found in one script's source: {"line", "text", "why"} per offending line.
static func offences(src: String) -> Array[Dictionary]:
	var lines := src.split("\n")
	var code: Array[String] = []
	for raw in lines:
		var text: String = raw.strip_edges()
		code.append("" if text.begins_with("#") else raw.get_slice(" # ", 0))
	var names := _alias_names(code)
	var members := RegEx.create_from_string(r"\b(" + "|".join(names) + r")\s*\.\s*_[A-Za-z_]")
	var reflection := RegEx.create_from_string(r"\.\s*(get|set|call|has_method|get_indexed)\s*\(\s*&?[\"']_")
	var found: Array[Dictionary] = []
	for i in code.size():
		if members.search(code[i]) != null:
			found.append({"line": i + 1, "text": code[i].strip_edges(), "why": "private member of Battle"})
		elif reflection.search(code[i]) != null:
			found.append({"line": i + 1, "text": code[i].strip_edges(), "why": "reflection on a private name"})
	return found


## The seed names plus every variable declared as a Battle or assigned from a name already known, to a fixed point.
static func _alias_names(code: Array[String]) -> Array[String]:
	var names: Array[String] = []
	names.assign(SEED_NAMES)
	var typed := RegEx.create_from_string(r"\b([A-Za-z_][A-Za-z_0-9]*)\s*:\s*Battle\b")
	var cast := RegEx.create_from_string(r"\b([A-Za-z_][A-Za-z_0-9]*)\s*:?=.*\bas\s+Battle\b")
	var changed := true
	while changed:
		changed = false
		var assigned := RegEx.create_from_string(r"\b([A-Za-z_][A-Za-z_0-9]*)\s*(?::\s*\w+\s*)?:?=\s*(?:" + "|".join(names) + r")\s*$")
		for line in code:
			for rx in [typed, cast, assigned]:
				for m in (rx as RegEx).search_all(line):
					var alias := m.get_string(1)
					if not names.has(alias) and alias != "var":
						names.append(alias)
						changed = true
	return names


func _scripts(dir_path: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".gd"):
			out.append(dir_path + "/" + f)
	for d in DirAccess.get_directories_at(dir_path):
		_scripts(dir_path + "/" + d, out)


func _test_samples() -> void:
	var bad := {
		"direct underscore member": "\t_battle._hand.sync()",
		"plain name": "\tbattle._combat.foo()",
		"alias by assignment": "var bt := _battle\nbt._hand.sync()",
		"alias by typed assignment": "var bt: Battle = _battle\nbt._x = 1",
		"alias of an alias": "var a := _battle\nvar b2 := a\nb2._x()",
		"typed parameter": "func f(bt: Battle) -> void:\n\tbt._combat = null",
		"cast": "var bt := get_parent() as Battle\nbt._combat = null",
		"reflection get": "\tvar v = _battle.get(\"_combat\")",
		"reflection set": "\t_battle.set(\"_combat\", null)",
		"reflection call": "\t_battle.call(\"_refresh\")",
		"reflection call, name literal": "\tsomething.call(&\"_refresh\")",
		"spacing": "\t_battle . _hand.sync()",
	}
	for label in bad:
		_check(not offences(bad[label]).is_empty(), "the scan flags: %s" % label)
	var good := {
		"public member": "\t_battle.hand().sync()",
		"comment": "\t# _battle._hand is private",
		"trailing comment": "\t_battle.end_turn() # not _battle._x",
		"own private member": "\t_x = 1\n\tself._y = 2",
		"other object": "\tother._hand.sync()",
		"public reflection": "\t_battle.call(\"end_turn\")",
		"alias public use": "var bt := _battle\nbt.end_turn()",
		"unrelated assignment": "var bt := _other\nbt._x = 1",
		"similar name": "\tbattle_state._x = 1",
	}
	for label in good:
		_check(offences(good[label]).is_empty(), "the scan accepts: %s" % label)


func run() -> int:
	_failures = 0
	_test_samples()
	var files: Array[String] = []
	_scripts("res://run", files)
	var scanned := 0
	var found: Array[String] = []
	for path in files:
		scanned += 1
		for o in offences(FileAccess.get_file_as_string(path)):
			found.append("%s:%d %s (%s)" % [path, o.line, o.text, o.why])
	_check(scanned >= 60 and files.has("res://run/battle/battle_hand.gd") and files.has("res://run/screens/combat_screen.gd"), "the scan covers all of run/ and its subfolders (%d files)" % scanned)
	_check(found.is_empty(), "nothing under run/ reaches into a private member of Battle: %s" % "; ".join(found))
	return _failures

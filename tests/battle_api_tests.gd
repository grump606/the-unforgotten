extends "res://tests/test_base.gd"
## The helpers under run/battle/ talk to the Battle screen only through its public methods: no `_battle._x` reach
## into a private member (a renamed field or a reordered setup in battle.gd must not break them silently).


func run() -> int:
	_failures = 0
	var reach := RegEx.create_from_string(r"\b(_battle|battle|owner|b)\._[A-Za-z_]")
	var scanned := 0
	var offenders: Array[String] = []
	for f in DirAccess.get_files_at("res://run/battle"):
		if not f.ends_with(".gd"):
			continue
		scanned += 1
		var lines := FileAccess.get_file_as_string("res://run/battle/" + f).split("\n")
		for i in lines.size():
			var line := lines[i].strip_edges()
			if not line.begins_with("#") and reach.search(line) != null:
				offenders.append("%s:%d %s" % [f, i + 1, line])
	_check(scanned >= 8, "the scan found the battle helpers (%d files)" % scanned)
	_check(offenders.is_empty(), "no helper under run/battle/ reaches into a private member of Battle: %s" % "; ".join(offenders))
	return _failures

extends "res://tests/test_base.gd"
## Keeps the docs honest about the code: every `Class.member` written in backticks in docs/*.md, where Class is one of
## the project's class_name scripts, must name something that script still declares (a func, var, const, signal,
## enum or inner class, annotations such as @export included). Moving or renaming code then fails here until the
## docs follow, instead of leaving them pointing at nothing.
##
## Also accepted: `Class.new` and `Class.duplicate` (built in), and a prefix that ends in "_" (`Encounters.BUDGET_ACT_`)
## when some member starts with it.

const DOCS_DIR := "res://docs"
const CODE_DIRS: Array[String] = ["res://combat", "res://run", "res://tools", "res://tests"]
const BUILT_IN: Array[String] = ["new", "duplicate"]


func run() -> int:
	_failures = 0
	var members := _class_members()
	_check(members.size() >= 50, "the class_name scripts are found (%d)" % members.size())
	var code_span := RegEx.create_from_string("`([^`\\n]+)`")
	var reference := RegEx.create_from_string("\\b([A-Z]\\w+)\\.(\\w+)")
	var checked := 0
	for file_name in DirAccess.get_files_at(DOCS_DIR):
		if not file_name.ends_with(".md"):
			continue
		var text := FileAccess.get_file_as_string(DOCS_DIR.path_join(file_name))
		for span in code_span.search_all(text):
			for found in reference.search_all(span.get_string(1)):
				var owner := found.get_string(1)
				if not members.has(owner):
					continue
				var member := found.get_string(2)
				checked += 1
				_check(_known(members[owner], member), "docs/%s names `%s.%s`, which %s does not declare: update the doc to where it lives now" % [file_name, owner, member, owner])
	_check(checked >= 100, "doc references are found and checked (%d)" % checked)
	return _failures


func _known(declared: Dictionary, member: String) -> bool:
	if declared.has(member) or BUILT_IN.has(member):
		return true
	if member.ends_with("_"):
		for name: String in declared:
			if name.begins_with(member):
				return true
	return false


## {class_name: {member: true}} for every class_name script in CODE_DIRS and the project root.
func _class_members() -> Dictionary:
	var files: Array[String] = []
	for dir in CODE_DIRS:
		_collect(dir, files)
	for file_name in DirAccess.get_files_at("res://"):
		if file_name.ends_with(".gd"):
			files.append("res://" + file_name)
	var class_regex := RegEx.create_from_string("(?m)^class_name\\s+(\\w+)")
	var member_regex := RegEx.create_from_string("(?m)^\\s*(?:@\\w+(?:\\([^)]*\\))?\\s+)*(?:static\\s+)?(?:func|var|const|signal|enum|class)\\s+(\\w+)")
	var out := {}
	for path in files:
		var source := FileAccess.get_file_as_string(path)
		var found := class_regex.search(source)
		if found == null:
			continue
		var declared := {}
		for m in member_regex.search_all(source):
			declared[m.get_string(1)] = true
		out[found.get_string(1)] = declared
	return out


func _collect(dir: String, into: Array[String]) -> void:
	for file_name in DirAccess.get_files_at(dir):
		if file_name.ends_with(".gd"):
			into.append(dir.path_join(file_name))
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(sub), into)

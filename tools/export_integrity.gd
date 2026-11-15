extends SceneTree
## Export integrity: every scripted .tres in the project must load from the exported game with the same data it has
## in the project. The export converts text resources to binary, and a value lost there is invisible to every test
## that runs from the project (v0.10.0 shipped Find the Seam+ without Ready that way: an exported
## `PackedStringArray = []` default made the converter drop the card's value).
##
## Run by scripts/build_installer.ps1 right after the export:
##   godot --headless --path . -s res://tools/export_integrity.gd -- <exported exe or .pck>
## Prints one DIFF line per resource that differs and exits 1 if any does (or the pack cannot be loaded).

## Properties that hold engine state rather than game data.
const SKIP := ["resource_path", "resource_scene_unique_id", "script", "resource_local_to_scene", "resource_name"]
const MAX_DEPTH := 8


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("export integrity: pass the exported exe or .pck after --")
		quit(1)
		return
	var files: Array[String] = []
	_collect("res://", files)
	var before := {}
	for path in files:
		var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if res != null and res.get_script() != null:
			before[path] = var_to_str(_dump(res, 0))
	if not ProjectSettings.load_resource_pack(args[0], true):
		printerr("export integrity: cannot load the pack in %s" % args[0])
		quit(1)
		return
	var differing := 0
	for path: String in before:
		var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		var after := var_to_str(_dump(res, 0)) if res != null else "<missing>"
		if after != before[path]:
			differing += 1
			print("DIFF %s\n  project: %s\n  export:  %s" % [path, _around(before[path], after), _around(after, before[path])])
	print("export integrity: %d scripted resources compared, %d differ" % [before.size(), differing])
	quit(1 if differing > 0 or before.size() < 100 else 0)


## A comparable picture of a value: stored properties of resources (recursively), arrays and dictionaries item by item.
## Scripts, textures, audio and fonts are named by class only (they are not converted the same way, and not game data).
func _dump(value: Variant, depth: int) -> Variant:
	if depth > MAX_DEPTH:
		return "<deep>"
	if value is Script or value is Texture2D or value is AudioStream or value is Font:
		return "<%s>" % value.get_class()
	if value is Resource:
		var out := {}
		for prop in value.get_property_list():
			if prop.usage & PROPERTY_USAGE_STORAGE and not SKIP.has(prop.name):
				out[prop.name] = _dump(value.get(prop.name), depth + 1)
		return out
	if value is Array:
		return value.map(func(item: Variant) -> Variant: return _dump(item, depth + 1))
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[key] = _dump(value[key], depth + 1)
		return out
	return var_to_str(value)


## The part of `text` around where it first differs from `other`.
func _around(text: String, other: String) -> String:
	var i := 0
	while i < mini(text.length(), other.length()) and text[i] == other[i]:
		i += 1
	return text.substr(maxi(i - 60, 0), 140).replace("\n", " ")


func _collect(dir: String, into: Array[String]) -> void:
	for file_name in DirAccess.get_files_at(dir):
		if file_name.ends_with(".tres"):
			into.append(dir.path_join(file_name))
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with(".") and sub != "build":
			_collect(dir.path_join(sub), into)

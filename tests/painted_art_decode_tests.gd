extends "res://tests/test_base.gd"
## PaintedArt.decode_imported reads the imported .ctex file itself (so the warm-up can decode on a worker thread without
## touching the RenderingServer). Its pixels must equal the engine's own decode (the texture loader plus get_image) for
## every art file, so a change in the engine's .ctex layout, or an art file imported another way, fails here instead of
## shipping blank or garbled art. tools/export_integrity.gd checks the same reader against the exported game.

const ART_DIR := "res://art"


func run() -> int:
	_failures = 0
	var files: Array[String] = []
	_collect(ART_DIR, files)
	_check(files.size() >= 250, "the art files are found (%d)" % files.size())
	var same := 0
	for path in files:
		var mine := PaintedArt.decode_imported(path)
		var engine := PaintedArt._decode(path)
		if mine == null or engine == null:
			_check(false, "%s decodes both ways (worker %s, engine %s)" % [path, mine != null, engine != null])
			continue
		mine.generate_mipmaps()
		var equal := mine.get_size() == engine.get_size() and mine.get_format() == engine.get_format() and mine.get_data() == engine.get_data()
		_check(equal, "%s: the worker decode equals the engine's (%s %d vs %s %d)" % [path, mine.get_size(), mine.get_format(), engine.get_size(), engine.get_format()])
		if equal:
			same += 1
	_check(same == files.size(), "every art file decodes identically (%d of %d)" % [same, files.size()])
	_check(PaintedArt.decode_imported("res://art/layers/screens/nope/bg.png") == null, "a missing file decodes to null")
	return _failures


## Every imported PNG under `dir` (the ones with a .import next to them).
func _collect(dir: String, into: Array[String]) -> void:
	for file_name in DirAccess.get_files_at(dir):
		if file_name.ends_with(".png") and FileAccess.file_exists(dir.path_join(file_name) + ".import"):
			into.append(dir.path_join(file_name))
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(sub), into)

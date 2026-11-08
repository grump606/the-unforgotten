class_name UserDataMigration
extends RefCounted
## One-time move of the player's data from the folder the game used before it was renamed
## ("Card Battle Prototype", used up to v0.6.6) to the folder named after the game ("The Unforgotten").
##
## The files that hold player data are copied across (never over a file that already exists in the new
## folder, so newer data always wins), and once every one of them is safe in the new folder the whole old
## folder is removed: what is left in it is logs, shader caches and test leftovers. If any copy fails the
## old folder is kept and the move is tried again on the next launch. The Windows installer does the same
## move after installing (installer/setup.iss, MigrateOldSaves); whichever runs first does the work and the
## other finds nothing to do. Headless runs (the automated tests) never touch the real folders.

const OLD_NAME := "Card Battle Prototype"
## The player's data: the run save and the settings (which also hold the audio levels), each with the
## backup and temporary files the crash-safe writers leave next to them.
const DATA_FILES: Array[String] = [
	"run_save.json", "run_save.json.bak", "run_save.json.tmp",
	"settings.json", "settings.json.bak", "settings.json.tmp",
]


## What a migration did; read by the tests and printed when something moved.
class Result:
	## An old folder existed.
	var found := false
	var copied: Array[String] = []
	## Left alone because the new folder already had a file of that name.
	var skipped: Array[String] = []
	var failed: Array[String] = []
	## The old folder is gone.
	var removed := false


## The old folder that belongs to the given user-data folder: its sibling named OLD_NAME.
static func old_dir_for(new_dir: String) -> String:
	return new_dir.get_base_dir().path_join(OLD_NAME)


## Runs the move for this machine's real folders. Does nothing in headless runs.
static func migrate_default() -> Result:
	if DisplayServer.get_name() == "headless":
		return Result.new()
	var new_dir := OS.get_user_data_dir()
	return migrate(old_dir_for(new_dir), new_dir)


## Copies the data files from `old_dir` into `new_dir` and removes `old_dir` when all of them arrived.
## `old_dir` must be named OLD_NAME: this deletes a folder, so it refuses any other.
static func migrate(old_dir: String, new_dir: String) -> Result:
	var result := Result.new()
	if old_dir.get_file() != OLD_NAME or old_dir.simplify_path() == new_dir.simplify_path():
		push_error("UserDataMigration: refusing to migrate '%s'" % old_dir)
		return result
	if not DirAccess.dir_exists_absolute(old_dir):
		return result
	result.found = true
	if DirAccess.make_dir_recursive_absolute(new_dir) != OK:
		result.failed.append(new_dir)
		return result
	for file_name in DATA_FILES:
		var source := old_dir.path_join(file_name)
		if not FileAccess.file_exists(source):
			continue
		var target := new_dir.path_join(file_name)
		if FileAccess.file_exists(target):
			result.skipped.append(file_name)
		elif _copy_checked(source, target):
			result.copied.append(file_name)
		else:
			result.failed.append(file_name)
	if result.failed.is_empty():
		result.removed = _remove_tree(old_dir)
	if not result.copied.is_empty() or not result.failed.is_empty() or result.removed:
		print("UserDataMigration: moved %d file(s) from '%s'%s%s" % [
			result.copied.size(), old_dir,
			"; failed: %s" % ", ".join(result.failed) if not result.failed.is_empty() else "",
			"; old folder removed" if result.removed else "; old folder kept"])
	return result


## Copies a file and checks that the copy has the same bytes; a bad copy is deleted again.
static func _copy_checked(source: String, target: String) -> bool:
	if DirAccess.copy_absolute(source, target) != OK:
		return false
	if FileAccess.get_file_as_bytes(source) != FileAccess.get_file_as_bytes(target):
		DirAccess.remove_absolute(target)
		return false
	return true


## Deletes a folder and everything under it. Returns false if anything could not be removed. A subfolder that
## is a symlink or junction is never followed (its link is removed, its target is left alone).
static func _remove_tree(path: String) -> bool:
	var dir := DirAccess.open(path)
	if dir == null:
		return false
	var clean := true
	for sub in dir.get_directories():
		var child := path.path_join(sub)
		if dir.is_link(sub):
			clean = DirAccess.remove_absolute(child) == OK and clean
		else:
			clean = _remove_tree(child) and clean
	for file_name in dir.get_files():
		if DirAccess.remove_absolute(path.path_join(file_name)) != OK:
			clean = false
	return DirAccess.remove_absolute(path) == OK and clean

extends RefCounted
## UserDataMigration: the one-time move from the "Card Battle Prototype" user folder to the new one.
## Runs on throwaway folders under the user-data folder, never on the real ones. Registered by run_tests.gd.

var _failures := 0
var _base := ""


func run() -> int:
	_failures = 0
	_base = OS.get_user_data_dir().path_join("migration_test_%d" % OS.get_process_id())
	_test_nothing_to_move()
	_test_moves_data_and_removes_old_folder()
	_test_never_overwrites_newer_data()
	_test_refuses_other_folder_names()
	_test_headless_default_does_nothing()
	_test_old_dir_for()
	_remove_all(_base)
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _remove_all(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	for sub in dir.get_directories():
		_remove_all(path.path_join(sub))
	for file_name in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)


## A fresh pair of folders: the old one named as the migration expects, and the new one.
func _fresh(name: String) -> Array[String]:
	var root := _base.path_join(name)
	_remove_all(root)
	var pair: Array[String] = [root.path_join(UserDataMigration.OLD_NAME), root.path_join("The Unforgotten")]
	return pair


func _test_nothing_to_move() -> void:
	var dirs := _fresh("none")
	var result := UserDataMigration.migrate(dirs[0], dirs[1])
	_check(not result.found and not result.removed and result.copied.is_empty(), "no old folder: nothing happens")
	_check(not DirAccess.dir_exists_absolute(dirs[1]), "no old folder: the new folder is not created")


func _test_moves_data_and_removes_old_folder() -> void:
	var dirs := _fresh("move")
	_write(dirs[0].path_join("run_save.json"), '{"character":"medium"}')
	_write(dirs[0].path_join("run_save.json.bak"), '{"character":"deserter"}')
	_write(dirs[0].path_join("settings.json"), '{"update_check_enabled":false}')
	_write(dirs[0].path_join("godot.log"), "log")
	_write(dirs[0].path_join("shader_cache").path_join("a").path_join("b.bin"), "cache")
	_write(dirs[0].path_join("ui_update_notice_test_settings_1.json.bak"), "leftover")
	var result := UserDataMigration.migrate(dirs[0], dirs[1])
	_check(result.found and result.failed.is_empty() and result.removed, "the move succeeds and reports the old folder removed")
	_check(result.copied.size() == 3, "the three data files were copied")
	_check(_read(dirs[1].path_join("run_save.json")) == '{"character":"medium"}', "the run save arrives unchanged")
	_check(_read(dirs[1].path_join("run_save.json.bak")) == '{"character":"deserter"}', "the save backup arrives too")
	_check(_read(dirs[1].path_join("settings.json")) == '{"update_check_enabled":false}', "the settings arrive")
	_check(not FileAccess.file_exists(dirs[1].path_join("godot.log")), "logs are not copied")
	_check(not DirAccess.dir_exists_absolute(dirs[1].path_join("shader_cache")), "caches are not copied")
	_check(not DirAccess.dir_exists_absolute(dirs[0]), "the whole old folder, caches and leftovers included, is gone")
	var again := UserDataMigration.migrate(dirs[0], dirs[1])
	_check(not again.found and again.copied.is_empty(), "running it again does nothing")


func _test_never_overwrites_newer_data() -> void:
	var dirs := _fresh("keep")
	_write(dirs[0].path_join("run_save.json"), "old save")
	_write(dirs[0].path_join("settings.json"), "old settings")
	_write(dirs[1].path_join("run_save.json"), "newer save")
	var result := UserDataMigration.migrate(dirs[0], dirs[1])
	_check(result.skipped == ["run_save.json"] and result.copied == ["settings.json"], "an existing file is skipped and the rest copied")
	_check(_read(dirs[1].path_join("run_save.json")) == "newer save", "the newer save is untouched")
	_check(_read(dirs[1].path_join("settings.json")) == "old settings", "the missing settings were filled in")
	_check(result.removed, "the old folder is still removed")


func _test_refuses_other_folder_names() -> void:
	var root := _base.path_join("refuse")
	_remove_all(root)
	_write(root.path_join("Something Else").path_join("run_save.json"), "keep me")
	var result := UserDataMigration.migrate(root.path_join("Something Else"), root.path_join("The Unforgotten"))
	_check(not result.found and not result.removed, "a folder not named like the old one is refused")
	_check(FileAccess.file_exists(root.path_join("Something Else").path_join("run_save.json")), "the refused folder is untouched")
	var same := UserDataMigration.migrate(root.path_join(UserDataMigration.OLD_NAME), root.path_join(UserDataMigration.OLD_NAME))
	_check(not same.found, "moving a folder onto itself is refused")


func _test_headless_default_does_nothing() -> void:
	var result := UserDataMigration.migrate_default()
	_check(not result.found and not result.removed, "headless runs never touch the real folders")


func _test_old_dir_for() -> void:
	_check(UserDataMigration.old_dir_for("C:/x/Godot/app_userdata/The Unforgotten") == "C:/x/Godot/app_userdata/Card Battle Prototype", "the old folder is the sibling named Card Battle Prototype")

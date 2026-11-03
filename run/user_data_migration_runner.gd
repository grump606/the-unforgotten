extends Node
## Autoload "UserDataMigrationRunner", listed before AudioManager in project.godot so the move to the
## new user-data folder (UserDataMigration) is finished before anything reads the settings or the save.


func _init() -> void:
	UserDataMigration.migrate_default()

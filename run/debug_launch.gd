class_name DebugLaunch
extends RefCounted
## Developer option: start the game straight in a chosen fight (any boss, or up to Combat.MAX_ENEMIES
## enemies in any combination) instead of the main menu. Never touches the player's save.
##
##   godot --path . -- --fight=eraser
##   godot --path . -- --fight=wisp,crow,hound --character=medium --hp=20
##
## The same values can come from THE_UNFORGOTTEN_FIGHT, THE_UNFORGOTTEN_CHARACTER and THE_UNFORGOTTEN_HP.
## `--fight=list` prints the accepted names. Names match an enemy id, its in-game name, or a short
## alias (ignoring case, spaces and punctuation), e.g. `bellkeeper`, `brakeman`, `the_conductor`.

const ENV_FIGHT := "THE_UNFORGOTTEN_FIGHT"
const ENV_CHARACTER := "THE_UNFORGOTTEN_CHARACTER"
const ENV_HP := "THE_UNFORGOTTEN_HP"

## Short names beyond the id and display name.
const ALIASES := {
	"warden": &"gate_warden", "keeper": &"gate_warden", "shade": &"lost_shade", "wisp": &"skittering_wisp",
	"colossus": &"hollow_colossus", "giant": &"hollow_colossus", "whisperer": &"pale_whisperer",
	"hound": &"cinder_hound", "crow": &"mourning_crow", "brakeman": &"the_brakeman",
	"conductor": &"the_conductor", "eraser": &"the_conductor", "bellkeeper": &"the_brakeman",
}

## The parsed request. `error` is non-empty when the request was malformed (nothing should start);
## `requested` is false when no fight was asked for at all.
var requested := false
var enemy_ids: Array[StringName] = []
var character_id: StringName = StarterContent.DEFAULT_CHARACTER_ID
var hp := -1
var list_only := false
var error := ""


## Reads the user arguments (after `--`) first, then the environment.
static func from_environment() -> DebugLaunch:
	return parse(OS.get_cmdline_user_args(), {
		ENV_FIGHT: OS.get_environment(ENV_FIGHT),
		ENV_CHARACTER: OS.get_environment(ENV_CHARACTER),
		ENV_HP: OS.get_environment(ENV_HP),
	})


static func parse(args: PackedStringArray, env := {}) -> DebugLaunch:
	var launch := DebugLaunch.new()
	var fight_text := String(env.get(ENV_FIGHT, ""))
	var character_text := String(env.get(ENV_CHARACTER, ""))
	var hp_text := String(env.get(ENV_HP, ""))
	for arg in args:
		if arg.begins_with("--fight="):
			fight_text = arg.trim_prefix("--fight=")
		elif arg.begins_with("--character="):
			character_text = arg.trim_prefix("--character=")
		elif arg.begins_with("--hp="):
			hp_text = arg.trim_prefix("--hp=")
	if fight_text.strip_edges() == "":
		return launch
	launch.requested = true
	if _normalize(fight_text) == "list":
		launch.list_only = true
		return launch
	for part in fight_text.split(","):
		var id := resolve(part)
		if id == &"":
			launch.error = "Unknown enemy '%s'. %s" % [part.strip_edges(), help_text()]
			return launch
		launch.enemy_ids.append(id)
	if launch.enemy_ids.is_empty() or launch.enemy_ids.size() > Combat.MAX_ENEMIES:
		launch.error = "A fight needs 1 to %d enemies, got %d." % [Combat.MAX_ENEMIES, launch.enemy_ids.size()]
		return launch
	if character_text.strip_edges() != "":
		var wanted := _normalize(character_text)
		var found := false
		for id in StarterContent.character_ids():
			if _normalize(String(id)) == wanted:
				launch.character_id = id
				found = true
		if not found:
			launch.error = "Unknown character '%s'. Choose from: %s" % [character_text.strip_edges(), ", ".join(StarterContent.character_ids())]
			return launch
	if hp_text.strip_edges() != "":
		if not hp_text.strip_edges().is_valid_int() or int(hp_text) < 1:
			launch.error = "--hp must be a whole number of at least 1."
			return launch
		launch.hp = int(hp_text)
	return launch


## The enemy id a name refers to (id, display name or alias), or &"" if none matches.
static func resolve(name: String) -> StringName:
	var wanted := _normalize(name)
	if wanted == "":
		return &""
	if ALIASES.has(wanted):
		return ALIASES[wanted]
	for id in StarterContent.enemy_ids():
		var data := StarterContent.enemy_by_id(id)
		if _normalize(String(id)) == wanted or (data != null and _normalize(data.display_name) == wanted):
			return id
	return &""


static func help_text() -> String:
	var names: Array[String] = []
	for id in StarterContent.enemy_ids():
		var data := StarterContent.enemy_by_id(id)
		names.append("%s (%s)" % [id, data.display_name if data != null else "?"])
	return "Accepted enemies: %s. Aliases: %s. Up to %d, comma separated." % [", ".join(names), ", ".join(ALIASES.keys()), Combat.MAX_ENEMIES]


static func _normalize(text: String) -> String:
	var out := ""
	for ch in text.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out

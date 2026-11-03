class_name DebugLaunch
extends RefCounted
## Developer option: start the game straight in a chosen fight (any boss, or up to Combat.MAX_ENEMIES
## enemies in any combination) instead of the main menu. Never touches the player's save.
##
##   godot --path . -- --fight=eraser
##   godot --path . -- --fight=wisp,crow,hound --character=medium --hp=20
##
## Or open a shop or rest stop with gold in hand and the player already hurt (defaults: 100 gold, 55% HP):
##
##   godot --path . -- --screen=vendor --character=medium
##   godot --path . -- --screen=rest --gold=0 --hp=10
##   godot --path . -- --screen=vendor:2        (the second shop on the line)
##
## The same values can come from THE_UNFORGOTTEN_FIGHT, THE_UNFORGOTTEN_SCREEN, THE_UNFORGOTTEN_CHARACTER,
## THE_UNFORGOTTEN_HP and THE_UNFORGOTTEN_GOLD.
## `--fight=list` prints the accepted names. Names match an enemy id, its in-game name, or a short
## alias (ignoring case, spaces and punctuation), e.g. `bellkeeper`, `brakeman`, `the_conductor`.

const ENV_FIGHT := "THE_UNFORGOTTEN_FIGHT"
const ENV_CHARACTER := "THE_UNFORGOTTEN_CHARACTER"
const ENV_HP := "THE_UNFORGOTTEN_HP"
const ENV_SCREEN := "THE_UNFORGOTTEN_SCREEN"
const ENV_GOLD := "THE_UNFORGOTTEN_GOLD"

## Stop screens that can be opened directly, mapped to their stop type.
const SCREENS := {"vendor": RunState.StopType.VENDOR, "rest": RunState.StopType.REST}
## Defaults for a screen launch: enough gold for a few purchases, and a player at this share of max HP.
const DEFAULT_GOLD := 100
const DEFAULT_HP_PERCENT := 55

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
## Set for a screen launch ("vendor" or "rest"); `screen_index` picks the nth such stop on the line (1-based).
var screen := ""
var screen_index := 1
var gold := -1
var list_only := false
var error := ""


## Reads the user arguments (after `--`) first, then the environment.
static func from_environment() -> DebugLaunch:
	return parse(OS.get_cmdline_user_args(), {
		ENV_FIGHT: OS.get_environment(ENV_FIGHT),
		ENV_CHARACTER: OS.get_environment(ENV_CHARACTER),
		ENV_HP: OS.get_environment(ENV_HP),
		ENV_SCREEN: OS.get_environment(ENV_SCREEN),
		ENV_GOLD: OS.get_environment(ENV_GOLD),
	})


static func parse(args: PackedStringArray, env := {}) -> DebugLaunch:
	var launch := DebugLaunch.new()
	var fight_text := String(env.get(ENV_FIGHT, ""))
	var character_text := String(env.get(ENV_CHARACTER, ""))
	var hp_text := String(env.get(ENV_HP, ""))
	var screen_text := String(env.get(ENV_SCREEN, ""))
	var gold_text := String(env.get(ENV_GOLD, ""))
	for arg in args:
		if arg.begins_with("--fight="):
			fight_text = arg.trim_prefix("--fight=")
		elif arg.begins_with("--character="):
			character_text = arg.trim_prefix("--character=")
		elif arg.begins_with("--screen="):
			screen_text = arg.trim_prefix("--screen=")
		elif arg.begins_with("--gold="):
			gold_text = arg.trim_prefix("--gold=")
		elif arg.begins_with("--hp="):
			hp_text = arg.trim_prefix("--hp=")
	var wants_fight := fight_text.strip_edges() != ""
	var wants_screen := screen_text.strip_edges() != ""
	if not wants_fight and not wants_screen:
		return launch
	launch.requested = true
	if wants_fight and wants_screen:
		launch.error = "Use either --fight or --screen, not both."
		return launch
	if wants_fight:
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
	else:
		# "vendor", "rest", or "vendor:2" for the second one on the line.
		var parts := screen_text.strip_edges().to_lower().split(":")
		if not SCREENS.has(parts[0]) or parts.size() > 2 or (parts.size() == 2 and (not parts[1].is_valid_int() or int(parts[1]) < 1)):
			launch.error = "Unknown screen '%s'. Choose from: %s (add :2 for the second one)." % [screen_text.strip_edges(), ", ".join(SCREENS.keys())]
			return launch
		launch.screen = parts[0]
		launch.screen_index = int(parts[1]) if parts.size() == 2 else 1
		if launch.screen_index > screen_count(launch.screen):
			launch.error = "The line has only %d %s stop(s)." % [screen_count(launch.screen), launch.screen]
			return launch
	if gold_text.strip_edges() != "":
		if not gold_text.strip_edges().is_valid_int() or int(gold_text) < 0:
			launch.error = "--gold must be a whole number, 0 or more."
			return launch
		launch.gold = int(gold_text)
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


## How many stops of this screen the default line has (a RunState builds the line, so this stays true
## if the line changes).
static func screen_count(screen_name: String) -> int:
	var count := 0
	var run_state := RunState.new(0, StarterContent.DEFAULT_CHARACTER_ID)
	for stop in run_state.stops:
		if stop.type == SCREENS[screen_name]:
			count += 1
	return count

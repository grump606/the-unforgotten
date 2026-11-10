class_name DestinationArt
extends RefCounted
## Presentation lookups by stop index. The data (destination name, battle backdrop) lives on each Stop of the
## line (RunState._default_line), so reordering the route moves the art with it; these are thin lookups for
## callers that only have an index. Stop objects, save signatures and RNG are unchanged.

## The place of a map fight whose backdrop has no name of its own (the character's and the neutral one).
const UNMARKED_FIGHT_PLACE := "A Forgotten Road"

static var _line: Array[RunState.Stop] = []


static func _stop(index: int) -> RunState.Stop:
	if _line.is_empty():
		_line = RunState._default_line()
	return _line[index] if index >= 0 and index < _line.size() else null


## The destination's name at a stop index, "" outside the line.
static func label_at(index: int) -> String:
	var stop := _stop(index)
	return stop.label if stop != null else ""


## Map mode: the place name for a stop built from a map node. Fights are named by their backdrop key
## (the character and neutral keys share UNMARKED_FIGHT_PLACE), the rest by their kind.
static func label_for_stop(stop: RunState.Stop) -> String:
	match stop.type:
		RunState.StopType.REST:
			return "Candlehouse"
		RunState.StopType.VENDOR:
			return "The Lost-Property Stall"
		RunState.StopType.TREASURE:
			return "The Sealed Strongbox"
		RunState.StopType.EVENT:
			return "A Place Along the Way"
		RunState.StopType.STORY:
			# Named like the same story beat on the line, wherever that beat sits in it.
			if _line.is_empty():
				_line = RunState._default_line()
			for line_stop in _line:
				if line_stop.type == RunState.StopType.STORY and line_stop.beat_index == stop.beat_index:
					return line_stop.label
			return ""
	match stop.backdrop:
		&"battle_street": return "Drowned Street"
		&"battle_garden": return "Processional Garden"
		&"battle_archive": return "The Name Vault"
		&"battle_bell_court": return "The Bell Court"
		&"battle_threshold": return "The Threshold"
	# The character and neutral backdrops have no place of their own: a fight there still gets a place, so every
	# fight header reads "<place> — Combat (n enemies)".
	if stop.type == RunState.StopType.COMBAT and stop.backdrop != &"":
		return UNMARKED_FIGHT_PLACE
	return ""

## The painted battle backdrop key at a stop index, &"" for the default art or outside the line.
static func battle_key(index: int) -> StringName:
	var stop := _stop(index)
	return stop.backdrop if stop != null else &""

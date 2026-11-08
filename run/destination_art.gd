class_name DestinationArt
extends RefCounted
## Presentation lookups by stop index. The data (destination name, battle backdrop) lives on each Stop of the
## line (RunState._default_line), so reordering the route moves the art with it; these are thin lookups for
## callers that only have an index. Stop objects, save signatures and RNG are unchanged.

static var _line: Array[RunState.Stop] = []


static func _stop(index: int) -> RunState.Stop:
	if _line.is_empty():
		_line = RunState._default_line()
	return _line[index] if index >= 0 and index < _line.size() else null


## The destination's name at a stop index, "" outside the line.
static func label_at(index: int) -> String:
	var stop := _stop(index)
	return stop.label if stop != null else ""


## The painted battle backdrop key at a stop index, &"" for the default art or outside the line.
static func battle_key(index: int) -> StringName:
	var stop := _stop(index)
	return stop.backdrop if stop != null else &""

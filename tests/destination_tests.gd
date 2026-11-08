extends "res://tests/test_base.gd"
## Pins every destination label and battle backdrop of the 22-stop line, and that they live on the Stop
## objects (DestinationArt is only a lookup). Registered by run_tests.gd.

const LABELS := [
	"Shore of Names", "Drowned Street", "Laundry Court", "Lampkeeper's Kitchen",
	"Empty Tenements", "The Lost-Property Stall", "Petition Steps", "The Unanswered Hall",
	"Caretaker's Alcove", "The Bell Court", "Garden of Unmarked Stones", "Glasshouse Shelter",
	"Processional Garden", "The Listening Marsh", "The Bone Orchard Market", "Candlehouse",
	"The Name Vault", "The Unwritten Causeway", "Last Keepsake Stall", "The Last Hearth", "The Breathing Door", "The Threshold",
]
const BACKDROPS := {
	1: &"battle_street", 2: &"battle_street", 4: &"battle_street", 6: &"battle_street",
	9: &"battle_bell_court", 12: &"battle_garden", 13: &"battle_garden",
	16: &"battle_archive", 17: &"battle_archive", 21: &"battle_threshold",
}


func run() -> int:
	_failures = 0
	var state := RunState.new(1)
	_check(state.stops.size() == LABELS.size(), "the line has %d stops" % LABELS.size())
	for i in state.stops.size():
		var expected_key: StringName = BACKDROPS.get(i, &"")
		_check(state.stops[i].label == LABELS[i], "stop %d carries its label" % i)
		_check(state.stops[i].backdrop == expected_key, "stop %d carries its backdrop" % i)
		_check(DestinationArt.label_at(i) == LABELS[i], "label_at(%d)" % i)
		_check(DestinationArt.battle_key(i) == expected_key, "battle_key(%d)" % i)
		_check(state.stops[i].ambience == (&"coastal" if i == 0 else &""), "stop %d ambience" % i)
	_check(DestinationArt.label_at(-1) == "" and DestinationArt.label_at(22) == "", "label_at is empty outside the line")
	_check(DestinationArt.battle_key(-1) == &"" and DestinationArt.battle_key(22) == &"", "battle_key is empty outside the line")
	return _failures



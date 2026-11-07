class_name DestinationArt
extends RefCounted
## Presentation metadata only; stop objects, save signatures and RNG are unchanged.
const LABELS := [
	"Shore of Names", "Drowned Street", "Laundry Court", "Lampkeeper's Kitchen",
	"Empty Tenements", "The Lost-Property Stall", "Petition Steps", "The Unanswered Hall",
	"Caretaker's Alcove", "The Bell Court", "Garden of Unmarked Stones", "Glasshouse Shelter",
	"Processional Garden", "The Listening Marsh", "The Bone Orchard Market", "Candlehouse",
	"The Name Vault", "The Unwritten Causeway", "Last Keepsake Stall", "The Breathing Door", "The Threshold",
]

## The place of a map fight whose backdrop has no name of its own (the character's and the neutral one).
const UNMARKED_FIGHT_PLACE := "A Forgotten Road"

static func label_at(index: int) -> String:
	return LABELS[index] if index >= 0 and index < LABELS.size() else ""

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
			var beat_labels := {0: 0, 1: 7, 2: 10, 3: 19}
			return label_at(beat_labels.get(stop.beat_index, -1))
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

static func battle_key(index: int) -> StringName:
	match index:
		1, 2, 4, 6: return &"battle_street"
		9: return &"battle_bell_court"
		12, 13: return &"battle_garden"
		16, 17: return &"battle_archive"
		20: return &"battle_threshold"
	return &""

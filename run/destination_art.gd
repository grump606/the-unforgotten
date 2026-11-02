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

static func label_at(index: int) -> String:
	return LABELS[index] if index >= 0 and index < LABELS.size() else ""

static func battle_key(index: int) -> StringName:
	match index:
		1, 2, 4, 6: return &"battle_street"
		9: return &"battle_bell_court"
		12, 13: return &"battle_garden"
		16, 17: return &"battle_archive"
		20: return &"battle_threshold"
	return &""

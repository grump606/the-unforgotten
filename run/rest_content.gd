class_name RestContent
extends RefCounted
## The short story card shown at a rest stop: it continues the voice from the opening beat
## ("A Voice Beyond the Rain"). The line has four rests; each has a title, a passage everyone
## reads and one closing line per character. `beat(rest_number, character_id)` returns a
## StoryBeat, so the rest screen can show it like any other story passage.

const BUTTON := "Follow the voice"

## Per rest (in line order): title, passage, and a closing line per character id.
const BEATS: Array[Dictionary] = [
	{
		"title": "Somewhere to Stop",
		"text": "A low fire burns in a room no one seems to own. Beyond the walls the voice calls again, softer, waiting for you to rest.",
		"deserter": "You have kept watch in worse places. Tonight someone else's fire keeps it.",
		"thief": "You check the door twice, pocket nothing, and sit down.",
		"medium": "The firelight moves like a breath. Even the quiet here is kind.",
	},
	{
		"title": "The Warmth Remains",
		"text": "Past the sealed hall the fire still burns, and its warmth makes you whole. The voice is closer now, saying only the shape of your name.",
		"deserter": "A barracks fire, and a voice that once called you off watch. Almost the same voice.",
		"thief": "The key warms in your hand. It fits no lock here, and you keep it anyway.",
		"medium": "The dead nearby lean toward the light. You nod, and they nod back.",
	},
	{
		"title": "Quiet Between the Gardens",
		"text": "Among the unmarked stones one fire is still lit. The voice no longer calls. It sounds like someone who has waited up.",
		"deserter": "Someone once waited up for you, before you gave them reason to stop.",
		"thief": "You almost remember a window left lit. You were always outside it.",
		"medium": "Under the voice you hear a chair creak, a kettle. Home has a sound.",
	},
	{
		"title": "Before the Door",
		"text": "One last fire before the breathing door. The voice is near enough to answer, and you do not yet know what you will say.",
		"deserter": "You rehearsed it for years: sorry, and then the rest. You will say it anyway.",
		"thief": "There is a name scratched inside the key's bow. You can almost read it.",
		"medium": "You have heard the dead say goodbye a thousand times. Now one of them is you.",
	},
]


static func beat_count() -> int:
	return BEATS.size()


## The card for the `rest_number`th rest of the line (1 for the first; out-of-range numbers use the
## nearest one). A character without its own closing line gets the shared passage alone.
static func beat(rest_number: int, character_id: StringName = &"") -> StoryBeat:
	var entry := BEATS[clampi(rest_number - 1, 0, BEATS.size() - 1)]
	var result := StoryBeat.new()
	result.title = entry["title"]
	result.text = entry["text"]
	var own: String = entry.get(String(character_id), "")
	if own != "":
		result.text += "\n" + own
	result.button_text = BUTTON
	return result

class_name StoryContent
extends RefCounted
## Loader for the story beats under res://data/story/. Beats are indexed in
## train order; RunState's STORY stops refer to them by index. Characters can
## override a beat (see beat()); the neutral files are the fallback.

const BEAT_PATHS: Array[String] = [
	"res://data/story/boarding.tres",
	"res://data/story/conductor.tres",
	"res://data/story/empty_platform.tres",
	"res://data/story/last_light.tres",
]


## The beat files of a chapter other than the first, by chapter number: the story rows of its map (RouteMap.STORY_LOCAL_ROWS) read
## beat `beat_index` of this list. A chapter without an entry plays Chapter 1's beats. Per-class versions sit beside them in
## data/story/<class>/ under the same file name, as for Chapter 1.
const CHAPTER_BEAT_PATHS := {
	2: [
		"res://data/story/chapter2/registry_arrival.tres",
		"res://data/story/chapter2/archivists_hall.tres",
		"res://data/story/chapter2/reading_room.tres",
		"res://data/story/chapter2/registrars_desk.tres",
	],
	3: [
		"res://data/story/chapter3/dry_stair.tres",
		"res://data/story/chapter3/blotters_alcove.tres",
		"res://data/story/chapter3/the_margin.tres",
		"res://data/story/chapter3/wardens_door.tres",
	],
}
## The closing beat of a chapter, shown on its break screen (key: the chapter that has just ended). The break after Chapter 1 is what
## drops the book and opens the Registry; the one after Chapter 2 opens Chapter 3. Class versions sit beside the others by file name.
const BREAK_BEAT_PATHS := {
	1: "res://data/story/chapter1/dropped_book.tres",
	2: "res://data/story/chapter2/last_entry.tres",
	3: "res://data/story/chapter3/foot_of_the_page.tres",
}
## The finale's two texts (key: the chapter whose end boss it follows): "before" shows on the break that leads to the finale, "after" on the end card
## of an escape. Class versions sit beside them by file name, as for the closing beats.
const FINALE_BEAT_PATHS := {
	3: {
		"before": "res://data/story/chapter3/last_name.tres",
		"after": "res://data/story/chapter3/door_that_opens.tres",
	},
}


## The beat files of chapter `chapter`.
static func paths_for(chapter: int) -> Array[String]:
	var own: Array = CHAPTER_BEAT_PATHS.get(chapter, [])
	if chapter <= 1 or own.is_empty():
		return BEAT_PATHS
	var typed: Array[String] = []
	typed.assign(own)
	return typed


static func beat_count(chapter: int = 1) -> int:
	return paths_for(chapter).size()


## Returns null (after logging an error) if the index is out of range or the
## resource is missing or not a StoryBeat. A character's own version of the beat
## (same file name under res://data/story/<character id>/) wins when it exists.
static func beat(index: int, character_id: StringName = &"", chapter: int = 1) -> StoryBeat:
	var paths := paths_for(chapter)
	if index < 0 or index >= paths.size():
		push_error("StoryContent.beat: no beat at index %d" % index)
		return null
	var path := paths[index]
	if character_id != &"":
		var own_path := "res://data/story/%s/%s" % [character_id, path.get_file()]
		if ResourceLoader.exists(own_path):
			path = own_path
	var loaded: StoryBeat = null
	if ResourceLoader.exists(path):
		loaded = load(path) as StoryBeat
	if loaded == null:
		push_error("StoryContent: missing or non-StoryBeat resource: %s" % path)
	return loaded


## The closing beat of chapter `chapter` for `character_id`, or null when that chapter has none (a class's own version wins).
static func break_beat(chapter: int, character_id: StringName = &"") -> StoryBeat:
	if not BREAK_BEAT_PATHS.has(chapter):
		return null
	return _load_beat(BREAK_BEAT_PATHS[chapter], character_id)


## The finale text `which` ("before" or "after") of chapter `chapter` for `character_id`, or null when that chapter has no finale.
static func finale_beat(chapter: int, which: String, character_id: StringName = &"") -> StoryBeat:
	var own: Dictionary = FINALE_BEAT_PATHS.get(chapter, {})
	if not own.has(which):
		return null
	return _load_beat(own[which], character_id)


static func _load_beat(path: String, character_id: StringName) -> StoryBeat:
	if character_id != &"":
		var own_path := "res://data/story/%s/%s" % [character_id, path.get_file()]
		if ResourceLoader.exists(own_path):
			path = own_path
	var loaded: StoryBeat = null
	if ResourceLoader.exists(path):
		loaded = load(path) as StoryBeat
	if loaded == null:
		push_error("StoryContent: missing or non-StoryBeat resource: %s" % path)
	return loaded

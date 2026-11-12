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
const CHAPTER_BEAT_PATHS := {}


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

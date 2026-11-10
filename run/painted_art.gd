class_name PaintedArt
extends RefCounted
## Loads the painted art kit (res://art/layers) for cards and enemy portraits, with mipmaps so the
## large source images downscale cleanly. Everything is optional: a missing file returns null / an
## empty array and the caller falls back to the code-drawn picture.

const CARD_DIR := "res://art/layers/cards/%s/art.png"
const ENEMY_DIR := "res://art/layers/%s/%s.png"
## An elite enemy's art: the regular sprite with a painted flame aura behind it, `sprite_elite.png`, on a larger canvas.
## ELITE_PADS gives, per art key, the pixels the canvas adds around the regular sprite: left and right (x), above (y) and
## below (z). The sprite itself is unchanged and sits at the same place in the canvas, so the game scales both alike.
const ELITE_PADS := {
	&"warden": Vector3i(160, 220, 80), &"shade": Vector3i(184, 220, 80), &"wisp": Vector3i(275, 220, 80),
	&"colossus": Vector3i(246, 220, 80), &"whisperer": Vector3i(142, 220, 80),
	&"hound": Vector3i(304, 165, 60), &"crow": Vector3i(248, 165, 60),
}
const PLAYER_DIR := "res://art/layers/players/%s/figure.png"
const SCREEN_DIR := "res://art/layers/screens/%s/bg.png"

static var _cache := {}
## Stops entered so far, and the stop each cache key was last used in; entries unused for EVICT_AFTER_STOPS
## stops are dropped by advance_stop() (a screen that needs one again simply decodes it again).
static var _stop_serial := 0
static var _last_used := {}
## Painted-pixel box of each decoded image, measured on the decoded Image when it is stored, so showing a
## figure never reads a texture back from the GPU.
static var _used_rects := {}
const EVICT_AFTER_STOPS := 2


## Marks a cache key as used in the current stop.
static func _touch(key: String) -> void:
	_last_used[key] = _stop_serial


## Call once per stop entered: drops every cache entry not used during the last EVICT_AFTER_STOPS stops.
## Returns how many entries were dropped.
static func advance_stop() -> int:
	_stop_serial += 1
	var stale: Array = []
	for key in _cache:
		if _stop_serial - int(_last_used.get(key, 0)) >= EVICT_AFTER_STOPS:
			stale.append(key)
	for key in stale:
		_cache.erase(key)
		_last_used.erase(key)
		_used_rects.erase(key)
	return stale.size()


static func card_texture(card_id: StringName) -> Texture2D:
	return _load(CARD_DIR % card_id)


## The enemy's figure layer and the tight box around its painted pixels, as {tex, region}, or {} when
## there is no painted figure. The battle stage draws the figure alone (no backdrop or fog layers).
static func enemy_figure(key: StringName) -> Dictionary:
	var ck := "figure:" + String(key)
	if _cache.has(ck):
		_touch(ck)
		return _cache[ck]
	_touch(ck)
	var out := {}
	var sprite := _load(ENEMY_DIR % [key, "sprite"])
	if sprite != null:
		out = {"tex": sprite, "region": Rect2(Vector2.ZERO, sprite.get_size()), "sprite": true}
		_cache[ck] = out
		return out
	var tex := _load(ENEMY_DIR % [key, "figure"])
	if tex != null:
		var used: Rect2i = _used_rects.get(ENEMY_DIR % [key, "figure"], Rect2i())
		if used.size.x > 0 and used.size.y > 0:
			out = {"tex": tex, "region": Rect2(used)}
	_cache[ck] = out
	return out


## The elite version of an enemy's sprite as {tex, pads} (see ELITE_PADS), or {} when the enemy has no elite art or no
## plain sprite to match it to.
static func enemy_elite_figure(key: StringName) -> Dictionary:
	if not ELITE_PADS.has(key):
		return {}
	var ck := "elite:" + String(key)
	if _cache.has(ck):
		_touch(ck)
		return _cache[ck]
	_touch(ck)
	var out := {}
	var tex := _load(ENEMY_DIR % [key, "sprite_elite"])
	var plain := _load(ENEMY_DIR % [key, "sprite"])
	if tex != null and plain != null:
		var pads: Vector3i = ELITE_PADS[key]
		var expected := plain.get_size() + Vector2(pads.x * 2, pads.y + pads.z)
		if tex.get_size() == expected:
			out = {"tex": tex, "pads": pads}
	_cache[ck] = out
	return out


## The player class figure (art/layers/players/<id>/figure.png) and its painted-pixel box, as {tex, region}, or {}.
static func player_figure(id: StringName) -> Dictionary:
	var ck := "player:" + String(id)
	if _cache.has(ck):
		_touch(ck)
		return _cache[ck]
	_touch(ck)
	var out := {}
	var tex := _load(PLAYER_DIR % id)
	if tex != null:
		out = {"tex": tex, "region": Rect2(Vector2.ZERO, tex.get_size())}
	_cache[ck] = out
	return out


## The vendor shopkeeper (art/layers/screens/vendor/keeper.png) and the box around its painted pixels,
## as {tex, region}, or {} when the file is missing (the stall then draws its code-drawn keeper).
static func keeper_figure() -> Dictionary:
	if _cache.has("keeper"):
		_touch("keeper")
		return _cache["keeper"]
	_touch("keeper")
	var out := {}
	var tex := _load("res://art/layers/screens/vendor/keeper.png")
	if tex != null:
		var used: Rect2i = _used_rects.get("res://art/layers/screens/vendor/keeper.png", Rect2i())
		if used.size.x > 0 and used.size.y > 0:
			out = {"tex": tex, "region": Rect2(used)}
	_cache["keeper"] = out
	return out


## A full-window painted background (art/layers/screens/<name>/bg.png), or null.
static func screen_texture(screen_name: StringName) -> Texture2D:
	return _load(SCREEN_DIR % screen_name)


## Draws `tex` covering `rect` (keeping its aspect, cropping the overflow), zoomed in by `zoom` and
## panned by `pan` (-1..1 on each axis, spending the spare picture the zoom leaves) on canvas item `ci`.
static func draw_cover(ci: CanvasItem, tex: Texture2D, rect: Rect2, zoom := 1.0, pan := Vector2.ZERO, tint := Color.WHITE) -> void:
	var ts := tex.get_size()
	var src := ts
	if ts.x / ts.y > rect.size.x / rect.size.y:
		src.x = ts.y * rect.size.x / rect.size.y
	else:
		src.y = ts.x * rect.size.y / rect.size.x
	src /= maxf(zoom, 1.0)
	var spare := (ts - src) * 0.5
	var origin := spare + spare * pan.clamp(Vector2(-1, -1), Vector2(1, 1))
	ci.draw_texture_rect_region(tex, rect, Rect2(origin, src), tint)


## The art files the screen after a run stop will draw (`stop_type` is a RunState.StopType value; `character_id` picks the class backdrops and `story_beat`, a STORY stop's beat_index or -1, its own window painting).
static func paths_for_stop(stop_type: int, character_id: StringName = &"", story_beat := -1) -> Array[String]:
	var names: Array[StringName] = []
	var extra: Array[String] = []
	match stop_type:
		RunState.StopType.COMBAT:
			names.append(StringName("battle_" + String(character_id)) if character_id != &"" else &"battle_neutral")
			names.append(&"battle_neutral")
			names.append(&"battle_boss")
		RunState.StopType.REST:
			names.append(StringName("rest_" + String(character_id)) if character_id != &"" else &"rest")
			names.append(&"rest")
		RunState.StopType.STORY:
			if story_beat >= 0:
				names.append(StoryScene.key_for_beat(story_beat))
		RunState.StopType.VENDOR:
			names.append(&"vendor")
			extra.append("res://art/layers/screens/vendor/keeper.png")
		RunState.StopType.TREASURE:
			names.append(&"battle_archive")
		RunState.StopType.EVENT:
			names.append(&"battle_street")
			names.append(&"battle_archive")
	var out: Array[String] = []
	for screen_name in names:
		out.append(SCREEN_DIR % screen_name)
	out.append_array(extra)
	return out


# --- spreading the warm-up over frames ------------------------------------------------------------------
# Decoding a ~3 MB screen takes long enough to hitch a frame, so the run queues the next stop's art and pumps the
# queue a little each frame from its _process. Still all on the main thread (Texture2D.get_image() goes through the RenderingServer, and decoding the same art from a worker thread and the main thread at once crashed intermittently); a draw that needs a
# queued path simply decodes it at once through _load, and the pump then skips it.

## Most milliseconds one pump() call keeps decoding after its first file.
const PUMP_BUDGET_MS := 4.0
## Paths waiting to be decoded, in order (duplicates and already cached paths are skipped when queued or pumped).
static var _queue: Array[String] = []


## Queues the art for a run stop's next screen instead of decoding it now (the paths of paths_for_stop).
static func queue_for_stop(stop_type: int, character_id: StringName = &"", story_beat := -1) -> void:
	queue_paths(paths_for_stop(stop_type, character_id, story_beat))


## Queues a screen background (art/layers/screens/<name>/bg.png).
static func queue_screen(screen_name: StringName) -> void:
	queue_paths([SCREEN_DIR % screen_name])


## Queues res:// paths to decode later; ones already queued are ignored. One already cached is not decoded again
## but is marked as used in the current stop, so advance_stop() cannot evict it before its screen draws.
static func queue_paths(paths: Array) -> void:
	for path in paths:
		var key := String(path)
		if _cache.has(key):
			_touch(key)
		elif not _queue.has(key):
			_queue.append(key)


## How many queued paths are still waiting.
static func pending() -> int:
	return _queue.size()


## Decodes queued paths until `budget_ms` has passed (always at least one, if any is waiting) and returns how many
## remain. Call once per frame; the first file already takes most of a frame, so in practice this is one per frame.
static func pump(budget_ms := PUMP_BUDGET_MS) -> int:
	var started := Time.get_ticks_usec()
	while not _queue.is_empty():
		var path: String = _queue.pop_front()
		if not _cache.has(path):
			_load(path)
		if (Time.get_ticks_usec() - started) / 1000.0 >= budget_ms:
			break
	return _queue.size()


## Any texture under res:// through the shared cache (mipmapped), or null when it is missing.
static func texture(path: String) -> Texture2D:
	return _load(path)


static func _load(path: String) -> Texture2D:
	_touch(path)
	if _cache.has(path):
		return _cache[path]
	return _store(path, _decode(path))


## Reads, decompresses and mipmaps an image off disk (main thread only, see the queue below).
static func _decode(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	# CACHE_MODE_IGNORE: the imported (compressed) texture is not kept by the loader's cache, so
	# only the mipmapped ImageTexture made in _store stays resident once `src` and `img` go out of scope.
	var src := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	if src == null:
		return null
	var img := src.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.generate_mipmaps()
	return img


## Makes the texture from a decoded image and caches it; a missing file caches null.
static func _store(path: String, img: Image) -> Texture2D:
	var tex: Texture2D = ImageTexture.create_from_image(img) if img != null else null
	if img != null:
		_used_rects[path] = img.get_used_rect()
	_cache[path] = tex
	return tex



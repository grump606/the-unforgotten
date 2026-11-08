class_name PaintedArt
extends RefCounted
## Loads the painted art kit (res://art/layers) for cards and enemy portraits, with mipmaps so the
## large source images downscale cleanly. Everything is optional: a missing file returns null / an
## empty array and the caller falls back to the code-drawn picture.

const CARD_DIR := "res://art/layers/cards/%s/art.png"
const ENEMY_DIR := "res://art/layers/%s/%s.png"
const PLAYER_DIR := "res://art/layers/players/%s/figure.png"
const SCREEN_DIR := "res://art/layers/screens/%s/bg.png"
## Back to front, with how far each layer shifts in the idle sway (the old enemy portrait sway).
const ENEMY_LAYERS: Array[StringName] = [&"bg", &"mid", &"figure", &"fg"]
const ENEMY_DEPTHS := [0.1, 0.4, 0.8, 1.6]

static var _cache := {}
## Paths being decoded on a worker thread: path -> {"task": id, "image": Image or null}.
static var _pending := {}
## Stops entered so far, and the stop each cache key was last used in; entries unused for EVICT_AFTER_STOPS
## stops are dropped by advance_stop() (a screen that needs one again simply decodes it again).
static var _stop_serial := 0
static var _last_used := {}
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
	return stale.size()


static func card_texture(card_id: StringName) -> Texture2D:
	return _load(CARD_DIR % card_id)


## The four layer textures for an enemy art key, or [] when the set is incomplete.
static func enemy_layers(key: StringName) -> Array:
	var ck := "enemy:" + String(key)
	if _cache.has(ck):
		_touch(ck)
		return _cache[ck]
	_touch(ck)
	var layers: Array = []
	for layer in ENEMY_LAYERS:
		var tex := _load(ENEMY_DIR % [key, layer])
		if tex == null:
			layers = []
			break
		layers.append(tex)
	_cache[ck] = layers
	return layers


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
		var img := tex.get_image()
		var used := img.get_used_rect() if img != null else Rect2i()
		if used.size.x > 0 and used.size.y > 0:
			out = {"tex": tex, "region": Rect2(used)}
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
		var img := tex.get_image()
		var used := img.get_used_rect() if img != null else Rect2i()
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


## Warms the cache for a screen background (art/layers/screens/<name>/bg.png) so its first draw does
## not decode and mipmap it on the main thread.
static func preload_screen(screen_name: StringName) -> void:
	_load(SCREEN_DIR % screen_name)


## Warms the cache for each res:// path in `paths` (missing files cache as null, like _load).
static func preload_paths(paths: Array) -> void:
	for path in paths:
		_load(String(path))


## Like preload_screen, but the decode runs on a worker thread; the texture is made later by poll() (or at once
## by the first draw that asks for it). Nothing happens for a path that is already cached or being decoded.
static func warm_screen_async(screen_name: StringName) -> void:
	warm_path_async(SCREEN_DIR % screen_name)


static func warm_path_async(path: String) -> void:
	if _cache.has(path) or _pending.has(path) or not ResourceLoader.exists(path):
		return
	var holder := {"image": null}
	holder["task"] = WorkerThreadPool.add_task(_decode_in_thread.bind(path, holder), false, "PaintedArt " + path.get_file())
	_pending[path] = holder


## True while any warm-up is still decoding or waiting for poll().
static func has_pending() -> bool:
	return not _pending.is_empty()


## Turns every finished worker-thread decode into a cached texture (cheap; the upload happens here on the main
## thread). Returns how many are still decoding.
static func poll() -> int:
	for path in _pending.keys():
		if WorkerThreadPool.is_task_completed(_pending[path].task):
			_finish_pending(path)
	return _pending.size()


## Warms what the screen after a run stop will draw. `stop_type` is a RunState.StopType value; `character_id`
## picks the class backdrops and `story_beat` (a STORY stop's beat_index, else -1) its own window painting. Call it
## when the previous screen is shown, so the decode cost is paid off the main thread before the player moves on.
static func warm_for_stop(stop_type: int, character_id: StringName = &"", story_beat := -1) -> void:
	match stop_type:
		RunState.StopType.COMBAT:
			warm_screen_async(StringName("battle_" + String(character_id)) if character_id != &"" else &"battle_neutral")
			warm_screen_async(&"battle_neutral")
			warm_screen_async(&"battle_boss")
		RunState.StopType.REST:
			warm_screen_async(StringName("rest_" + String(character_id)) if character_id != &"" else &"rest")
			warm_screen_async(&"rest")
		RunState.StopType.STORY:
			if story_beat >= 0:
				warm_screen_async(StoryScene.key_for_beat(story_beat))
		RunState.StopType.VENDOR:
			warm_screen_async(&"vendor")
			warm_path_async("res://art/layers/screens/vendor/keeper.png")


## Any texture under res:// through the shared cache (mipmapped), or null when it is missing.
static func texture(path: String) -> Texture2D:
	return _load(path)


static func _load(path: String) -> Texture2D:
	_touch(path)
	if _cache.has(path):
		return _cache[path]
	if _pending.has(path):
		if WorkerThreadPool.is_task_completed(_pending[path].task):
			_finish_pending(path)
			return _cache[path]
		# Still decoding: never block the main thread on the worker (the worker's resource load can need
		# the main thread). Decode here instead; poll() discards the worker's copy when it finishes.
	var img := _decode(path)
	return _store(path, img)


## Reads, decompresses and mipmaps an image off disk. Touches no scene state, so it may run on any thread.
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


static func _decode_in_thread(path: String, holder: Dictionary) -> void:
	holder["image"] = _decode(path)


## Makes the texture from a decoded image (main thread) and caches it; a missing file caches null.
static func _store(path: String, img: Image) -> Texture2D:
	var tex: Texture2D = ImageTexture.create_from_image(img) if img != null else null
	_cache[path] = tex
	return tex


static func _finish_pending(path: String) -> void:
	var holder: Dictionary = _pending[path]
	_pending.erase(path)
	WorkerThreadPool.wait_for_task_completion(holder.task) # only called once the task is complete
	if not _cache.has(path):
		_touch(path)
		_store(path, holder.image)

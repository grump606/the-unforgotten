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


static func card_texture(card_id: StringName) -> Texture2D:
	return _load(CARD_DIR % card_id)


## The four layer textures for an enemy art key, or [] when the set is incomplete.
static func enemy_layers(key: StringName) -> Array:
	var ck := "enemy:" + String(key)
	if _cache.has(ck):
		return _cache[ck]
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
		return _cache[ck]
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
		return _cache[ck]
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
		return _cache["keeper"]
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


## Warms what the screen after a run stop will draw. `stop_type` is a RunState.StopType value (an int
## here so this helper has no dependency on the run); `character_id` picks the class battle backdrop.
## Call it when the previous screen is shown, e.g. when the map arrives at a stop, so the decode cost
## is paid before the player moves on instead of as a stutter on the next screen.
static func warm_for_stop(stop_type: int, character_id: StringName = &"") -> void:
	match stop_type:
		0: # RunState.StopType.COMBAT
			preload_screen(StringName("battle_" + String(character_id)) if character_id != &"" else &"battle_neutral")
			preload_screen(&"battle_neutral")
			preload_screen(&"battle_boss")
		1: # REST
			preload_screen(&"rest")
		2: # STORY
			for dir in DirAccess.get_directories_at("res://art/layers/screens"):
				if dir.begins_with("story_"):
					preload_screen(StringName(dir))
		3: # VENDOR
			preload_screen(&"vendor")
			preload_paths(["res://art/layers/screens/vendor/keeper.png"])


## Any texture under res:// through the shared cache (mipmapped), or null when it is missing.
static func texture(path: String) -> Texture2D:
	return _load(path)


static func _load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		# CACHE_MODE_IGNORE: the imported (compressed) texture is not kept by the loader's cache, so
		# only the mipmapped ImageTexture below stays resident once `src` and `img` go out of scope.
		var src := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		if src != null:
			var img := src.get_image()
			src = null
			if img != null:
				if img.is_compressed():
					img.decompress()
				img.generate_mipmaps()
				tex = ImageTexture.create_from_image(img)
				img = null # the texture owns its own copy; do not hold the full-size image
	_cache[path] = tex
	return tex

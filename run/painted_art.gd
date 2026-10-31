class_name PaintedArt
extends RefCounted
## Loads the painted art kit (res://art/layers) for cards and enemy portraits, with mipmaps so the
## large source images downscale cleanly. Everything is optional: a missing file returns null / an
## empty array and the caller falls back to the code-drawn picture.

const CARD_DIR := "res://art/layers/cards/%s/art.png"
const ENEMY_DIR := "res://art/layers/%s/%s.png"
## Back to front, with how far each layer shifts in the idle sway (see EnemyView).
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


static func _load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var src := load(path) as Texture2D
		if src != null:
			var img := src.get_image()
			if img != null:
				if img.is_compressed():
					img.decompress()
				img.generate_mipmaps()
				tex = ImageTexture.create_from_image(img)
	_cache[path] = tex
	return tex

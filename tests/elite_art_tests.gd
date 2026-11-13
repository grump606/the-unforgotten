extends "res://tests/test_base.gd"
## Elite enemy art (PaintedArt.ELITE_PADS, art/layers/<key>/sprite_elite.png): every enemy with a plain sprite has an elite
## sprite on the padded canvas, a Fighter uses it only for an elite (never for a regular enemy or a boss), keeps the feet
## where they were, and falls back to the plain sprite without it.


func run() -> int:
	_failures = 0
	_every_sprite_has_its_elite()
	_fighter_uses_it_for_elites_only()
	_no_elite_art_falls_back()
	return _failures


func _every_sprite_has_its_elite() -> void:
	for key: StringName in Fighter.ART_KEYS.values():
		var plain := PaintedArt.enemy_figure(key)
		if plain.is_empty() or not plain.get("sprite", false):
			continue
		if key == &"conductor" or key == &"brakeman" or key == &"the_archivist" or key == &"the_registrar":
			continue # bosses are never elites
		var elite := PaintedArt.enemy_elite_figure(key)
		_check(not elite.is_empty(), "%s: an elite sprite is there and matches its padded size" % key)
		if elite.is_empty():
			continue
		var pads: Vector3i = elite.pads
		var tex: Texture2D = elite.tex
		var plain_size: Vector2 = plain.tex.get_size()
		_check(tex.get_size() == plain_size + Vector2(pads.x * 2, pads.y + pads.z), "%s: the canvas is the sprite plus its pads" % key)
		# The sprite sits unchanged inside the canvas: its opaque pixels are where the plain sprite's are.
		var canvas: Image = tex.get_image()
		var base: Image = plain.tex.get_image()
		var same := 0
		var checked := 0
		for y in range(0, base.get_height(), 60):
			for x in range(0, base.get_width(), 60):
				var b := base.get_pixel(x, y)
				if b.a >= 0.99: # (near) opaque pixels only: they blend with the aura by under 1% (softer edge pixels blend more)
					checked += 1
					var c := canvas.get_pixel(x + pads.x, y + pads.y)
					if absf(c.r - b.r) < 0.02 and absf(c.g - b.g) < 0.02 and absf(c.b - b.b) < 0.02:
						same += 1
		_check(checked > 5 and same == checked, "%s: the original sprite is unchanged inside the elite canvas (%d of %d samples)" % [key, same, checked])


func _fighter_uses_it_for_elites_only() -> void:
	var data := StarterContent.enemy_by_id(&"gate_warden")
	var regular := Fighter.new()
	regular.set_enemy(EnemyUnit.new(data), false, false)
	_check(regular._elite_tex == null, "a regular enemy draws the plain sprite")
	var elite := Fighter.new()
	elite.set_enemy(EnemyUnit.new(StarterContent.elite_named(data)), false, true)
	_check(elite._elite_tex != null, "an elite draws its elite sprite")
	_check(is_equal_approx(elite.figure_height, elite.base_height * Fighter.ELITE_SCALE) and is_equal_approx(elite.figure_width(), elite.figure_height * elite._region.size.x / elite._region.size.y), "its layout size is still the plain sprite's, scaled")
	var boss := Fighter.new()
	boss.set_enemy(EnemyUnit.new(StarterContent.enemy_by_id(&"the_conductor")), true, true)
	_check(boss._elite_tex == null, "a boss never takes elite art")
	# Reusing one Fighter: going back to a regular enemy drops the elite art.
	elite.set_enemy(EnemyUnit.new(data), false, false)
	_check(elite._elite_tex == null, "a Fighter set to a regular enemy again drops the elite art")
	for f in [regular, elite, boss]:
		f.free()


func _no_elite_art_falls_back() -> void:
	_check(PaintedArt.enemy_elite_figure(&"conductor").is_empty() and PaintedArt.enemy_elite_figure(&"nonesuch").is_empty(), "a key with no elite art gives nothing, so the plain sprite is used")

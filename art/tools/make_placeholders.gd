extends SceneTree
## Writes procedural stand-in layers so the parallax pipeline can be previewed before real
## painted art exists. Replace the PNGs in art/layers/<enemy>/ with painted ones (same names/size).
##   godot --headless --path . -s res://art/tools/make_placeholders.gd

const W := 960
const H := 320
const OUT := "res://art/layers/warden/"

var noise := FastNoiseLite.new()


func _initialize() -> void:
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	DirAccess.make_dir_recursive_absolute(OUT)
	_bg().save_png(OUT + "bg.png")
	_mid().save_png(OUT + "mid.png")
	_figure().save_png(OUT + "figure.png")
	_fg().save_png(OUT + "fg.png")
	print("wrote layers to ", OUT)
	quit()


func _blank() -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _bg() -> Image:
	var img := _blank()
	for y in H:
		for x in W:
			var t := float(y) / H
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var glow := clampf(1.0 - Vector2(x - 480, y - 250).length() / 380.0, 0.0, 1.0)
			var c := Color(0.09, 0.07, 0.09).lerp(Color(0.22, 0.12, 0.10), t * 0.6 + n * 0.25)
			c = c.lerp(Color(0.62, 0.30, 0.14), glow * glow * 0.55)
			img.set_pixel(x, y, c)
	return img


func _mid() -> Image:
	var img := _blank()
	for y in H:
		for x in W:
			var n := noise.get_noise_2d(x * 1.6 + 500, y * 2.4)
			var a := clampf(n * 0.9 + (float(y) / H - 0.45), 0.0, 0.55)
			var pillar := (x % 240 > 200) and y < 270
			if pillar:
				img.set_pixel(x, y, Color(0.05, 0.04, 0.05, 0.85))
			elif a > 0.0:
				img.set_pixel(x, y, Color(0.55, 0.50, 0.55, a * 0.5))
	return img


func _figure() -> Image:
	var img := _blank()
	var body := Color(0.20, 0.17, 0.19)
	var steel := Color(0.34, 0.31, 0.34)
	_ellipse(img, 480, 150, 120, 56, body)
	_rect(img, 410, 150, 140, 170, body)
	_rect(img, 440, 188, 80, 10, Color(0.08, 0.06, 0.07))
	_rect(img, 440, 214, 80, 10, Color(0.08, 0.06, 0.07))
	_ellipse(img, 480, 78, 44, 56, steel)
	_rect(img, 436, 78, 88, 52, steel)
	_rect(img, 452, 74, 56, 10, Color(1.0, 0.72, 0.30))
	_rect(img, 650, 30, 8, 290, Color(0.40, 0.38, 0.38))
	_ellipse(img, 668, 52, 22, 30, Color(0.62, 0.60, 0.60))
	return img


func _fg() -> Image:
	var img := _blank()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		var c := Color(1.0, rng.randf_range(0.5, 0.8), 0.25, rng.randf_range(0.4, 0.9))
		_ellipse(img, rng.randi_range(0, W), rng.randi_range(0, H), rng.randi_range(2, 5), rng.randi_range(2, 5), c)
	return img


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(maxi(y, 0), mini(y + h, H)):
		for xx in range(maxi(x, 0), mini(x + w, W)):
			img.set_pixel(xx, yy, _shade(c, xx, yy))


func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for yy in range(maxi(cy - ry, 0), mini(cy + ry, H)):
		for xx in range(maxi(cx - rx, 0), mini(cx + rx, W)):
			var d := pow(float(xx - cx) / rx, 2) + pow(float(yy - cy) / ry, 2)
			if d <= 1.0:
				var s := _shade(c, xx, yy)
				s.a = c.a * clampf((1.0 - d) * 6.0, 0.0, 1.0)
				img.set_pixel(xx, yy, s)


func _shade(c: Color, x: int, y: int) -> Color:
	var n := noise.get_noise_2d(x * 2.0, y * 2.0) * 0.12
	return Color(clampf(c.r + n, 0, 1), clampf(c.g + n, 0, 1), clampf(c.b + n, 0, 1), c.a)

extends "res://tests/test_base.gd"
## Every numbered marker of the tutorial's fight-screen page sits on or next to something in the battle screenshot, not on
## a flat patch of background (so a changed layout that moves things away from the markers is noticed).


func run() -> int:
	_failures = 0
	var tex := load(TutorialContent.BATTLE_IMAGE) as Texture2D
	_check(tex != null, "the battle screenshot loads")
	if tex == null:
		return _failures
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	_check(Vector2(img.get_size()) == TutorialContent.BATTLE_IMAGE_SIZE, "the screenshot has the size the markers assume")
	_check(Vector2(img.get_size()) == MenuStyle.BASE_SIZE, "the screenshot is the base window's size, the one the layouts are designed for")
	var page: Dictionary = TutorialContent.pages()[1]
	for item in page.items:
		var at: Vector2 = item.at
		_check(Rect2(Vector2(TutorialOverlay.MARKER_RADIUS, TutorialOverlay.MARKER_RADIUS), TutorialContent.BATTLE_IMAGE_SIZE - Vector2.ONE * 2.0 * TutorialOverlay.MARKER_RADIUS).has_point(at), "the marker at %s lies inside the picture" % str(at))
		var lo := 1e9
		var hi := -1e9
		for y in range(int(at.y) - 40, int(at.y) + 41):
			for x in range(int(at.x) - 40, int(at.x) + 41):
				if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
					continue
				var l := img.get_pixel(x, y).get_luminance()
				lo = minf(lo, l)
				hi = maxf(hi, l)
		_check(hi - lo > 0.08, "the marker at %s is near something in the screenshot (contrast %.2f)" % [str(at), hi - lo])
	return _failures

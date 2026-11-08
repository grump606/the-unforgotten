extends "res://tests/test_base.gd"
## The second, non-colour cue on live card numbers: a small triangle that points up when a status raises the
## number and down when it lowers it (see CardView.delta_marker_points), shown only for live lines.


func run() -> int:
	_failures = 0
	var c := Vector2(50, 40)
	var up := CardView.delta_marker_points(1, c, 4.0)
	var down := CardView.delta_marker_points(-1, c, 4.0)
	_check(up.size() == 3 and down.size() == 3, "a raised or lowered number gets a triangle")
	_check(up[0].y < c.y and up[1].y > c.y and up[2].y > c.y, "a raised number's triangle points up (apex above the base)")
	_check(down[0].y > c.y and down[1].y < c.y and down[2].y < c.y, "a lowered number's triangle points down (apex below the base)")
	_check(is_equal_approx(up[1].x - c.x, c.x - up[2].x) and up[1].y == up[2].y, "the base is level and centred")
	_check(CardView.delta_marker_points(0, c, 4.0).is_empty(), "an unchanged (printed) number gets no marker")
	# Only lines the player's statuses changed carry a delta, and so a marker.
	var card: CardData = null
	for candidate in ContentRegistry.all_cards():
		if candidate.effects.size() > 0 and candidate.effects[0].kind == CardEffect.Kind.DAMAGE and candidate.effects[0].amount > 0 and not candidate.dormant:
			card = candidate
			break
	_check(card != null, "setup: a plain Deal card exists")
	if card != null:
		var view := CardView.new()
		view.set_card(card)
		_check(view.body_lines()[0].delta == 0, "outside a fight no line has a marker")
		var player := Combatant.new("P", 40)
		player.apply_status(Combatant.Status.MALICE, 3)
		view.live = player
		_check(view.body_lines()[0].delta == 1, "Malice raises the live number, so its line is marked up")
		var shaken := Combatant.new("Q", 40)
		shaken.apply_status(Combatant.Status.SHAKEN, 2)
		view.live = shaken
		_check(view.body_lines()[0].delta == -1, "Shaken lowers the live number, so its line is marked down")
		view.free()
	return _failures

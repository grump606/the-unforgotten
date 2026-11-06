class_name TreasureScene
extends ScreenScene
## The scene behind a treasure stop (docs/MAP_DESIGN.md "Phase 4b"): the Name Vault painting, dimmed, with a
## code-drawn strongbox on the floor. Closed it is a banded chest with a lock plate; opened its lid tips back
## and a warm light rises from inside. `opened` is set by TreasureScreen before the scene is shown.

const PAINTING := &"battle_archive"
const WOOD_LIGHT := Color(0.40, 0.25, 0.13)
const WOOD_DARK := Color(0.22, 0.13, 0.07)
const IRON := Color(0.13, 0.12, 0.13)
const GILT := Color(0.86, 0.66, 0.30)
const LIGHT := Color(1.0, 0.84, 0.50)

var opened := false:
	set(value):
		opened = value
		queue_redraw()

## Where the chest sits, as fractions of the scene (the screen lays its panel out around it).
var chest_centre := Vector2(0.5, 0.36)


func _init() -> void:
	super(4477, 24)


## The chest's width in pixels for a scene of this size.
func chest_width(w: float, h: float) -> float:
	return clampf(minf(w * 0.3, h * 0.46), 120.0, 300.0)


func _draw_scene(w: float, h: float) -> void:
	if not _draw_painted_bg(PAINTING, Rect2(0, 0, w, h), 1.08, 0.3, Color(0.44, 0.44, 0.5)):
		_gradient(Rect2(0, 0, w, h), Color(0.06, 0.07, 0.09), Color(0.12, 0.10, 0.09))
	draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.02, 0.03, 0.4))
	_draw_motes(w, h, AMBER, 0.35)
	_draw_scrim(w, h)
	var width := chest_width(w, h)
	var at := Vector2(w * chest_centre.x, h * chest_centre.y)
	if opened:
		_halo(at + Vector2(0, -width * 0.12), width * 1.3, LIGHT, 0.02 * flicker(3))
	else:
		_halo(at, width * 0.9, AMBER, 0.008 * flicker(1))
	_draw_chest(at, width)


## The chest centred at `at`, `width` wide: a floor shadow, the box, then the lid (shut, or tipped back).
func _draw_chest(at: Vector2, width: float) -> void:
	var half := width * 0.5
	var box_h := width * 0.36
	var top := at.y - box_h * 0.1 # the rim of the box
	_ellipse(Vector2(at.x, top + box_h + 4.0), half * 1.12, width * 0.05, Color(0, 0, 0, 0.45), 20)
	var body := Rect2(at.x - half, top, width, box_h)
	draw_rect(body, WOOD_LIGHT)
	for i in 4:
		draw_line(Vector2(body.position.x, top + box_h * (i + 1) / 5.0), Vector2(body.end.x, top + box_h * (i + 1) / 5.0), Color(WOOD_DARK, 0.55), 1.5)
	if opened:
		# The inside: a dark mouth with light pouring out of it.
		var mouth := PackedVector2Array([Vector2(body.position.x + 6, top), Vector2(body.end.x - 6, top), Vector2(body.end.x - 12, top - width * 0.06), Vector2(body.position.x + 12, top - width * 0.06)])
		draw_colored_polygon(mouth, Color(LIGHT, 0.9))
		_ellipse(Vector2(at.x, top - width * 0.06), half * 0.78, width * 0.05, Color(1.0, 0.95, 0.75, 0.85), 18)
	for x: float in [-0.34, 0.34]:
		draw_rect(Rect2(at.x + x * width - width * 0.035, top, width * 0.07, box_h), IRON)
	draw_rect(body, IRON, false, 2.5)
	draw_rect(Rect2(body.position.x, top + box_h - 3.0, width, 3.0), Color(IRON, 0.8))
	if opened:
		_draw_open_lid(at, width, top)
	else:
		_draw_shut_lid(at, width, top)
		_draw_lock(Vector2(at.x, top + 2.0), width)


func _lid_shape(at_x: float, base_y: float, width: float, height: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var half := width * 0.5
	pts.append(Vector2(at_x - half, base_y))
	for i in 17:
		var a := PI + PI * i / 16.0
		pts.append(Vector2(at_x + cos(a) * half, base_y + sin(a) * height))
	pts.append(Vector2(at_x + half, base_y))
	return pts


func _draw_shut_lid(at: Vector2, width: float, top: float) -> void:
	var height := width * 0.26
	var lid := _lid_shape(at.x, top, width, height)
	draw_colored_polygon(lid, WOOD_LIGHT.lightened(0.06))
	# Grain across the dome, then the iron straps over it.
	for i in 3:
		var y := top - height * (0.3 + 0.22 * i)
		var reach := sqrt(maxf(1.0 - pow((top - y) / height, 2.0), 0.0)) * width * 0.5
		draw_line(Vector2(at.x - reach + 3.0, y), Vector2(at.x + reach - 3.0, y), Color(WOOD_DARK, 0.5), 1.5)
	for x: float in [-0.34, 0.34]:
		var dx: float = x * width
		var lift := height * sqrt(maxf(1.0 - pow(dx / (width * 0.5), 2.0), 0.0))
		draw_rect(Rect2(at.x + dx - width * 0.035, top - lift, width * 0.07, lift), IRON)
	draw_polyline(lid, IRON, 2.5, true)
	draw_line(Vector2(at.x - width * 0.5, top), Vector2(at.x + width * 0.5, top), IRON, 3.0)


## The lid tipped back behind the box: its inside faces us, a flat dome pressed against the back edge.
func _draw_open_lid(at: Vector2, width: float, top: float) -> void:
	var height := width * 0.2
	var base_y := top - width * 0.1
	var lid := PackedVector2Array()
	var half := width * 0.5
	lid.append(Vector2(at.x - half + 4.0, base_y))
	lid.append(Vector2(at.x - half + 14.0, base_y - height * 1.05))
	lid.append(Vector2(at.x + half - 14.0, base_y - height * 1.05))
	lid.append(Vector2(at.x + half - 4.0, base_y))
	draw_colored_polygon(lid, WOOD_DARK)
	var inner := PackedVector2Array([lid[0] + Vector2(8, -3), lid[1] + Vector2(6, 6), lid[2] + Vector2(-6, 6), lid[3] + Vector2(-8, -3)])
	draw_colored_polygon(inner, Color(LIGHT.r * 0.55, LIGHT.g * 0.4, LIGHT.b * 0.2, 0.9))
	draw_polyline(PackedVector2Array([lid[0], lid[1], lid[2], lid[3]]), IRON, 2.5, true)


func _draw_lock(at: Vector2, width: float) -> void:
	var plate := Vector2(width * 0.11, width * 0.14)
	var rect := Rect2(at - Vector2(plate.x * 0.5, plate.y * 0.5), plate)
	draw_rect(rect, GILT)
	draw_rect(rect, IRON, false, 2.0)
	draw_circle(at + Vector2(0, -plate.y * 0.08), plate.x * 0.14, IRON)
	draw_line(at + Vector2(0, -plate.y * 0.08), at + Vector2(0, plate.y * 0.22), IRON, 2.0)

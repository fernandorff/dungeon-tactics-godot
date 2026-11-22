class_name Glove
extends Control
## The white glove that points at the focused row (FFT's cursor; the web game's menu3d glove), drawn flat: a cuff, the
## back of the hand and the pointing finger, with a dark outline. It bobs a little so the eye finds it.

const W := 62.0 # reference px, as menu-layout.ts REF.hand
var _t := 0.0
var _at := Vector2.ZERO


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	size = Vector2(HudSkin.px(W), HudSkin.px(40))


## points its fingertip at `tip`
func point_at(tip: Vector2) -> void:
	_at = tip - Vector2(size.x, size.y / 2)
	position = _at


func _process(dt: float) -> void:
	_t += dt
	position = _at + Vector2(sin(_t * 6.0) * 2.0 - 2.0, 0)


func _draw() -> void:
	var s := size / Vector2(62, 40)
	var line := Color("#2a2418")
	var white := Color("#f7f4ea")
	var shade := Color("#c9c3b2")
	var pts := func(a: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p: Vector2 in a:
			out.append(p * s)
		return out
	var cuff: PackedVector2Array = pts.call([Vector2(2, 10), Vector2(14, 8), Vector2(14, 32), Vector2(2, 30)])
	var hand: PackedVector2Array = pts.call([Vector2(14, 8), Vector2(34, 6), Vector2(40, 12), Vector2(60, 14), Vector2(62, 19), Vector2(58, 23), Vector2(40, 23), Vector2(40, 30), Vector2(30, 34), Vector2(14, 32)])
	for poly in [cuff, hand]:
		draw_colored_polygon(poly, white)
		var closed: PackedVector2Array = poly.duplicate()
		closed.append(poly[0])
		draw_polyline(closed, line, 1.5, true)
	# the knuckles' folds
	for y in [25.0, 29.0]:
		draw_line(Vector2(24, y) * s, Vector2(39, y - 1) * s, shade, 1.2, true)
	draw_line(Vector2(8, 11) * s, Vector2(8, 29) * s, shade, 1.2, true)

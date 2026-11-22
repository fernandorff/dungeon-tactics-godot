class_name CombatBar
extends Control
## The combat bar along the bottom (port of the web game's bar3d/bar3d.ts): the acting unit's sheet on the left, the
## target's on the right (the unit under the cursor when nothing is aimed) and, while a strike is aimed, the plate between
## them with the hit chance, the damage or heal, push, ALLY and the ability. Each piece redraws only when its view changes.

var _me := UnitSheet.new()
var _target := UnitSheet.new()
var _plate := Control.new()
var _plate_view := {}
var _key := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_me.position = HudSkin.region("sheet").position
	add_child(_me)
	_target.mirror = true
	_target.position = HudSkin.region("target").position
	add_child(_target)
	var r := HudSkin.region("preview")
	_plate.position = r.position
	_plate.size = r.size
	_plate.mouse_filter = MOUSE_FILTER_IGNORE
	_plate.draw.connect(_draw_plate)
	add_child(_plate)


## `v`: BarView.of's {sheet, plate, target}
func show_bar(v: Dictionary) -> void:
	_me.show_view(v.sheet)
	_target.show_view(v.target)
	var key := hash([v.plate, Texts.current()])
	if key != _key:
		_key = key
		_plate_view = v.plate
		_plate.visible = not v.plate.is_empty()
		_plate.queue_redraw()


func _draw_plate() -> void:
	var p := _plate_view
	if p.is_empty():
		return
	var s := _plate.size
	var tip := HudSkin.px(40)
	# a dark plate pointing at the target, its edge red when the strike hits the user's own side
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(s.x - tip, 0), Vector2(s.x, s.y * 0.5), Vector2(s.x - tip, s.y), Vector2(0, s.y)])
	_plate.draw_colored_polygon(pts, Color("#1d1c19", 0.94))
	var edge := Color("#ff7a5c") if p.warn else Color("#b9b3a0")
	pts.append(pts[0])
	_plate.draw_polyline(pts, edge, 1.5, true)
	var mid := (s.x - tip) / 2
	_line(p.chance, mid, HudSkin.px(40), 28, HudSkin.LIGHT)
	var big_col := Color("#f0806a") if p.big and not p.amount.begins_with("+") else (Color("#bfe88a") if p.big else HudSkin.LIGHT)
	_line(p.amount, mid, HudSkin.px(118), 80 if p.big else 40, big_col)
	_line(p.label, mid, HudSkin.px(165), 26, HudSkin.WARN if p.warn else Color("#f0806a"))
	_line(p.name, mid, HudSkin.px(198), 20, HudSkin.LIGHT_SOFT)


## a line centred on `x` with its baseline at `y`, never wider than the plate
func _line(s: String, x: float, y: float, ref_size: float, col: Color) -> void:
	if s == "":
		return
	var f := HudSkin.font()
	var n := HudSkin.text(ref_size)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, n).x
	while w > _plate.size.x - HudSkin.px(60) and n > HudSkin.MIN_TEXT:
		n -= 2
		w = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, n).x
	_plate.draw_string(f, Vector2(x - w / 2, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, n, col)

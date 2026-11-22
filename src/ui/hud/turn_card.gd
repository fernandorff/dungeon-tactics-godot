class_name TurnCard
extends Control
## A card of the turn list (port of the web game's turn3d/card.ts, drawn flat): the order number in the side's colour,
## the face in a light frame (a pink diamond on an enemy's), and on the night-blue plate beside it the name, then life
## and mana, then stamina and CT, each over its thin bar. A repeat (a unit listed above) shows the face and the name only;
## a charge shows its caster's face with the spell's icon and the ticks left. `marked`: the strike being aimed reaches it;
## `firing`: it is the charge being aimed.

const FACE := Vector2(48, 58) # our px; queue-layout.ts sizes at 1280x720, taller here so three 14 px lines fit
const NUMBER_W := 40.0
const STATS_W := 150.0

var unit := {}
var number := 0
var small := false
var charge := ""
var ticks := 0
var marked := false
var firing := false
var _face: TextureRect


func setup() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	var h := FACE.y if not small else maxf(FACE.y * 0.6, 36.0)
	size = Vector2(NUMBER_W + FACE.x + 6 + STATS_W, h)
	var fw := FACE.x * (h / FACE.y)
	_face = Portraits.face(unit, int(h))
	if _face:
		_face.mouse_filter = MOUSE_FILTER_IGNORE
		_face.custom_minimum_size = Vector2.ZERO
		_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_face.position = Vector2(NUMBER_W + 2, 2)
		_face.size = Vector2(fw - 4, h - 4)
		_face.clip_contents = true
		add_child(_face)
	queue_redraw()


func _face_w() -> float:
	return FACE.x * (size.y / FACE.y)


func _draw() -> void:
	var f := HudSkin.font()
	var foe: bool = unit.team != "hero"
	var fw := _face_w()
	var plate := Rect2(NUMBER_W + fw + 2, 0, size.x - NUMBER_W - fw - 2, size.y)
	if small or charge != "":
		plate.size.y = minf(size.y, 30)
		plate.position.y = (size.y - plate.size.y) / 2
	# the plate: night blue, a foe's wine, darker to the right
	draw_rect(plate, Color(HudSkin.WINE if foe else HudSkin.NIGHT, 0.92))
	draw_rect(Rect2(plate.position + Vector2(plate.size.x * 0.6, 0), Vector2(plate.size.x * 0.4, plate.size.y)), Color(HudSkin.WINE_LOW if foe else HudSkin.NIGHT_LOW, 0.6))
	# the face's frame: light paper, a gold one on the card the aimed strike reaches
	var frame := Rect2(NUMBER_W, 0, fw, size.y)
	draw_rect(frame, Color("#efe5c8") if not marked else Color("#f0d76c"))
	draw_rect(frame.grow(-2), Color("#a6b9c6") if not foe else Color("#c8a39a"))
	if marked or firing:
		draw_rect(Rect2(0, 0, NUMBER_W - 4, size.y), Color("#c8a54e"))
		draw_rect(Rect2(0, 0, NUMBER_W - 4, size.y), Color("#ffe56e"), false, 2.0)
	# the number, big, in the side's colour (blue a hero, pink an enemy)
	var num := str(number)
	var ns := 26
	var nw := f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x
	draw_string_outline(f, Vector2((NUMBER_W - 4 - nw) / 2, size.y / 2 + ns * 0.35), num, HORIZONTAL_ALIGNMENT_LEFT, -1, ns, 4, Color(0, 0, 0, 0.7))
	draw_string(f, Vector2((NUMBER_W - 4 - nw) / 2, size.y / 2 + ns * 0.35), num, HORIZONTAL_ALIGNMENT_LEFT, -1, ns, HudSkin.FOE if foe else HudSkin.HERO)
	if foe:
		var d := Vector2(NUMBER_W + 1, 3)
		draw_colored_polygon(PackedVector2Array([d + Vector2(0, -4), d + Vector2(4, 0), d + Vector2(0, 4), d + Vector2(-4, 0)]), Color("#f06b9a"))
	var x := plate.position.x + 6
	if charge != "":
		var tex := Icons.texture(charge)
		if tex:
			draw_texture_rect(tex, Rect2(frame.end - Vector2(22, 22), Vector2(20, 20)), false)
		_text(Texts.ability_name(charge) + " · " + Texts.t("%d tiq.", "%d tk") % ticks, x, size.y / 2 + 5, 14)
		return
	if small:
		_text(Texts.unit_name(unit.def), x, size.y / 2 + 5, 15)
		return
	var lines := TurnRows.card_lines(unit)
	var bars := TurnRows.card_bars(unit)
	_text(lines[0], x, 15, 14)
	_text(lines[1], x, 33, 14)
	_bar(x, 36, 62, bars[0], HudSkin.HP)
	_bar(x + 66, 36, 62, bars[1], HudSkin.MP)
	_text(lines[2], x, 51, 14)
	_bar(x, 54, 62, bars[2], HudSkin.ST)
	_bar(x + 66, 54, 62, bars[3], HudSkin.CT)


func _text(s: String, x: float, y: float, px: int) -> void:
	draw_string(HudSkin.font(), Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 2, px, HudSkin.LIGHT)


func _bar(x: float, y: float, w: float, fill: float, col: Color) -> void:
	if fill < 0.0:
		return
	draw_rect(Rect2(x, y, w, 3), HudSkin.GROOVE)
	draw_rect(Rect2(x, y, w * fill, 3), col)

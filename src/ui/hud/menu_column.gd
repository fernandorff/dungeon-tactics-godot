class_name MenuColumn
extends Control
## One parchment column of the command menu (port of the web game's menu3d/column.ts): its head, then one row per
## command or action, each with its icon in the darker column, its name and its note (beside it, or under it on the Agir
## lists), Move's gauge, and the lit focused row. Rebuilt only when what it shows changes; clicks and hovers go out by row.

signal picked(i: int)
signal hovered(i: int)

const HEAD := 42.0 # reference px, as menu-layout.ts REF
const ROW := 56.5
const FOOT := 2.0
const ICON_W := 55.0
const ICON := 40.0
const WIDTH := 414.0

var _paper := Control.new()
var _key := 0
var _rows := 0
var _hover := -1


static func height_of(rows: int) -> float:
	return HudSkin.px(HEAD + rows * ROW + FOOT)


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_paper.mouse_filter = MOUSE_FILTER_IGNORE
	_paper.draw.connect(func() -> void: HudSkin.draw_paper(_paper, size))
	add_child(_paper)


## the column's head, rows and focused row; `active`: its focus is the one the player moves (lit)
func show_rows(title: String, rows: Array, index: int, active: bool) -> void:
	var key := hash([title, rows, Texts.current()])
	if key == _key:
		_focus(index, active) # a cursor step only moves the lit band: no rebuild
		return
	_key = key
	_rows = rows.size()
	custom_minimum_size = Vector2(HudSkin.px(WIDTH), height_of(rows.size()))
	size = custom_minimum_size
	for c in get_children():
		if c != _paper:
			c.queue_free()
	_paper.material = HudSkin.paper(size, HEAD, 0.0, ICON_W, Vector3(HEAD, ROW, rows.size()), float(get_instance_id() % 97))
	_focus(index, active)
	_paper.size = size
	_paper.queue_redraw()
	_put(HudSkin.label(title, 24, HudSkin.INK_SOFT), HudSkin.px(10), HudSkin.px(HEAD / 2 - 1))
	for i in rows.size():
		_build_row(rows[i], HudSkin.px(HEAD + (i + 0.5) * ROW))


## the lit row band on the paper (none for an index off the list)
func _focus(index: int, active: bool) -> void:
	var on := index >= 0 and index < _rows
	(_paper.material as ShaderMaterial).set_shader_parameter("focus", Vector4(HEAD + (index + 0.5) * ROW, ROW, 1.0 if active and on else 0.0, 0.0))


## a label with its left edge at `x` and its middle at `mid`
func _put(l: Label, x: float, mid: float) -> Label:
	add_child(l)
	l.position = Vector2(x, mid - l.get_minimum_size().y / 2)
	return l


func _build_row(r: Dictionary, mid: float) -> void:
	var left := HudSkin.px(ICON_W + 8)
	var width := size.x - HudSkin.px(ICON_W + 8 + 7 + 12)
	var font := HudSkin.font()
	var note_width := font.get_string_size(r.note, HORIZONTAL_ALIGNMENT_LEFT, -1, HudSkin.text(20)).x
	var name_width := font.get_string_size(r.label, HORIZONTAL_ALIGNMENT_LEFT, -1, HudSkin.text(30)).x
	# Put long translations on two lines so the target's name and HP both stay readable.
	var below: bool = r.note != "" and (r.below or name_width + note_width + HudSkin.px(10) > width)
	var note: Label = null
	if r.note != "":
		note = HudSkin.label(r.note, 18 if below else 20, HudSkin.INK_SOFT)
		if below:
			_put(note, left, mid + HudSkin.px(13))
		else:
			_put(note, size.x - HudSkin.px(12) - note_width, mid + HudSkin.px(1))
	var name := HudSkin.label(r.label, 26 if below else 30, HudSkin.INK_OFF if r.off else HudSkin.INK)
	var room := width - (note_width + HudSkin.px(10) if note and not below else 0.0)
	# a long name beside a note shrinks to the room left, as the web scales it, down to the text floor, then clips
	var n := name.get_theme_font_size("font_size")
	while n > HudSkin.MIN_TEXT and HudSkin.font().get_string_size(r.label, HORIZONTAL_ALIGNMENT_LEFT, -1, n).x > room:
		n -= 1
	name.add_theme_font_size_override("font_size", n)
	name.clip_text = true
	name.size.x = room
	_put(name, left, mid - (HudSkin.px(9) if below else 0.0))
	if r.gauge >= 0.0:
		# Move's bar along the row's foot: the track in the panel's shade, the half tiles left in the walk marks' blue
		var track := ColorRect.new()
		track.color = HudSkin.SHADE
		track.position = Vector2(left, mid + HudSkin.px(17))
		track.size = Vector2(width, maxf(2.0, HudSkin.px(5)))
		track.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(track)
		var fill := ColorRect.new()
		fill.color = HudSkin.MOVE_BLUE
		fill.size = Vector2(width * clampf(r.gauge, 0.0, 1.0), track.size.y)
		fill.mouse_filter = MOUSE_FILTER_IGNORE
		track.add_child(fill)
	var icon := RowIcon.new()
	icon.id = r.icon
	icon.off = r.off
	icon.size = Vector2.ONE * HudSkin.px(ICON)
	icon.position = Vector2(HudSkin.px(ICON_W) / 2, mid) - icon.size / 2
	add_child(icon)


## the row under a point of the column, -1 on the head
func row_at(p: Vector2) -> int:
	var i := floori((p.y - HudSkin.px(HEAD)) / HudSkin.px(ROW))
	return i if i >= 0 and i < _rows else -1


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var i := row_at(ev.position)
		if i != _hover and i >= 0:
			_hover = i
			hovered.emit(i)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var i := row_at(ev.position)
		if i >= 0:
			picked.emit(i)
			accept_event()
	elif ev is InputEventScreenTouch and ev.pressed:
		var i := row_at(ev.position)
		if i >= 0:
			picked.emit(i)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = -1

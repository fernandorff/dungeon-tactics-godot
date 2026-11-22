class_name HudHints
extends Control
## The battle's corners (port of the web game's hints3d/hints3d.ts, hints-view.ts and window3d/tools3d.ts): the Height
## corner with the tile line under it, the banner pill at the top, the key hints at the foot (what Confirm and Cancel do
## now, the camera, the menu) and the corner buttons: the gear, Undo and the two camera turns. Each piece is redrawn only
## when its text changes. The gear and the buttons call back into the battle screen.

signal pressed(what: String)

const TAP := 44.0
const GAP := 8.0

var _height: Label
var _number: Label
var _line: Label
var _rule: ColorRect
var _banner: Label
var _left := HBoxContainer.new()
var _right := HBoxContainer.new()
var _undo: Button
var _camera_pair := HBoxContainer.new()
var _finger := false
var _key := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	var h := HudSkin.region("height")
	_height = HudSkin.label(Texts.t("Altura", "Height"), 30, HudSkin.LIGHT)
	_number = HudSkin.label("", 110, Color("#3ba86f"))
	_number.add_theme_constant_override("outline_size", 6)
	_number.add_theme_color_override("font_outline_color", Color("#0d2418"))
	_line = HudSkin.label("", 22, HudSkin.LIGHT)
	for l in [_height, _number, _line]:
		l.add_theme_constant_override("outline_size", maxi(l.get_theme_constant("outline_size"), 4))
		if l != _number:
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		add_child(l)
	_height.position = h.position + Vector2(HudSkin.px(88), HudSkin.px(30))
	_number.position = h.position + Vector2(HudSkin.px(255), -HudSkin.px(20))
	_rule = ColorRect.new()
	_rule.color = Color(HudSkin.LIGHT, 0.45)
	_rule.position = h.position + Vector2(HudSkin.px(40), h.size.y)
	_rule.size = Vector2(h.size.x - HudSkin.px(40), 1)
	_rule.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_rule)
	_line.position = h.position + Vector2(HudSkin.px(88), h.size.y + HudSkin.px(10))
	_banner = HudSkin.label("", 32, HudSkin.LIGHT)
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color("#1a2238", 0.85)
	pill.set_corner_radius_all(30)
	pill.content_margin_left = HudSkin.px(48)
	pill.content_margin_right = HudSkin.px(48)
	pill.content_margin_top = HudSkin.px(12)
	pill.content_margin_bottom = HudSkin.px(12)
	_banner.add_theme_stylebox_override("normal", pill)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_banner)
	for row in [_left, _right]:
		row.add_theme_constant_override("separation", int(HudSkin.px(40)))
		row.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(row)
	_corner_buttons()


func _corner_buttons() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(GAP))
	row.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(row)
	row.add_child(_tool("⚙", Texts.t("Opções", "Options"), "pause"))
	_undo = _tool("↶", Texts.t("Desfazer", "Undo"), "undo")
	row.add_child(_undo)
	# right to left from the corner: the gear, then Undo when it shows
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.size.x = TAP * 2 + GAP
	row.position = Vector2(1280 - GAP - row.size.x, GAP)
	# the camera pair right after the turn list's column, where nothing else lives at that height
	var pair := _camera_pair
	pair.add_theme_constant_override("separation", int(GAP))
	pair.position = Vector2(HudSkin.region("turn").end.x + GAP, GAP)
	pair.add_child(_tool("↺", Texts.t("Girar a câmera para a esquerda", "Turn the camera left"), "turn_left"))
	pair.add_child(_tool("↻", Texts.t("Girar a câmera para a direita", "Turn the camera right"), "turn_right"))
	add_child(pair)


func _tool(glyph: String, name: String, what: String) -> Button:
	var b := Button.new()
	b.text = glyph
	b.tooltip_text = name
	b.custom_minimum_size = Vector2(TAP, TAP)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", HudSkin.LIGHT)
	for st in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color("#1a1d26", 0.9) if st == "normal" else Color("#2b3142", 0.95)
		s.border_color = Color(HudSkin.LIGHT, 0.3)
		s.set_border_width_all(1)
		s.set_corner_radius_all(6)
		b.add_theme_stylebox_override(st, s)
	b.pressed.connect(func() -> void: pressed.emit(what))
	return b


## `height`: the tile's number, or -1 to hide the corner; `hints`: {left, right} of [[caps], text]
func show_hints(height: int, line: String, banner: String, hints: Dictionary, can_undo: bool) -> void:
	_update_visibility()
	_undo.disabled = not can_undo
	for l in [_height, _number, _line, _rule]:
		l.visible = height >= 0
	# the Height corner follows the cursor; the rest only changes with the screen, so it keeps its own key
	_height.text = Texts.t("Altura", "Height")
	_number.text = str(height)
	_line.text = line
	var key := hash([banner, hints, can_undo, Texts.current()])
	if key == _key:
		return
	_key = key
	_banner.visible = banner != ""
	_banner.text = banner
	_banner.reset_size()
	var b := HudSkin.region("banner")
	_banner.position = Vector2(640 - _banner.size.x / 2, b.position.y)
	_fill(_left, hints.get("left", []))
	_fill(_right, hints.get("right", []))
	_left.reset_size()
	_right.reset_size()
	var lr := HudSkin.region("hintsLeft")
	var rr := HudSkin.region("hints")
	_left.position = Vector2(lr.position.x, rr.position.y - HudSkin.px(4))
	_right.position = Vector2(rr.end.x - _right.get_combined_minimum_size().x, rr.position.y - HudSkin.px(4))


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_finger = true
	elif (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		_finger = false
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		_finger = false
	else:
		return
	_update_visibility()


func _update_visibility() -> void:
	var mode := Settings.hints()
	_left.visible = mode == "always" or (mode == "auto" and not _finger)
	_right.visible = _left.visible
	_camera_pair.visible = Settings.screen_buttons()
	_undo.visible = _camera_pair.visible


func _fill(row: HBoxContainer, hints: Array) -> void:
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	for h in hints:
		var one := HBoxContainer.new()
		one.add_theme_constant_override("separation", int(HudSkin.px(4)))
		for cap: String in h[0]:
			one.add_child(_cap(cap))
		var t := HudSkin.label(h[1], 22, HudSkin.LIGHT)
		t.add_theme_constant_override("outline_size", 4)
		t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		one.add_child(Control.new())
		one.get_child(-1).custom_minimum_size = Vector2(HudSkin.px(8), 0)
		one.add_child(t)
		row.add_child(one)


## a key's cap: its letters on a small paper tile (glyphs.ts' keyboard caps)
func _cap(text: String) -> Label:
	var l := HudSkin.label(text, 18, HudSkin.INK)
	var s := StyleBoxFlat.new()
	s.bg_color = HudSkin.PAPER
	s.border_color = HudSkin.EDGE
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 4
	s.content_margin_right = 4
	l.add_theme_stylebox_override("normal", s)
	return l

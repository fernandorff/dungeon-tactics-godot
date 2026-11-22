class_name HudHints
extends Control
## The battle's corner buttons (port of the web game's window3d/tools3d.ts): the gear, Undo and the two camera turns,
## and which input was last used (a finger hides the key hints, which Hints3d draws). The buttons call back into the
## battle screen.

signal pressed(what: String)
signal device_changed # a finger or a key: the key hints hide or come back

const TAP := 44.0
const GAP := 8.0

var _undo: Button
var _camera_pair := HBoxContainer.new()
var _finger := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
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


func show_hints(can_undo: bool) -> void:
	_update_visibility()
	_undo.disabled = not can_undo


## the key hints show: Options › Key and button hints, Automatic hiding them for a finger (hints-view.ts hintsDevice)
func rows_shown() -> bool:
	var mode := Settings.hints()
	return mode == "always" or (mode == "auto" and not _finger)


func _input(event: InputEvent) -> void:
	var was := _finger
	if event is InputEventScreenTouch and event.pressed:
		_finger = true
	elif (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		_finger = false
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		_finger = false
	else:
		return
	_update_visibility()
	if _finger != was:
		device_changed.emit()


func _update_visibility() -> void:
	_camera_pair.visible = Settings.screen_buttons()
	_undo.visible = _camera_pair.visible

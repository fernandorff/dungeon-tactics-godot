class_name Kit
## The interface pieces every screen builds with: a panel, a label, a button and a dialog, with the colours and sizes in one
## place (the web game's design system tokens, simplified). Touch targets stay 44 px tall and text 14 px or more.

const BG := Color(0.07, 0.08, 0.11, 0.88)
const TEXT := Color(0.94, 0.93, 0.9)
const MUTED := Color(0.68, 0.7, 0.75)
const ACCENT := Color(1.0, 0.82, 0.4)
const HERO := Color(0.55, 0.75, 1.0)
const FOE := Color(1.0, 0.55, 0.5)
const FOCUS := Color(0.95, 0.75, 0.3)


static func _box(col: Color, border: Color = Color(1, 1, 1, 0.12)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(10)
	return s


static func focus_box() -> StyleBoxFlat:
	var s := _box(Color(0.3, 0.24, 0.1, 0.95), FOCUS)
	s.set_border_width_all(2)
	return s


## a panel at `at` from its anchor corner, holding a vertical list; returns the list
static func panel(parent: Control, at: Vector2, size: Vector2, anchor: int = Control.PRESET_TOP_LEFT) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(BG))
	p.custom_minimum_size = size
	parent.add_child(p)
	var grow_h := Control.GROW_DIRECTION_BEGIN if anchor in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_RIGHT] else (Control.GROW_DIRECTION_BOTH if anchor in [Control.PRESET_CENTER_BOTTOM, Control.PRESET_CENTER_TOP, Control.PRESET_CENTER] else Control.GROW_DIRECTION_END)
	var grow_v := Control.GROW_DIRECTION_BEGIN if anchor in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM] else (Control.GROW_DIRECTION_BOTH if anchor in [Control.PRESET_CENTER, Control.PRESET_CENTER_LEFT, Control.PRESET_CENTER_RIGHT] else Control.GROW_DIRECTION_END)
	p.grow_horizontal = grow_h
	p.grow_vertical = grow_v
	p.set_anchors_and_offsets_preset(anchor, Control.PRESET_MODE_MINSIZE)
	p.position += at
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	return v


static func label(text: String, size: int = 16, col: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", _box(Color(0.14, 0.15, 0.2, 0.95)))
	b.add_theme_stylebox_override("hover", _box(Color(0.2, 0.22, 0.3, 0.95), FOCUS))
	b.add_theme_stylebox_override("pressed", _box(Color(0.25, 0.2, 0.1, 0.95), FOCUS))
	b.add_theme_stylebox_override("focus", focus_box())
	b.add_theme_stylebox_override("disabled", _box(Color(0.1, 0.1, 0.12, 0.9)))
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(on_press)
	return b


## a centred window over a dim backdrop: a title, a text and its buttons ([[label, callable]]); returns the backdrop
static func dialog(parent: Control, title: String, text: String, actions: Array) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(dim)
	var v := panel(dim, Vector2.ZERO, Vector2(480, 0), Control.PRESET_CENTER)
	v.add_child(label(title, 22, ACCENT))
	if text != "":
		v.add_child(label(text, 16))
	var first: Button = null
	for a in actions:
		var b := button(a[0], a[1])
		v.add_child(b)
		if first == null:
			first = b
	if first:
		first.call_deferred("grab_focus")
	return dim


## a full screen with a title and a vertical list in the middle; returns the list
static func page(parent: Control, title: String, width: float = 560.0) -> VBoxContainer:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bg.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(width, 0)
	v.add_theme_constant_override("separation", 8)
	center.add_child(v)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	v.add_child(spacer)
	v.add_child(label(title, 28, ACCENT))
	return v

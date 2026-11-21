class_name OptionsRow
extends PanelContainer
## One row of the Options list (port of option-row.ts and flow3d/options-row.ts): the setting's name at the left and its
## value at the right, drawn as what it is: a word between ‹ › in a light box, a switch, or a % with a bar a pointer can
## drag. Left and right change it, Enter goes to the next value, a press on ‹ goes back and anywhere else on the value goes
## forward; a press on the name only puts the cursor on the row. A link row ends in ▸ and runs on Enter or a press.

signal described(title: String, help: String)
signal changed # a value was set: the window checks whether the language moved

const INK := Color("#e8e0cc")
const DARK := Color("#2a2418")
const PAPER := Color("#ece4cc")
const GOLD := Color("#f0dca0")
const ON := Color("#4caf7d")
const OFF := Color("#5a5448")

var opt: Dictionary
var _value: Control # the value's area: a press left of it only focuses
var _prev: Label
var _text: Label
var _slider: HSlider
var _switch: Control
var _name: Label


static func make(o: Dictionary) -> OptionsRow:
	var r := OptionsRow.new()
	r.opt = o
	r._build()
	return r


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0 else 0)
	s.set_corner_radius_all(radius)
	return s


## a button that asks first: the 1st press only changes its text to `confirm`, the 2nd runs (the web's secondTap)
static func second_press(c: Control, confirm: String) -> bool:
	if c.has_meta("armed"):
		return true
	c.set_meta("armed", true)
	if c is Button:
		(c as Button).text = confirm
	elif c is OptionsRow:
		(c as OptionsRow)._name.text = confirm
	return false


static func _label(text: String, col: Color = INK, size: int = 20) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build() -> void:
	custom_minimum_size = Vector2(0, 44) # a finger's target
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style(false)
	focus_entered.connect(func() -> void:
		_style(true)
		described.emit(opt.label, opt.help))
	focus_exited.connect(_style.bind(false))
	mouse_entered.connect(grab_focus) # one cursor for mouse, keys and pad, as the web's hoverFocus
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	add_child(h)
	_name = _label(opt.label)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_name)
	var v := HBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 10)
	v.alignment = BoxContainer.ALIGNMENT_END
	h.add_child(v)
	_value = v
	if opt.has("run"):
		v.add_child(_label("▸", GOLD, 14))
		return
	if opt.get("switch", false):
		_text = _label("")
		v.add_child(_text)
		_switch = Control.new()
		_switch.custom_minimum_size = Vector2(50, 24)
		_switch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_switch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_switch.draw.connect(_draw_switch)
		v.add_child(_switch)
	else:
		_prev = _label("‹", GOLD)
		v.add_child(_prev)
		if opt.get("bar", false):
			_text = _label("")
			_text.custom_minimum_size = Vector2(52, 0)
			_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			v.add_child(_text)
			_slider = HSlider.new()
			_slider.min_value = 0
			_slider.max_value = 100
			_slider.step = 5
			_slider.custom_minimum_size = Vector2(128, 24)
			_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_slider.focus_mode = Control.FOCUS_NONE # the row keeps the cursor; the bar only takes a pointer's drag
			_slider.add_theme_stylebox_override("slider", _track(Color("#2c281f")))
			_slider.add_theme_stylebox_override("grabber_area", _track(PAPER))
			_slider.add_theme_stylebox_override("grabber_area_highlight", _track(PAPER))
			_slider.value_changed.connect(func(x: float) -> void:
				if int(x) != opt.read.call():
					_put(int(x)))
			v.add_child(_slider)
		else:
			var p := PanelContainer.new()
			p.add_theme_stylebox_override("panel", box(PAPER))
			p.custom_minimum_size = Vector2(200, 30)
			p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_text = _label("", DARK, 18)
			_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			p.add_child(_text)
			v.add_child(p)
		v.add_child(_label("›", GOLD))
	redraw()


static func _track(col: Color) -> StyleBoxFlat:
	var s := box(col, Color(0, 0, 0, 0), 3)
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


func _style(focused: bool) -> void:
	add_theme_stylebox_override("panel", _pad(box(Color("#2b291f"), Color("#4a4434")) if focused else box(Color(0, 0, 0, 0))))


static func _pad(s: StyleBoxFlat) -> StyleBoxFlat:
	s.content_margin_left = 14
	s.content_margin_right = 14
	return s


func _draw_switch() -> void:
	var on: bool = opt.read.call()
	var r := Rect2(Vector2.ZERO, _switch.size)
	var bg := box(ON if on else OFF, Color(0, 0, 0, 0), 12)
	_switch.draw_style_box(bg, r)
	_switch.draw_circle(Vector2(r.size.x - 12 if on else 12, r.size.y / 2), 8, PAPER)


## the value as it is now
func redraw() -> void:
	if opt.has("run"):
		return
	if opt.get("bar", false):
		_text.text = "%d%%" % opt.read.call()
		_slider.set_value_no_signal(opt.read.call())
		return
	var now: Variant = opt.read.call()
	for pair in opt["values"]:
		if pair[0] == now:
			_text.text = pair[1]
	if _switch:
		_switch.queue_redraw()


func _put(v: Variant) -> void:
	opt.write.call(v)
	redraw()
	Sound.play("cursor")
	changed.emit()


## the value before or after the current one, round the ends (Enter only goes forward, so the last leads to the first)
func step(dir: int) -> void:
	if opt.has("run"):
		return
	if opt.get("bar", false):
		_put(clampi(opt.read.call() + dir * 5, 0, 100))
		return
	var vals: Array = opt["values"].map(func(p: Array) -> Variant: return p[0])
	var at := vals.find(opt.read.call())
	_put(vals[posmod(at + dir, vals.size())])


func _gui_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_left") or ev.is_action_pressed("ui_right"):
		if opt.has("run"):
			return # a link has no value: left and right walk the window as any other key
		step(-1 if ev.is_action_pressed("ui_left") else 1)
		accept_event()
	elif ev.is_action_pressed("ui_accept"):
		accept_event()
		_press(1)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		accept_event()
		var x: float = ev.global_position.x
		if opt.has("run"):
			_press(1)
		elif x < _value.global_position.x:
			return # a press on the name only puts the cursor on the row
		elif _prev and x <= _prev.get_global_rect().end.x:
			step(-1)
		else:
			step(1)


func _press(dir: int) -> void:
	if opt.has("run"):
		Sound.play("confirm")
		opt.run.call(self)
	else:
		step(dir)

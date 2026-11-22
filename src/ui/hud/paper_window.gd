class_name PaperWindow
extends ColorRect
## A parchment window over the darkened battle (port of the web game's window3d/status3d.ts and note3d.ts): the head band
## with the title, the rows in two columns the way FFT lays a unit's numbers out (label left, value right; one column for
## a list of paragraphs), and the buttons on the foot, 44 px tall. Status, a unit's abilities, the unit peek and the
## battle's menu open in it. Closing frees it and calls `on_close`.

const REF_W := 1100.0 # reference px, as status-view.ts REF
const PLAIN_W := 640.0
const HEAD := 42.0
const PAD := 22.0
const GAP := 36.0
const LABEL := 230.0

var on_close := Callable()
var _first: Button


## `rows`: [[label, value]] (an empty label: one column of paragraphs); `buttons`: [[text, callable]], each closing the
## window itself when it should
static func open(parent: Control, title: String, rows: Array, buttons: Array, on_close: Callable = Callable()) -> PaperWindow:
	var w := PaperWindow.new()
	w.on_close = on_close
	parent.add_child(w)
	w._build(title, rows, buttons)
	return w


func _build(title: String, rows: Array, buttons: Array) -> void:
	color = Color(0, 0, 0, 0.55)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var plain := rows.size() < 2 or rows.any(func(r: Array) -> bool: return r[0] == "")
	var w := HudSkin.px(PLAIN_W if plain else REF_W)
	var pad := HudSkin.px(PAD)
	var col_w := w - 2 * pad if plain else (w - 2 * pad - HudSkin.px(GAP)) / 2
	var body := Control.new()
	body.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(body)
	var head := HudSkin.px(HEAD)
	var half := rows.size() if plain else ceili(rows.size() / 2.0)
	var ys := [head + pad / 2, head + pad / 2]
	for i in rows.size():
		var col := 0 if i < half else 1
		var x := pad + col * (col_w + HudSkin.px(GAP))
		var label_w := 0.0 if plain else minf(HudSkin.px(LABEL), col_w / 2)
		var row_h := HudSkin.px(46)
		if not plain:
			var l := HudSkin.label(rows[i][0], 22, HudSkin.INK_SOFT)
			l.position = Vector2(x, ys[col] + HudSkin.px(8))
			body.add_child(l)
		var v := HudSkin.label(rows[i][1], 22, HudSkin.INK)
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.size.x = col_w - label_w
		v.position = Vector2(x + label_w, ys[col] + HudSkin.px(8))
		body.add_child(v)
		row_h = maxf(row_h, v.get_minimum_size().y + HudSkin.px(14))
		ys[col] += row_h
	var y: float = maxf(ys[0], ys[1]) + pad / 2
	var actions := VBoxContainer.new()
	actions.position = Vector2(pad, y)
	actions.size.x = w - 2 * pad
	actions.add_theme_constant_override("separation", 6)
	body.add_child(actions)
	for a in buttons:
		actions.add_child(_button(a[0], a[1]))
	if buttons.size():
		y += actions.get_combined_minimum_size().y + pad
	var h := y + HudSkin.px(8)
	var size_v := Vector2(w, h)
	var paper := Control.new()
	paper.mouse_filter = MOUSE_FILTER_IGNORE
	paper.size = size_v
	paper.material = HudSkin.paper(size_v, HEAD, 0.0, 0.0, Vector3(0, 1, 0), 7.1)
	paper.draw.connect(func() -> void: HudSkin.draw_paper(paper, size_v))
	add_child(paper)
	move_child(paper, 0)
	var t := HudSkin.label(title, 24, HudSkin.INK_SOFT)
	t.position = Vector2(HudSkin.px(12), (head - t.get_minimum_size().y) / 2)
	body.add_child(t)
	var at := (Vector2(1280, 720) - size_v) / 2
	at.y = maxf(at.y, 8)
	paper.position = at
	body.position = at
	if _first:
		_first.call_deferred("grab_focus")


func _button(text: String, run: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", HudSkin.font())
	b.add_theme_font_size_override("font_size", HudSkin.text(26))
	for st in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(HudSkin.LIT, 0.0) if st == "normal" else HudSkin.LIT
		s.border_color = Color(HudSkin.EDGE, 0.5)
		s.border_width_bottom = 1
		s.content_margin_left = 12
		b.add_theme_stylebox_override(st, s)
		b.add_theme_color_override("font_" + ("color" if st == "normal" else st + "_color"), HudSkin.INK)
	b.pressed.connect(func() -> void:
		run.call())
	if _first == null:
		_first = b
	return b


## closes the window (the buttons that go elsewhere call it first)
func close() -> void:
	queue_free()
	if on_close.is_valid():
		on_close.call()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		close()
		accept_event()


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

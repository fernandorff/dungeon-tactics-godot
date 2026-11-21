class_name Notice
extends Control
## A notice window (port of note.ts and window3d/note3d.ts with note-view.ts): the screen darkened, one parchment sheet
## in the middle with the title on its head, then a legend of marks (the map's seals), paragraphs, a figure (the gold)
## and one to three plaques, the gold one in focus with the glove, and the keys on its foot. Esc, the pad's B, a tap
## outside and the ✕ close it unless it is `fixed`; the arrows go to the plaque seen that way.
## A note is {title, legend?: [[{glyph, look, kind}, text]], text?: [String], figure?: [label, value],
## buttons: [[label, Callable]], on_back?: Callable, fixed?: bool}.

# px of the 1920x1080 reference; the head and the foot are the Status sheet's
const W := 780.0
const HEAD := 42.0
const FOOT := 48.0
const PAD := 30.0
const GAP := 16.0
const MARK := 40.0
const MARK_GAP := 14.0
const BUTTON := Vector2(320, 66) # 66: never under the game's 44 px tap at the 1280 px window
const ROW := 24 # the rows' text

var n: Dictionary
var _root := Control.new()
var _sheet: Rect2
var _rows: Array = [] # [kind, y, h] of each legend row, paragraph and the figure, from the sheet's top
var _buttons: Array = []
var _from: Control # the focus before, given back on closing


static func open(parent: Control, note: Dictionary) -> Notice:
	var w := Notice.new()
	w.n = note
	parent.add_child(w)
	return w


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_from = get_viewport().gui_get_focus_owner()
	_root.mouse_filter = MOUSE_FILTER_IGNORE
	_root.size = MapLayout.SCREEN
	_root.draw.connect(_paint)
	add_child(_root)
	_measure()
	var inner := W - 2 * PAD
	var count: int = n.buttons.size()
	var bw := minf(BUTTON.x, (inner - (count - 1) * GAP) / count)
	var left := _sheet.position.x + (W - count * bw - (count - 1) * GAP) / 2
	for i in count:
		var b := _button(Rect2(left + i * (bw + GAP), _sheet.position.y + _rows.back()[1], bw, BUTTON.y), n.buttons[i][1])
		_buttons.append(b)
	if not n.get("fixed", false):
		_button(Rect2(_sheet.end.x - 66, _sheet.position.y, 66, 66), _back) # the ✕: a 44 px square at the window's size
	resized.connect(_fit)
	_fit()
	_buttons[0].grab_focus()


func _button(r: Rect2, run: Callable) -> Button:
	var b := Button.new()
	b.flat = true
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.position = r.position
	b.size = r.size
	b.focus_mode = FOCUS_ALL
	b.mouse_entered.connect(b.grab_focus)
	b.focus_entered.connect(_root.queue_redraw)
	b.pressed.connect(func() -> void:
		close()
		if run.is_valid():
			run.call())
	_root.add_child(b)
	return b


## the rows' heights as they wrap, and the sheet's box centred on the screen
func _measure() -> void:
	var f := Paper.para_font()
	var inner := W - 2 * PAD
	var y := HEAD + PAD / 2
	for e in n.get("legend", []):
		var h := maxf(MARK, f.get_multiline_string_size(e[1], HORIZONTAL_ALIGNMENT_LEFT, inner - MARK - MARK_GAP, ROW).y)
		_rows.append(["legend", y, h])
		y += h + GAP / 2
	if n.get("legend", []).size():
		y += GAP / 2
	for p in n.get("text", []):
		var h := f.get_multiline_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, inner, ROW).y
		_rows.append(["text", y, h])
		y += h + GAP
	if n.has("figure"):
		_rows.append(["figure", y, MARK])
		y += MARK + GAP
	_rows.append(["buttons", y, BUTTON.y])
	var h := y + BUTTON.y + PAD / 2 + FOOT
	_sheet = Rect2((MapLayout.SCREEN.x - W) / 2, maxf(0, (MapLayout.SCREEN.y - h) / 2), W, h)


func _fit() -> void:
	var k := minf(size.x / MapLayout.SCREEN.x, size.y / MapLayout.SCREEN.y)
	_root.scale = Vector2(k, k)
	_root.position = (size - MapLayout.SCREEN * k) / 2


func _paint() -> void:
	var ci := _root
	ci.draw_rect(Rect2(Vector2(-4000, -4000), Vector2(10000, 10000)), Color(0.03, 0.04, 0.05, 0.72))
	Paper.sheet(ci, _sheet, HEAD, FOOT)
	var o := _sheet.position
	Paper.say(ci, n.title, o + Vector2(10, HEAD / 2), 24, Paper.INK_SOFT)
	if not n.get("fixed", false):
		Paper.say(ci, "✕", Vector2(_sheet.end.x - 22, o.y + HEAD / 2), 24, Paper.INK_SOFT, 0, INF, Paper.symbols())
	var k := 0
	for r in _rows:
		var top: Vector2 = o + Vector2(PAD, r[1])
		match r[0]:
			"legend":
				var e: Array = n.legend[k]
				k += 1
				var m: Dictionary = e[0]
				var mid := top + Vector2(MARK, MARK) / 2
				if m.look == "flag":
					Paper.flag(ci, top + Vector2(MARK * 0.3, MARK * 0.1), MARK * 0.8)
				else:
					Paper.seal(ci, mid, MARK, m.look, m.get("kind", "room"), m.glyph)
				Paper.para(ci, e[1], top + Vector2(MARK + MARK_GAP, (MARK - ROW * 1.3) / 2), W - 2 * PAD - MARK - MARK_GAP, ROW, Paper.INK)
			"text":
				Paper.para(ci, n.text[_rows.find(r) - n.get("legend", []).size()], top, W - 2 * PAD, ROW, Paper.INK)
			"figure":
				ci.draw_rect(Rect2(top, Vector2(W - 2 * PAD, 1)), Color(0.2, 0.17, 0.1, 0.16))
				Paper.say(ci, n.figure[0], top + Vector2(0, MARK / 2), ROW, Paper.INK_SOFT)
				Paper.say(ci, n.figure[1], top + Vector2(W - 2 * PAD, MARK / 2), 30, Paper.INK, 1)
	var focus := get_viewport().gui_get_focus_owner()
	for i in _buttons.size():
		var b: Button = _buttons[i]
		var r := Rect2(b.position, b.size)
		Paper.box(ci, r, Paper.GOLD if b == focus else Color(Paper.PLATE, 0.96), 6, Paper.EDGE if b == focus else Paper.LINE, 2 if b == focus else 1)
		Paper.say(ci, n.buttons[i][0], r.get_center(), 24, Paper.TEXT, 0, r.size.x - 24)
		if b == focus:
			Paper.glove(ci, r if _buttons.size() == 1 else Rect2(r.position + Vector2(45, 0), r.size), 56)
	# the foot: what the keys do
	var keys := Texts.t("Enter  Escolher", "Enter  Choose")
	if not n.get("fixed", false):
		keys += Texts.t("      Esc  Fechar", "      Esc  Close")
	Paper.say(ci, keys, Vector2(_sheet.end.x - 14, _sheet.end.y - FOOT / 2), 22, Paper.INK_SOFT, 1)


func close() -> void:
	if is_queued_for_deletion():
		return
	queue_free()
	if is_instance_valid(_from) and _from.is_inside_tree():
		_from.grab_focus()


func _back() -> void:
	var then: Callable = n.get("on_back", Callable())
	if then.is_valid():
		then.call()


func _gui_input(ev: InputEvent) -> void:
	# a tap outside the sheet closes it, as Esc
	if ev is InputEventMouseButton and ev.pressed and not n.get("fixed", false):
		var at: Vector2 = (ev.position - _root.position) / _root.scale.x
		if not _sheet.has_point(at):
			close()
			_back()
			accept_event()


func _input(ev: InputEvent) -> void:
	if not ev.is_pressed() or ev.is_echo() and not ev.is_action("ui_left") and not ev.is_action("ui_right"):
		return
	if ev.is_action("ui_cancel"):
		if not n.get("fixed", false):
			close()
			_back()
		get_viewport().set_input_as_handled()
		return
	for d in [["ui_left", Vector2.LEFT], ["ui_right", Vector2.RIGHT], ["ui_up", Vector2.UP], ["ui_down", Vector2.DOWN]]:
		if ev.is_action(d[0]):
			var at := _buttons.find(get_viewport().gui_get_focus_owner())
			var boxes: Array = _buttons.map(func(b: Button) -> Rect2: return Rect2(b.position, b.size))
			_buttons[0 if at < 0 else MapLayout.next_spot(boxes, at, d[1])].grab_focus()
			get_viewport().set_input_as_handled()
			return

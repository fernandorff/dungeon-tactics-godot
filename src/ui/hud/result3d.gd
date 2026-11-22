class_name Result3d
extends RefCounted
## The end of a battle drawn in 3D (port of the web game's result3d/result3d.ts), a screen of the shared 3D layer, laid
## out like FFT: The Ivalice Chronicles' victory screen: the battle darkened, the title in capitals over a hairline, a
## line under it, and a dark band across the page with what the battle gave and each hero's row on the left and who did
## the most on the right. A defeat is the same screen, darker, its title in a cold red. Nothing here decides anything:
## the battle's end hands over the board (ResultView.of's input plus `actions` [[label, Callable]] and `back`),
## ResultView says what to show and ResultLayout where. Input: a transparent button over each drawn one (focus, Enter,
## the arrows, the mouse); Esc takes `back`; the glove points at the button in focus.

# style.css --ui3d-result-*
const C := {
	"title": Color("#fdebb4"), "lost": Color("#c98f7f"), "note": Color("#ddf3b5"), "text": Color("#dcd5ac"),
	"soft": Color("#a8a184"), "veil": Color("#070908"), "band": Color("#151207"), "plate": Color("#1e1c18"),
	"line": Color("#736353"),
}
const FACE: Shader = preload("res://src/ui/ui3d/face3d.gdshader")
const TEXT_ORDER := 64 # over the plates (62); its halo in 63

var _layer: Layer3d
var _root := Node3D.new()
var _host := Control.new()
var _glove := Menu3dIcon.new("", "glove", 0.035)
var _open := Spring3d.new()
var _gx := Spring3d.new()
var _board := {}
var _view := {}
var _at := {}
var _parts: Array = [] # {mesh, a, at, y, rise}: its full opacity, when it comes in (0 first), how far above it starts
var _buttons: Array = [] # each button's plate material
var _focus := 0


func _init(layer: Layer3d) -> void:
	_layer = layer
	layer.flat.add_child(_root)
	_glove.model.rotation = Vector3(0.2, -0.3, 0)
	_glove.group.visible = false
	layer.deep.add_child(_glove.group)
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.hits.add_child(_host)
	layer.add(self)


func shown() -> bool:
	return not _board.is_empty()


## the end of a battle: opens over whatever showed before
func show(board: Dictionary) -> void:
	hide()
	_board = board
	_view = ResultView.of(board, board.actions.map(func(a: Array) -> String: return a[0]))
	_open.land(0.0)
	_open.to = 1.0
	_focus = 0 # the board lists the primary first: Enter takes it
	_build()
	_gx.land(_at.buttons[0].position.x if not _at.buttons.is_empty() else 0.0)


func hide() -> void:
	_board = {}
	_view = {}
	_at = {}
	_clear()
	for c in _host.get_children():
		c.queue_free()
	_glove.group.visible = false
	_layer.wake()


func resize() -> void:
	if not _view.is_empty():
		_build()


func _add(mesh: GeometryInstance3D, a: float, at: float, rise: float = 0.0) -> GeometryInstance3D:
	_parts.append({"mesh": mesh, "a": a, "at": at, "y": mesh.position.y, "rise": rise})
	Panel3d.alpha(mesh, 0.0)
	_root.add_child(mesh)
	return mesh


func _plate(b: Rect2, color: Color, a: float, at: float, order: int = 61) -> MeshInstance3D:
	var mat := Panel3d.band(b.size.x, b.size.y, _layer.s, Vector3(color.r, color.g, color.b))
	var m := Panel3d.quad(mat, b.position.x, b.position.y, b.size.x, b.size.y, order)
	_add(m, a, at)
	return m


## text in the theme's serif, `size` in px of the 1080p layout and never under the game's 16 px
func _text(words: String, size: float, color: Color, wrap: float = -1.0) -> Label3D:
	var px := _layer.px(size)
	var line := maxf(ResultLayout.REF.noteLine * _layer.s, px * 1.3) if wrap > 0 else -1.0
	return Text3d.label(_layer, words, px, color, wrap, line)


## a text with its `align` edge on x and its middle on `mid`, shrunk to `room`
func _put(m: Label3D, x: float, mid: float, align: String, at: float, room: float = INF, rise: float = 0.0) -> Label3D:
	var k := minf(1.0, room / Text3d.w(m))
	m.scale = Vector3.ONE * k
	var w := Text3d.w(m)
	var left := x if align == "left" else (x - w if align == "right" else x - w / 2)
	if k == 1.0:
		Text3d.put(m, left + w / 2, mid, _layer.dpr)
	else:
		m.position = Vector3(left + w / 2, -mid, 0)
	Text3d.order(m, TEXT_ORDER)
	_add(m, 1.0, at, rise)
	return m


static func _middle(b: Rect2) -> float:
	return b.position.y + b.size.y / 2


func _build() -> void:
	var v := _view
	if v.is_empty():
		return
	_clear()
	var s := _layer.s
	var page := _layer.page
	var L := ResultLayout.layout(_layer.stage, page.x, v.heroes.size(), v.spoils.size(), v.actions.size())
	_at = L
	var won: bool = v.won
	var REF := ResultLayout.REF

	# the battle darkened (darker on a defeat), the band across the page and its two lines
	_plate(Rect2(-8, -8, page.x + 16, page.y + 16), C.veil, 0.8 if won else 0.92, 0.0, 60)
	var band: Rect2 = L.band
	_plate(Rect2(-8, band.position.y, band.size.x + 16, band.size.y), C.band, 0.72, 0.1)
	for y in [band.position.y, band.end.y - 2 * s]:
		_plate(Rect2(-8, y, band.size.x + 16, 2 * s), C.line, 0.9, 0.1, 62)
	var rule: Rect2 = L.rule
	_put(_text(v.title, REF.title, C.title if won else C.lost), L.title.x, L.title.y, "centre", 0.0, rule.size.x, 28 * s)
	_plate(rule, C.line, 0.9, 0.1)
	var note := _text(v.note, REF.note, C.note if won else C.soft, L.note.w)
	_put(note, L.note.x, L.note.y + Text3d.h(note) / 2, "centre", 0.15)

	# what the battle gave and each hero's row, under the left plate
	var left: Rect2 = L.left
	_plate(left, C.plate, 0.95, 0.25, 62)
	_put(_text(v.heads[0], REF.head, C.text), left.position.x + left.size.x / 2, _middle(left), "centre", 0.25)
	if not v.heroes.is_empty():
		_put(_text(v.did[0], REF.did, C.soft), L.did.dmg, L.did.y, "right", 0.3)
		_put(_text(v.did[1], REF.did, C.soft), L.did.kills, L.did.y, "right", 0.3)
	for i in v.heroes.size():
		_hero_row(v.heroes[i], L.heroes[i], L.faces[i], L, 0.3 + 0.05 * (i + 1))
	for i in v.spoils.size():
		var b: Rect2 = L.spoils[i]
		var at: float = 0.3 + 0.05 * i
		var key := _put(_text(v.spoils[i][0], REF.row, C.soft), b.position.x, _middle(b), "left", at, b.size.x * 0.75)
		_put(_text(v.spoils[i][1], REF.row, C.text), b.end.x, _middle(b), "right", at, b.size.x - Text3d.w(key) - 16 * s)

	# who did the most, under the right plate
	if v.mvp != null:
		var right: Rect2 = L.right
		_plate(right, C.plate, 0.95, 0.25, 62)
		_put(_text(v.heads[1], REF.head, C.text), L.mvp.x, _middle(right), "centre", 0.25)
		_put(_text(v.mvp.name, REF.name, C.text), L.mvp.x, L.mvp.name, "centre", 0.4, right.size.x)
		_put(_text(v.mvp.line, REF.row, C.soft), L.mvp.x, L.mvp.line, "centre", 0.45, right.size.x)
		_plate(L.mvp.rule, C.line, 0.9, 0.45, 62)

	# the buttons, bottom right, each under its transparent button
	for i in v.actions.size():
		var b: Rect2 = L.buttons[i]
		_buttons.append(_plate(b, C.plate, 0.95, 0.5, 62).material_override)
		_put(_text(v.actions[i], REF.button, C.text), b.position.x + b.size.x / 2, _middle(b), "centre", 0.5, b.size.x - 24 * s)
	_hits(L.buttons)
	_layer.wake()


## each hero: face, name, class and life, then what it did under the two columns' names
func _hero_row(h: Dictionary, b: Rect2, face: Rect2, L: Dictionary, at: float) -> void:
	var s := _layer.s
	var REF := ResultLayout.REF
	var fell: bool = h.tone == "fell"
	var f := _face(h.def, h.face, face, fell)
	if f:
		_add(f, 1.0, at)
	# the numbers first: the words before them take the room that is left, the name the last to shrink
	_put(_text(h.kills, REF.row, C.soft if fell else C.text), L.did.kills, _middle(b), "right", at)
	_put(_text(h.dmg, REF.row, C.soft if fell else C.text), L.did.dmg, _middle(b), "right", at)
	var x: float = b.position.x + L.who
	var end: float = L.did.dmg - 70 * s # the damage column's own room
	for w: Array in [[h.name, REF.row, C.soft if fell else C.text], [h.cls, REF.did, C.soft], [h.life, REF.row, C.soft], [h.line, REF.did, C.note if h.tone == "gain" else C.soft]]:
		if w[0] == "" or end - x < 24 * s:
			continue
		x += Text3d.w(_put(_text(w[0], w[1], w[2]), x, _middle(b), "left", at, end - x)) + 10 * s


## a unit's face on its painted sheet's frame; null without a sheet
## shortcut: the web falls back to the top of the rendered portrait; every hero has a sheet today
func _face(def: String, expr: String, b: Rect2, grey: bool) -> MeshInstance3D:
	var id := Portraits.sheet_of(def)
	if id == "":
		return null
	var tex: Texture2D = load("res://assets/faces/%s.webp" % id)
	var frames := maxi(1, roundi(float(tex.get_width()) / tex.get_height()))
	var mat := ShaderMaterial.new()
	mat.shader = FACE
	mat.set_shader_parameter("map", tex)
	mat.set_shader_parameter("uv", Vector4(float(Portraits.frame_of(Content.data.faces[id], expr)) / frames, 0, 1.0 / frames, 1))
	mat.set_shader_parameter("grey", 1.0 if grey else 0.0)
	return Panel3d.quad(mat, b.position.x, b.position.y, b.size.x, b.size.y, 63)


## the transparent buttons over the drawn ones: the focus, Enter, the arrows, the mouse; Esc goes back
func _hits(boxes: Array) -> void:
	for c in _host.get_children():
		c.queue_free()
	var made: Array[Button] = []
	for i in boxes.size():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		b.tooltip_text = _view.actions[i]
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.position = boxes[i].position
		b.size = boxes[i].size
		b.focus_entered.connect(func() -> void:
			_focus = i
			_layer.wake())
		b.mouse_entered.connect(b.grab_focus)
		b.pressed.connect(_board.actions[i][1])
		b.gui_input.connect(func(ev: InputEvent) -> void:
			if ev.is_action_pressed("ui_cancel") and _board.has("back"):
				b.accept_event()
				_board.back.call()
			elif ev is InputEventKey and ev.echo:
				b.accept_event()) # a held Enter (the way to speed the enemy up) would press it unread
		_host.add_child(b)
		made.append(b)
	if not made.is_empty():
		made[_focus].call_deferred("grab_focus")


func frame(dt: float, t: float) -> bool:
	if _at.is_empty():
		return false
	var s: float = _at.s
	var still := _layer.still
	_open.move(dt, still, 170, 18) # under-damped: the title drops a little past its place and settles
	var o := _open.x
	for p: Dictionary in _parts:
		Panel3d.alpha(p.mesh, p.a * clampf((o - p.at) * 4, 0.0, 1.0))
		p.mesh.position.y = p.y + p.rise * (1 - o)
	# the button in focus is lit and the glove points at it, sliding from one to the other
	for i in _buttons.size():
		var c: Color = C.line if i == _focus else C.plate
		_buttons[i].set_shader_parameter("color", Vector3(c.r, c.g, c.b))
	var b: Variant = _at.buttons[_focus] if _focus < _at.buttons.size() else null
	var on := clampf((o - 0.5) * 4, 0.0, 1.0) if b != null else 0.0
	_glove.group.visible = on > 0.004
	if b != null:
		_gx.to = b.position.x - ResultLayout.REF.hand / 2 * s
		_gx.move(dt, still, 330, 25)
		var nudge := 0.0 if still else sin(t * 5.2) * 3.2 * s
		_glove.group.position = Vector3(_gx.x + nudge, -(b.position.y + b.size.y / 2), 300)
		_glove.group.scale = Vector3.ONE * maxf(1e-5, ResultLayout.REF.hand * s * on)
	return not still # the glove sways for as long as the screen shows


func _clear() -> void:
	for p: Dictionary in _parts:
		p.mesh.queue_free()
	_parts = []
	_buttons = []

class_name Menu3dColumn
extends RefCounted
## A column of the 3D command menu (port of the web game's menu3d/column.ts): the menu or the Agir list, as a parchment
## panel with a row per command or ability, each with its text and a low-poly icon standing on a plate. Rebuilt only
## when what it shows changes; the focus and every motion are state of the frame: springs for the opening and the focus
## band, eases for the glow and the lift.

const MOVE_BLUE := Vector3(0.29, 0.56, 0.89)

var ui := Node3D.new()
var icons := Node3D.new()
var open := Spring3d.new()
var focus_y := Spring3d.new()
var shift := Spring3d.new() # px off its place, settling to 0: a list sliding over from the next column
var want := 0.0 # 1 open, 0 closed; `open` follows it once `hold` runs out
var hold := 0.0 # seconds a confirmed column stays up, so its flash is seen before it leaves
var flash := 0.0
var focus := -1
var glow := 0.0 # how lit the focus band is, eased to 1 as the column opens
var x := 0.0
var y := 0.0
var data := {} # {title, w, h, rows}: what it last showed, kept while it closes
var _key := ""
var _paper: ShaderMaterial
var _texts: Array[GeometryInstance3D] = []
var _rows: Array = [] # {label, x, icon}
var _lift: Array[float] = []
var _s := 1.0
var _plate: String
var _order: int
var _z: float
var _seed: float


func _init(plate: String, order: int, z: float, seed: float) -> void:
	_plate = plate
	_order = order
	_z = z
	_seed = seed


## the focused row's middle, from the panel's top
func row_y() -> float:
	return 0.0 if focus < 0 else (MenuLayout.HEAD + (focus + 0.5) * MenuLayout.ROW) * _s


## text in the theme's serif; `size` in px of the 1080p layout, never under the page's text floor
static func label(layer: Layer3d, s: float, text: String, size: float, color: Color, width: float = -1.0, line: float = -1.0) -> Label3D:
	var px:= StageLayout.text_px(size, s)
	return Text3d.label(layer, text, px, color, width, maxf(line * s, px * 1.3) if line > 0 else -1.0)


func _put(m: Label3D, at_x: float, mid: float) -> Label3D:
	m.position = Vector3(at_x + Text3d.w(m) / 2, -mid, 0)
	Text3d.order(m, _order + 4) # over the paper and the gauge's two bands, its halo clear of both
	_texts.append(m)
	ui.add_child(m)
	return m


## `d`: {title, w, h, rows}; `s`: the columns' scale (MenuLayout `cs`)
func set_data(d: Dictionary, layer: Layer3d, s: float) -> void:
	_s = s
	var key:= str([d, s, layer.dpr, Texts.current()])
	data = d
	if key == _key:
		return
	clear()
	_key = key
	var pad:= 44 * s
	_paper = Panel3d.paper(d.w, d.h, pad, s, _seed, MenuLayout.HEAD, 0.0, MenuLayout.ICON_W, Vector3(MenuLayout.HEAD, MenuLayout.ROW, d.rows.size()))
	ui.add_child(Panel3d.quad(_paper, -pad, -pad, d.w + 2 * pad, d.h + 2 * pad, _order))
	_put(label(layer, s, d.title, 24, HudSkin.INK_SOFT), 10 * s, (MenuLayout.HEAD / 2 - 1) * s)
	for i: int in d.rows.size():
		var r: Dictionary = d.rows[i]
		var mid:= (MenuLayout.HEAD + (i + 0.5) * MenuLayout.ROW) * s
		# a greyed row's note says what is missing: it stays readable (soft ink), only the name fades. `below`: the note is
		# a line under the name (the Agir list's reason), so a long one never pushes the name out
		var below: bool = r.below and r.note != ""
		var left:= (MenuLayout.ICON_W + 8) * s
		var width: float = d.w - (MenuLayout.ICON_W + 8 + 7 + 12) * s
		var note: Label3D = label(layer, s, r.note, 18 if below else 20, HudSkin.INK_SOFT) if r.note != "" else null
		if note and below:
			note.scale *= minf(1.0, width / Text3d.w(note))
		if note:
			_put(note, left if below else d.w - 12 * s - Text3d.w(note), mid + 13 * s if below else mid + s)
		# a long name beside a note shrinks to the room left (a small page: the text floor widens the text, not the row)
		var name:= label(layer, s, r.label, 26 if below else 30, HudSkin.INK_OFF if r.off else HudSkin.INK)
		var room:= width - (Text3d.w(note) + 10 * s if note and not below else 0.0)
		name.scale *= minf(1.0, room / Text3d.w(name))
		var text:= _put(name, left, mid - 9 * s if below else mid)
		if r.gauge >= 0.0:
			# Move's bar along the row's foot: the track in the panel's shade, the half tiles left in the walk marks' blue
			var by:= mid + 17 * s
			var bh:= 5 * s
			_bar(left, by, width, bh, s, Panel3d._v3(HudSkin.SHADE), _order + 1)
			if r.gauge > 0:
				_bar(left, by, width * clampf(r.gauge, 0.0, 1.0), bh, s, MOVE_BLUE, _order + 2)
		var icon:= Menu3dIcon.new(_plate, r.icon)
		icon.group.position = Vector3(MenuLayout.ICON_W * s / 2, -mid, 0)
		icons.add_child(icon.group)
		_rows.append({"label": text, "x": text.position.x, "icon": icon})
	_lift.resize(d.rows.size()) # each row keeps its lift across a rebuild, as the web's lift.length = n


func _bar(bx: float, by: float, bw: float, bh: float, s: float, color: Vector3, order: int) -> void:
	var m := Panel3d.quad(Panel3d.band(bw, bh, s, color), bx, by, bw, bh, order)
	_texts.append(m)
	ui.add_child(m)


## `slide`: px to the left of its place while closed (the submenu comes out of the menu); `rise`: how far it stands off
## the screen (shadow); `active`: its focus is the one the player moves
func frame(dt: float, time: float, layer: Layer3d, slide: float, rise: float, active: bool) -> void:
	var still:= layer.still
	if hold > 0:
		hold -= dt
	else:
		open.to = want
	open.move(dt, still, 300, 19) # under-damped: the column pops a little past its size and settles
	focus_y.to = row_y()
	focus_y.move(dt, still, 420, 30)
	shift.move(dt, still, 300, 30)
	flash = 0.0 if still else flash * exp(-dt * 9)
	var ease:= 1.0 if still else 1.0 - exp(-dt * 14)
	glow += (1.0 - glow) * ease
	var o:= open.x
	var a:= clampf(o * 2.2, 0.0, 1.0)
	var size:= 0.86 + 0.14 * o
	var s:= _s
	ui.visible = a > 0.004 and not data.is_empty()
	icons.visible = ui.visible
	if data.is_empty() or _paper == null:
		return
	# scaled about the middle of its left edge, where it hangs from the menu
	var left:= x + shift.x - slide * (1 - o)
	var top: float = y + data.h / 2 * (1 - size) + 10 * s * (1 - clampf(o, 0.0, 1.0))
	ui.position = Vector3(left, -top, 0)
	icons.position = Vector3(left, -top, _z)
	ui.scale = Vector3.ONE * size
	icons.scale = Vector3.ONE * size
	_paper.set_shader_parameter("alpha", a)
	_paper.set_shader_parameter("lift", rise * clampf(o, 0.0, 1.0))
	_paper.set_shader_parameter("time", time)
	_paper.set_shader_parameter("focus", Vector4(focus_y.x / s, MenuLayout.ROW, 0.0 if focus < 0 else glow, flash))
	for m in _texts:
		Panel3d.alpha(m, a)
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var on := 1.0 if i == focus else 0.0
		_lift[i] += (on * (1.0 if active else 0.0) - _lift[i]) * ease
		var lift:= _lift[i]
		row.label.position.x = row.x + 7 * s * lift
		# the focused icon rises off its plate, sways and bobs; a confirmed one jumps
		var hit:= flash * on
		var icon: Menu3dIcon = row.icon
		icon.group.scale = Vector3.ONE * maxf(1e-5, MenuLayout.ICON * s * clampf(o * 1.5, 0.0, 1.0) * (1 + 0.18 * lift + 0.3 * hit))
		icon.model.rotation.y = Menu3dIcon.REST.y + sin(time * 2.6) * 0.62 * lift
		icon.model.position.y = 0.0 if still else 0.05 * lift * sin(time * 5.2)
		icon.tone(1.0 if data.rows[i].off else 0.0, hit * 0.55)


## the row in focus lands where it is, lit: a column opens with its row already chosen
func settle_focus() -> void:
	focus_y.land(row_y())
	glow = 1.0


func busy() -> bool:
	return hold > 0 or not open.settled() or not focus_y.settled() or not shift.settled() or flash > 0.01


func clear() -> void:
	for row in _rows:
		row.icon.dispose()
	for c in ui.get_children():
		ui.remove_child(c)
		c.queue_free()
	_rows = []
	_texts = []
	_paper = null
	_key = ""

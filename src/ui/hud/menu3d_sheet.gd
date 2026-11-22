class_name Menu3dSheet
extends RefCounted
## The ability sheet of the 3D command menu (port of the web game's menu3d/sheet.ts): who has the ability on the head,
## its icon turning on its tile, its name, and one page of its numbers at a time under the page's title, with the page
## counter on the foot. Places are px of the 1920x1080 layout times the page's scale.

var ui := Node3D.new()
var icons := Node3D.new()
var open := Spring3d.new()
var page := Spring3d.new() # counts turns without wrapping, so the last page slides on to the first
var want := 0.0
var _at := 0 # the page it is going to
var _count := 1
var _kick := 0.0 # 1 when another ability took the sheet, fading: the icon jumps and the name settles in
var _key := ""
var _paper: ShaderMaterial
var _fixed: Array[GeometryInstance3D] = [] # bands and the head's text: they only fade with the sheet
var _name: Label3D
var _pages: Array = [] # {m, x, i}
var _counter: Array[Label3D] = []
var _icon: Menu3dIcon
var _emblem: Menu3dIcon


## `d`: MenuView.sheet's {owner, name, icon, page, pages}
func set_data(d: Dictionary, layer: Layer3d) -> void:
	var s:= layer.s
	var what := d.duplicate()
	what.erase("page")
	var key:= str([what, s, layer.dpr, Texts.current()])
	# another ability opens on the page asked for; the same one turns to it
	_count = d.pages.size()
	page.to += Spring3d.page_step(_at, d.page, _count)
	_at = d.page
	if key == _key:
		return
	page.land()
	_kick = 1.0 if _key != "" else 0.0
	clear()
	_key = key
	var r: Dictionary = StageLayout.REGIONS.detail
	var w: float = r.w * s
	var h: float = r.h * s
	var pad:= 44 * s
	_paper = Panel3d.paper(w, h, pad, s, 5.3, 47, MenuLayout.SHEET_FOOT)
	ui.add_child(Panel3d.quad(_paper, -pad, -pad, w + 2 * pad, h + 2 * pad, 30))
	_band(117, 60, 267, 46, s, HudSkin.SHADE) # under the name
	_band(16, 167, 368, 33, s, HudSkin.BAND) # under the page's title
	_fixed.append(_put(Menu3dColumn.label(layer, s, d.owner, 25, HudSkin.INK_SOFT), 52, 23, s))
	_name = _put(Menu3dColumn.label(layer, s, d.name, 28, HudSkin.INK), 126, 83, s)
	for i: int in d.pages.size():
		var p: Dictionary = d.pages[i]
		# on the darkest band only the full ink reads (4.9:1; the soft one 3.6:1)
		var title:= _put(Menu3dColumn.label(layer, s, p.title, 21, HudSkin.INK), 24, 183.5, s)
		var body:= Menu3dColumn.label(layer, s, p.text, 25, HudSkin.INK, 356 * s, 39)
		_put(body, 20, 208 + Text3d.h(body) / s / 2, s)
		_pages.append({"m": title, "x": title.position.x, "i": i})
		_pages.append({"m": body, "x": body.position.x, "i": i})
		var n:= Menu3dColumn.label(layer, s, "‹  %d / %d  ›" % [i + 1, d.pages.size()], 22, HudSkin.INK_SOFT)
		_counter.append(_put(n, 200 - Text3d.w(n) / s / 2, 541, s))
	_icon = Menu3dIcon.new("tile", d.icon)
	_icon.group.position = Vector3(61 * s, -107 * s, 0)
	_emblem = Menu3dIcon.new("", "gem")
	_emblem.group.position = Vector3(29 * s, -23 * s, 0)
	icons.add_child(_icon.group)
	icons.add_child(_emblem.group)


func _band(bx: float, by: float, bw: float, bh: float, s: float, color: Color) -> void:
	var m := Panel3d.quad(Panel3d.band(bw * s, bh * s, s, Panel3d._v3(color)), bx * s, by * s, bw * s, bh * s, 31)
	_fixed.append(m)
	ui.add_child(m)


func _put(m: Label3D, at_x: float, mid: float, s: float) -> Label3D:
	m.position = Vector3(at_x * s + Text3d.w(m) / 2, -mid * s, 0)
	Text3d.order(m, 33) # over the paper (30) and the bands (31)
	ui.add_child(m)
	return m


func frame(dt: float, time: float, layer: Layer3d, x: float, y: float) -> void:
	var still:= layer.still
	var s:= layer.s
	var n:= _count
	open.to = want
	open.move(dt, still, 210, 21)
	page.move(dt, still, 190, 21)
	_kick = 0.0 if still else _kick * exp(-dt * 8)
	var o:= open.x
	var a:= clampf(o * 1.8, 0.0, 1.0)
	ui.visible = a > 0.004 and _paper != null
	icons.visible = ui.visible
	if _paper == null:
		return
	# comes in from the right edge it sits against
	ui.position = Vector3(x + 30 * s * (1 - o), -y, 0)
	icons.position = Vector3(ui.position.x, -y, 200)
	_paper.set_shader_parameter("alpha", a)
	_paper.set_shader_parameter("lift", 0.35)
	for m in _fixed:
		Panel3d.alpha(m, a)
	if _name:
		Text3d.alpha(_name, a * (1 - 0.8 * _kick))
		_name.position.y = -(83 - 7 * _kick) * s
	# the page in view sits still; the one leaving slides out to its side and fades, the one coming slides in. A page
	# out of view is not drawn at all
	var near:= func(i: float) -> float: return fposmod(i - page.x + n / 2.0, n) - n / 2.0
	for p in _pages:
		var off: float = near.call(p.i)
		p.m.position.x = p.x + off * 90 * s
		_show(p.m, a * clampf(1 - absf(off) * 1.5, 0.0, 1.0) * (1 - 0.8 * _kick))
	for i in _counter.size():
		_show(_counter[i], a if absf(near.call(i)) < 0.5 else 0.0)
	var size:= clampf(o * 1.4, 0.0, 1.0)
	if _icon:
		_icon.group.scale = Vector3.ONE * maxf(1e-5, 90 * s * size * (1 + 0.14 * _kick))
		_icon.model.rotation.y = Menu3dIcon.REST.y + (0.0 if still else time * 1.5)
		_icon.model.position.y = 0.0 if still else 0.03 * sin(time * 2.4)
	if _emblem:
		_emblem.group.scale = Vector3.ONE * maxf(1e-5, 27 * s * size)
		_emblem.model.rotation.y = 0.0 if still else time * 0.9


static func _show(m: Label3D, v: float) -> void:
	m.visible = v > 0.004
	Text3d.alpha(m, v)


func busy() -> bool:
	return not open.settled() or not page.settled() or _kick > 0.01


func clear() -> void:
	if _icon:
		_icon.dispose()
	if _emblem:
		_emblem.dispose()
	for c in ui.get_children():
		ui.remove_child(c)
		c.queue_free()
	_fixed = []
	_pages = []
	_counter = []
	_icon = null
	_emblem = null
	_name = null
	_paper = null
	_key = ""

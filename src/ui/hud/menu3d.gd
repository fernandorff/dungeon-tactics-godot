class_name Menu3d
extends RefCounted
## The command menu drawn in 3D (port of the web game's menu3d/menu3d.ts), a screen of the shared 3D layer (Layer3d):
## the menu, the Agir primeiro list that opens over it as a cascade, the pointing glove and the action sheet, on the
## places MenuLayout gives.
##   State: nothing here decides anything. The HUD hands it each turn screen's MenuView; MenuView.changes says what
##   changed, MenuLayout where, and this file draws and moves it.
##   Input: one transparent button over each drawn row and over each half of the sheet's foot (the page arrows),
##   placed from the same layout; the keys and the pad stay with the turn.
##   Motion: a closed column keeps what it last showed and runs on its springs until it settles: the cascade opens and
##   closes the same way backwards.

var host := Control.new() # the buttons over the drawing
var _layer: Layer3d
var _act: Dictionary # {hover: (list, index), pick: (i), command: (i), page: (dir)}
var _main := Menu3dColumn.new("disc", 10, 0, 1.7)
var _sub := Menu3dColumn.new("tile", 20, 100, 8.2)
var _sheet := Menu3dSheet.new()
var _glove := Menu3dIcon.new("", "glove", 0.035)
var _gx := Spring3d.new()
var _gy := Spring3d.new()
var _glove_out := false
var _view := {}
var _at := {}
var _hit_key := ""


func _init(layer: Layer3d, act: Dictionary) -> void:
	_layer = layer
	_act = act
	layer.flat.add_child(_main.ui)
	layer.flat.add_child(_sub.ui)
	layer.flat.add_child(_sheet.ui)
	for g in [_main.icons, _sub.icons, _sheet.icons, _glove.group]:
		layer.deep.add_child(g)
	_glove.model.rotation = Vector3(0.2, -0.3, 0)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.hits.add_child(host)
	layer.add(self)


## called by the HUD with each turn screen's view ({} while it is closed)
func update(next: Dictionary) -> void:
	var ch := MenuView.changes(_view, next)
	_view = next
	var still:= _layer.still
	# a confirmed row flashes and holds its column a moment: Act as the submenu opens, a command or an ability as the
	# menu leaves for the map. Esc out of the submenu confirms nothing: the cascade just runs backwards
	if ch.has("cascade"):
		_main.flash = 1.0
	# a third list: the second slides from its place over the menu's and flashes the picked row, the new one opens where
	# it was; closing it runs backwards (Fernando's grill, Nov 19)
	var lead: float = MenuLayout.LEAD * _at.get("cs", _layer.s)
	if ch.has("deeper") and not still:
		_main.shift.x = lead
		_main.flash = 1.0
		_sub.open.x = 0.0
	if ch.has("shallower") and not still:
		_sub.shift.x = -lead
	if ch.has("leave"):
		(_sub if _sub.want > 0 else _main).flash = 1.0
		if not still:
			_main.hold = 0.15
			_sub.hold = 0.15
	var has_sub: bool = not next.is_empty() and not next.sub.is_empty()
	if not next.is_empty():
		_show(next)
		# a column opens with its row already lit
		if _main.want == 0:
			_main.settle_focus()
		if has_sub and _sub.want == 0:
			_sub.settle_focus()
	_main.want = 0.0 if next.is_empty() else 1.0
	_sub.want = 1.0 if has_sub else 0.0
	_sheet.want = 1.0 if not next.is_empty() and not next.sheet.is_empty() else 0.0
	_hits()
	_layer.wake()


func resize() -> void:
	if not _view.is_empty():
		_show(_view)
	_hits()


func _show(m: Dictionary) -> void:
	var layer:= _layer
	# a phone stands the menu in the combat bar's bottom right corner (MenuLayout.corner_layout)
	var bar:= StageLayout.place("bar", layer.small)
	var foot:= bar.end.y if layer.phone else NAN
	_at = MenuLayout.layout(layer.stage, m.rows.size(), m.sub.size(), OS.has_feature("mobile"), foot)
	var cs: float = _at.cs
	_main.x = _at.main.position.x
	_main.y = _at.main.position.y
	_main.set_data({"title": m.head, "w": _at.main.size.x, "h": _at.main.size.y, "rows": m.rows}, layer, cs)
	_main.focus = m.index
	if not m.sub.is_empty():
		_sub.x = _at.sub.position.x
		_sub.y = _at.sub.position.y
		_sub.set_data({"title": m.sub_title, "w": _at.sub.size.x, "h": _at.sub.size.y, "rows": m.sub}, layer, cs)
		_sub.focus = m.sub_index
	if not m.sheet.is_empty():
		_sheet.set_data(m.sheet, layer)


## the buttons over the drawing, rebuilt only when a place or a greyed state changed: the rows of the list in play (the
## list covers the menu while it is open) and the sheet's two arrows
func _hits() -> void:
	var m := _view
	var key:= ""
	if not m.is_empty() and not _at.is_empty():
		var list: Array = m.sub if not m.sub.is_empty() else m.rows
		key = str([_at, list.map(func(r: Dictionary) -> bool: return r.off), m.sub.is_empty(), m.sheet.is_empty(), m.commands])
	if key == _hit_key:
		return
	_hit_key = key
	for c in host.get_children():
		host.remove_child(c)
		c.queue_free()
	if m.is_empty() or _at.is_empty():
		return
	var cs: float = _at.cs
	if not m.sub.is_empty():
		_rows("abilities", _at.sub, m.sub, m, _act.pick, cs)
		if not m.sheet.is_empty():
			_hit(_at.prev, Texts.t("Página anterior", "Previous page"), func() -> void: _act.page.call(-1))
			_hit(_at.next, Texts.t("Próxima página", "Next page"), func() -> void: _act.page.call(1))
	else:
		_rows("menu", _at.main, m.rows, m, _act.command, cs)


# a menu row stands for its place in Command.COMMANDS (menu_rows leaves Undo move out), an ability for its own
func _rows(list: String, col: Rect2, rows: Array, m: Dictionary, pick: Callable, cs: float) -> void:
	for i: int in rows.size():
		var index: int = m.commands[i] if list == "menu" else i
		# a row that is off still takes the click, which only says no (Agir Nov 19, the greyed Move Nov 21)
		_hit(MenuLayout.row_box(col, i, cs), rows[i].label, func() -> void: pick.call(index), func() -> void: _act.hover.call(list, index))


func _hit(b: Rect2, name: String, click: Callable, over: Callable = Callable()) -> void:
	var e := Button.new()
	e.flat = true
	e.focus_mode = Control.FOCUS_NONE
	e.tooltip_text = ""
	e.accessibility_name = name
	e.modulate = Color(1, 1, 1, 0) # the drawing is the look; the button only takes the pointer
	e.position = b.position
	e.size = b.size
	e.pressed.connect(click)
	if over.is_valid():
		e.mouse_entered.connect(over)
	host.add_child(e)


func frame(dt: float, time: float) -> bool:
	var layer:= _layer
	var s: float = _at.get("cs", layer.s)
	var still:= layer.still
	# the menu under the open submenu only steps back a little: on the reference it keeps its light, under the shadow
	_main.frame(dt, time, layer, 0, 0, _sub.want == 0)
	_sub.frame(dt, time, layer, MenuLayout.LEAD * s * 0.55, 1, true)
	var sheet_at: Rect2 = _at.get("sheet", Rect2())
	_sheet.frame(dt, time, layer, sheet_at.position.x, sheet_at.position.y)
	# the glove points at the focused row of the column in play, sliding from one to the other
	var col:= _sub if _sub.want > 0 else _main
	_gx.to = col.x - 31 * s
	_gy.to = col.y + col.row_y()
	var shown:= clampf(_main.open.x * 1.6, 0.0, 1.0)
	if not _glove_out: # appears in place, does not fly in
		_gx.land()
		_gy.land()
	_glove_out = shown > 0.004
	_gx.move(dt, still, 330, 25)
	_gy.move(dt, still, 330, 25)
	# a finger is its own pointer: the glove only covers the map (Fernando, Nov 18; a key or a pad brings it back)
	_glove.group.visible = _glove_out and not layer.finger
	var nudge:= 0.0 if still else sin(time * 5.2) * 3.2 * s + col.flash * 10 * s
	_glove.group.position = Vector3(_gx.x + nudge, -_gy.x, 300)
	_glove.group.scale = Vector3.ONE * maxf(1e-5, MenuLayout.HAND * s * shown)
	_glove.group.rotation.z = clampf(-_gy.v * 0.0016, -0.4, 0.4) # leans into its slide
	# it sways while it is up; closed and settled, the last frame drawn is the empty one
	var up:= _main.want > 0 or _main.open.x > 0.004 or _sub.open.x > 0.004 or _sheet.open.x > 0.004
	var moving:= _main.busy() or _sub.busy() or _sheet.busy() or not _gx.settled() or not _gy.settled()
	return not still and (up or moving)


func dispose() -> void:
	_layer.remove(self)
	_main.clear()
	_sub.clear()
	_sheet.clear()
	_glove.dispose()
	host.queue_free()

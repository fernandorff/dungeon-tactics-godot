class_name Turn3d
extends RefCounted
## The turn list drawn in 3D (port of the web game's turn3d/turn3d.ts), a screen of the shared 3D layer (Layer3d): one
## card per row, 1 at the bottom and counting up, each springing to its row's box (QueueLayout, pure). The acting unit's
## card is the combat bar's sheet, so the list starts at 2. A transparent Control over the list takes the wheel, a
## drag, the hover (lifts the card and tells its unit's life and CT) and a click (opens that unit's look-only menu).

const K := 170.0 # the cards' spring: a ratio of 0.69, a little overshoot, settled in about a third of a second
const C := 18.0
const TEXT_PAD := 3.0 # the empty margin a label carries on each side (Text3d.PAD)
const STEP := 40.0 # px a wheel notch scrolls

var _layer: Layer3d
var _peek: Callable
var _root := Node3D.new()
var _cards: Array = []
var _leaving: Array = []
var _turn := ""
var _drawn := false # the first list is placed, not animated: nothing flies in when the battle opens
var _hovered := -1
var _stat_w := 0.0 # the widest line of the list: every bar takes it, so they compare at a glance
var _scroll := Spring3d.new() # 0 at rest, negative up the list (the column stacks from the bottom)
var _want := 0.0
var _lay := {}
var _shown := {"rows": 0, "now": false, "stats": 0.0, "folded": false}
var _small: Array = []
var _s := 1.0
var _title: Label3D
var _title_key := ""
var _tip := Turn3dTip.new()
var _hit := Control.new()
var _drag := -1.0


## `peek(id)`: a click on a card
func _init(layer: Layer3d, peek: Callable) -> void:
	_layer = layer
	_peek = peek
	layer.flat.add_child(_root)
	_root.add_child(_tip.group)
	_hit.mouse_filter = Control.MOUSE_FILTER_PASS
	_hit.gui_input.connect(_input)
	_hit.mouse_exited.connect(func() -> void: _hover(-1))
	layer.hits.add_child(_hit)
	layer.add(self)


## the list's scale: the cards were measured at 720 px tall, 1.5 of them to a reference px
func resize() -> void:
	_s = _layer.small.s * 1.5
	_retext()
	_relay()


func _relay() -> void:
	var st: Dictionary = _layer.small
	var r: Dictionary = StageLayout.REGIONS.sheet
	var h := QueueLayout.lu(r.h * st.s)
	var page_h := _layer.page.y
	var sheet_y := page_h - QueueLayout.lu(st.y + (StageLayout.SCREEN.y - r.y - r.h) * st.s) - h
	_lay = QueueLayout.layout({
		"rows": _shown.rows, "now": _shown.now, "s": _s, "at": StageLayout.place("turn", _layer.stage), "pageH": page_h,
		"sheet": page_h - roundf(sheet_y), "stats": _shown.stats, "small": _small, "margin": _layer.inset_top,
		"folded": _shown.folded,
	})
	var b: Rect2 = _lay.box
	_hit.position = b.position
	_hit.size = b.size
	_set_title()
	_place(false)


## the list's name over the cards
## shortcut: the web's title folds the list to faces only (hud-queue.ts, dt:turnsFold); the port shows it open
func _set_title() -> void:
	var says := Texts.t("Turnos", "Turns") + " ▾"
	var key := str([says, _layer.dpr])
	if key != _title_key:
		if _title:
			_title.queue_free()
		_title = Text3d.label(_layer, says, 16, Turn3dCard.INK)
		Text3d.order(_title, 5)
		_root.add_child(_title)
		_title_key = key
	Text3d.put(_title, _lay.title.x, _lay.title.y, _layer.dpr)


## A redrawn list: the queue (TurnRows.queue), the aimed strike on each target (BarView.forecast) and the unit the
## bar's sheet shows. Each row keeps its card (QueueView.match_rows), new rows get one and the rest leave: the one that
## just played slides out, the others fade
func update(b: Battle, q: Dictionary, fs: Array, sheet: String) -> void:
	var head := QueueView.head_on_sheet(q, sheet)
	var rows: int = q.rows.size() - (1 if head else 0)
	_shown.rows = rows
	_shown.now = rows > 0 and not head
	_small = QueueView.repeats(q.rows).slice(1 if head else 0)
	var next := QueueView.cards(b, q, fs, sheet)
	var turn := "%d:%s" % [b.state.get("turnsPlayed", 0), b.state.turn.actor]
	var passed := turn != _turn
	_turn = turn
	var kept := QueueView.match_rows(_cards.map(func(c: Turn3dCard) -> Dictionary: return c.d.id), next.map(func(x: Dictionary) -> Dictionary: return x.id), passed)
	for i in _cards.size():
		if kept.has(i):
			continue
		var c: Turn3dCard = _cards[i]
		c.row = -1
		c.fade = 0.0
		if i == 0 and passed:
			c.box.x.to -= 70 * _s
			c.box.y.to += 18 * _s
		_leaving.append(c)
	var old := _cards
	_cards = []
	for i in next.size():
		var c: Turn3dCard = Turn3dCard.new(next[i], _root) if kept[i] < 0 else old[kept[i]]
		c.row = i
		c.show(next[i])
		_cards.append(c)
	_retext()
	# a new turn goes back to the bottom; the row where the aimed charge fires stays in view
	if passed:
		_want = 0.0
	_relay()
	var at: int = q.get("at", -1) - (1 if head else 0)
	if at >= 0 and at < _lay.rows.size():
		_keep_in_view(_lay.rows[at])
	if not _drawn:
		_place(true)
	_drawn = true


func _keep_in_view(r: Rect2) -> void:
	var low: float = _lay.head
	var high: float = _lay.height - _lay.seat.pad.bottom
	if r.position.y - _want < low:
		_want = r.position.y - low
	elif r.end.y - _want > high:
		_want = r.end.y - high
	_want = clampf(_want, -_lay.more, 0.0)


func _retext() -> void:
	var size: float = QueueLayout.stats_layout(0, _s).size
	var widths: Array = []
	for c: Turn3dCard in _cards:
		c.set_texts(_layer, _root, size)
		for l: Array in c.lines:
			widths.append(l.map(func(m: Label3D) -> float: return Text3d.w(m)))
	_stat_w = QueueLayout.stat_width(widths, _s, TEXT_PAD)
	# the list grows by the room the lines take past its cards' column (20 design px are already there)
	var room: float = QueueLayout.stats_layout(0, _s).x + _stat_w + (6 - 20) * _s if _stat_w else 0.0
	_shown.stats = maxf(0.0, ceilf(room))


## each card heads for its row's box; `first` puts them there at once, as reduced motion does
func _place(first: bool) -> void:
	var snap := first or _layer.still
	for c: Turn3dCard in _cards:
		if c.row < 0 or c.row >= _lay.rows.size():
			continue
		var r: Rect2 = _lay.rows[c.row]
		var to := {"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y}
		for k: String in Turn3dCard.SIDES:
			c.box[k].to = to[k]
		# a new card grows in place
		if c.alpha == 0 and not snap:
			c.box.x.land()
			c.box.y.land()
			c.box.w.x = r.size.x * 0.6
			c.box.h.x = r.size.y * 0.6
		if snap:
			for k: String in Turn3dCard.SIDES:
				c.box[k].land()
			c.alpha = 1.0
	_layer.wake()


func _hover(row: int) -> void:
	if row != _hovered:
		_layer.wake()
	_hovered = row


## the row under a point of the list's box, -1 for none
func _row_at(at: Vector2) -> int:
	for i in _cards.size():
		var c: Turn3dCard = _cards[i]
		var y: float = c.box.y.x - _scroll.x
		if at.y >= y - _lay.seat.gap / 2 and at.y < y + c.box.h.x + _lay.seat.gap / 2 and at.y > _lay.head:
			return i
	return -1


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_hover(_row_at(ev.position))
		if _drag >= 0.0 and ev.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_scroll_by(-ev.relative.y)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_scroll_by(-STEP if ev.button_index == MOUSE_BUTTON_WHEEL_UP else STEP)
		_hit.accept_event()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_drag = ev.position.y
		else:
			# a tap or click on a card (a drag scrolls the list instead and never clicks)
			var row := _row_at(ev.position)
			if absf(ev.position.y - _drag) < 6 and row >= 0 and _cards[row].d.id.charge == "":
				_peek.call(_cards[row].d.unit.id)
			_drag = -1.0


func _scroll_by(v: float) -> void:
	_want = clampf(_want + v, -_lay.get("more", 0.0), 0.0)
	_layer.wake()


func frame(dt: float, t: float) -> bool:
	var still := _layer.still
	var e := 10.0 if still else dt # reduced motion: every ease is already there
	_scroll.to = _want
	if still:
		_scroll.land()
	else:
		_scroll.step(dt, K, C)
	var top: float = _lay.top
	# rows fade at an end only when there is more list past it
	var clip := Vector2(top + _lay.head if _lay.more + _want > 1 else -1e5, top + _lay.height + Turn3dCard.PAD * _s if _want < -1 else 1e5)
	_leaving = _leaving.filter(func(c: Turn3dCard) -> bool:
		if c.alpha > 0.01 and not still:
			return true
		c.dispose()
		return false)
	var tipped: Turn3dCard = _cards[_hovered] if _hovered >= 0 and _hovered < _cards.size() else null
	for c: Turn3dCard in _cards + _leaving:
		c.step(_layer, geo(), dt, e, t, c == tipped, clip)
	var m: Turn3dCard = tipped
	var past := 0.0
	if m:
		var stat: Vector4 = m.mat.get_shader_parameter("stat")
		past = stat.x + stat.y if not m.lines.is_empty() else m.box.w.x
	var target: float = m.mat.get_shader_parameter("target") if m else 0.0
	_tip.show(_layer, m.d.tip if m else "", _lay.left + (m.box.x.x if m else 0.0) + past + (12 + 8 * target) * _s, top + (m.box.y.x + m.box.h.x / 2 - _scroll.x if m else 0.0))
	var tip_moving := _tip.frame(e)
	# the acting card breathes and a light sweeps it: the list moves for as long as it shows
	return (tip_moving or not still) and _cards.size() + _leaving.size() > 0


## what a card reads to draw itself
func geo() -> Dictionary:
	return {"lay": _lay, "s": _s, "scroll": _scroll.x, "stat_w": _stat_w}

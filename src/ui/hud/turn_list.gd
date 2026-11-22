class_name TurnList
extends Control
## The turn list on the left (port of the web game's turn3d/turn3d.ts and queue-layout.ts): the cards stack up from just
## above the acting unit's sheet, which stands for row 1, through this round and the next; the wheel or a drag scrolls a
## list taller than its box, a new turn goes back to the bottom, and the aimed charge's row is kept in view. Hovering a
## card tells its unit's life and CT gains. Rebuilt only when the state, the aim or the language changes.

signal peek(id: String)

const GAP := 8.0
const HEAD := 22.0 # the pinned title: one line and its padding

var _box := Control.new()
var _rows := Control.new()
var _title: Label
var _tip: Label
var _key := 0
var _turn := -1
var _scroll := 0.0
var _more := 0.0
var _drag := -1.0


func _ready() -> void:
	var r := HudSkin.region("turn")
	# it ends above the acting sheet (queue-layout.ts: the room the sheet takes from the page's bottom, and 2 px)
	var bottom := HudSkin.region("sheet").position.y - 2
	position = Vector2(r.position.x, r.position.y)
	size = Vector2(TurnCard.NUMBER_W + TurnCard.FACE.x + 6 + TurnCard.STATS_W + 8, bottom - r.position.y)
	mouse_filter = MOUSE_FILTER_PASS
	_title = HudSkin.label(Texts.t("Turnos", "Turns") + " ▾", 18, HudSkin.LIGHT)
	_title.position = Vector2(TurnCard.NUMBER_W + 4, 0)
	add_child(_title)
	_box.clip_contents = true
	_box.mouse_filter = MOUSE_FILTER_IGNORE
	_box.position = Vector2(0, HEAD + 4)
	_box.size = Vector2(size.x, size.y - HEAD - 4)
	add_child(_box)
	_rows.mouse_filter = MOUSE_FILTER_IGNORE
	_box.add_child(_rows)
	_tip = HudSkin.label("", 18, HudSkin.INK)
	_tip.visible = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = HudSkin.PAPER
	bg.border_color = HudSkin.EDGE
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)
	bg.set_content_margin_all(6)
	_tip.add_theme_stylebox_override("normal", bg)
	_tip.z_index = 5
	_tip.top_level = true # placed beside a card, outside the list's clip
	add_child(_tip)


## the list for this state, with the projection of `aim` ({ability, target} or {}); `struck`: the ids the aimed strike
## reaches, their cards marked in gold
func show_queue(b: Battle, aim: Dictionary, struck: Dictionary = {}) -> void:
	var key := hash([b.state.hash(), aim, struck, Texts.current()])
	if key == _key:
		return
	_key = key
	_title.text = Texts.t("Turnos", "Turns") + " ▾"
	for c in _rows.get_children():
		c.queue_free()
	var q := TurnRows.queue(b, aim)
	var seen := {}
	var y := _box.size.y
	var fire_y := -1.0
	var fire_h := 0.0
	for i in q.rows.size():
		var r: Dictionary = q.rows[i]
		var u := Combat.find_unit(b.state, r.unit)
		if u.is_empty():
			continue
		var is_charge: bool = r.has("charge")
		var repeat: bool = not is_charge and seen.has(r.unit)
		if not is_charge:
			seen[r.unit] = true
		if i == 0:
			continue # the acting unit's sheet stands for row 1
		var c := TurnCard.new()
		c.unit = u
		c.number = i + 1
		c.small = repeat
		c.charge = r.get("charge", "")
		c.ticks = r.get("ticks", 0)
		c.marked = not is_charge and (q.targets.has(r.unit) or struck.has(r.unit))
		c.firing = i == q.at
		c.setup()
		y -= c.size.y
		c.position = Vector2(0, y)
		if c.firing:
			fire_y = y
			fire_h = c.size.y
		_rows.add_child(c)
		c.mouse_entered.connect(_show_tip.bind(c))
		c.mouse_exited.connect(func() -> void: _tip.visible = false)
		# a click or tap on a card opens its unit's look-only menu, as a tap on it on the map (unit-peek.ts)
		c.gui_input.connect(func(ev: InputEvent) -> void:
			if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
				peek.emit(c.unit.id))
		y -= GAP
	_more = maxf(0.0, -y)
	# a new turn goes back to the bottom; the aimed charge's row stays in view; else the place the player scrolled
	var turn: int = b.state.get("turnsPlayed", 0)
	if turn != _turn:
		_turn = turn
		_scroll = 0.0
	if fire_y >= 0.0:
		_scroll = keep_in_view(_scroll, _box.size.y, _box.size.y - (fire_y + fire_h), fire_h)
	_scroll_to(_scroll)


## the scroll that shows a row (`top` measured up from the box's bottom) moving as little as possible (keepInView)
static func keep_in_view(scroll: float, view: float, top: float, height: float) -> float:
	if top < scroll or height > view:
		return top
	if top + height > scroll + view:
		return top + height - view
	return scroll


func _scroll_to(v: float) -> void:
	_scroll = clampf(v, 0.0, _more)
	_rows.position.y = _scroll
	# no card shows cut under the title: one that does not fit whole is left out until the list scrolls to it (web, Nov 18)
	for c: Control in _rows.get_children():
		c.visible = c.position.y + _scroll >= 0.0


func _show_tip(c: TurnCard) -> void:
	_tip.text = TurnRows.stats_text(c.unit) if c.charge == "" else Texts.ability_name(c.charge)
	_tip.visible = true
	_tip.reset_size()
	_tip.global_position = c.global_position + Vector2(c.size.x + 6, 0)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_scroll_to(_scroll + (40.0 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else -40.0))
		accept_event()
	elif ev is InputEventScreenTouch:
		_drag = ev.position.y if ev.pressed else -1.0
	elif ev is InputEventScreenDrag and _drag >= 0.0:
		_scroll_to(_scroll + ev.relative.y)
		accept_event()

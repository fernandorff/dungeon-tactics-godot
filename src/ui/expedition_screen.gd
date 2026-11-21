class_name ExpeditionScreen
extends Control
## The expedition map (port of game/expedition-map.ts with the look of town3d/map3d.ts): the whole descent as a chart
## of places linked by ways (Fernando, Nov 16: after FFT's world map), the party's state, the box of the picked place
## and the commands. A place is only picked on the chart; the box describes it and Travel enters it, so no tap on the
## map commits the party. The arrows and the d-pad go to what is straight that way on screen (MapLayout.next_spot).
## MapDraw draws it all; this screen keeps the state and seats transparent buttons under the drawn places and plaques.

const ARM_MS := 5000 # long enough to read "Confirm: ends the expedition, the gold found goes to town"

var main: Main
var exp: Dictionary
var map: Array
var L: Dictionary
var floor: int
var gold: int
var heroes: Array = [] # [{name, job, hp, max, mana, mana_max}]
var marks: Array = [] # each place's glyph by node
var commands: Array = [] # [{label, note, disabled, armed}]: Travel, Information, Back to town
var picked := 0
var facts: Dictionary
var _chart: Dictionary
var _root := Control.new()
var _draw: MapDraw
var _places: Array = [] # Button by node
var _cmds: Array = [] # Button by command
var _note: Notice
var _armed_at := 0


func _init(m: Main, e: Dictionary) -> void:
	main = m
	exp = e


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_root.size = MapLayout.SCREEN
	_root.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_root)
	_draw = MapDraw.new(self)
	_root.add_child(_draw)
	resized.connect(_fit)
	get_viewport().gui_focus_changed.connect(func(_c: Control) -> void: _draw.queue_redraw())
	_build()


func _fit() -> void:
	var k := minf(size.x / MapLayout.SCREEN.x, size.y / MapLayout.SCREEN.y)
	_root.scale = Vector2(k, k)
	_root.position = (size - MapLayout.SCREEN * k) / 2


func _build() -> void:
	for c in _root.get_children():
		if c != _draw:
			c.queue_free()
	_places.clear()
	_cmds.clear()
	map = Expedition.map_of(exp.seed)
	_chart = MapChart.chart(map, exp.path)
	floor = map[Expedition.open_nodes(map, exp.path)[0]].floor
	gold = Expedition.descent_gold(exp)
	marks = []
	var kinds: Array = []
	for i in map.size():
		marks.append(MapFacts.mark(map[i], _chart.places[i].state))
		kinds.append(MapFacts.kind_of(map[i]))
	var g := CrawlFlow.group()
	heroes = []
	for h in exp.party:
		var m := Party.member(g, h.id)
		heroes.append({"name": m.get("name", h.id), "job": Texts.unit_name(m.cls) if m.has("cls") else "", "cls": m.get("cls", ""), "hp": h.hp, "max": h.max, "mana": h.get("mana", h.get("manaMax", 0)), "mana_max": h.get("manaMax", 0)})
	commands = [{"label": "", "note": "", "disabled": false, "armed": false}, {"label": Texts.t("Informações", "Information"), "note": "", "disabled": false, "armed": false}, {"label": Texts.t("Voltar à cidade", "Back to town"), "note": "", "disabled": false, "armed": false}]
	L = MapLayout.layout(_chart, kinds, heroes.size(), commands.size())
	_faces()
	# the buttons in reading order (down the chart, left to right), the order Tab walks them
	var order: Array = range(map.size())
	order.sort_custom(func(a: int, b: int) -> bool: return L.places[a].at.y < L.places[b].at.y or L.places[a].at.y == L.places[b].at.y and L.places[a].at.x < L.places[b].at.x)
	_places.resize(map.size())
	for i in order:
		var p: Dictionary = L.places[i]
		var side := maxf(66, p.size) # never under the game's 44 px tap at the 1280 px window
		var node: int = i
		_places[i] = _button(Rect2(p.at - Vector2(side, side) / 2, Vector2(side, side)), func() -> void: _pick(node, true))
		_places[i].focus_entered.connect(func() -> void: _pick(node))
		# the arrows walk the seals as drawn, not the wider tap squares (the layout's tests walk the same boxes)
		_places[i].set_meta("walk", Rect2(p.at - Vector2(p.size, p.size) / 2, Vector2(p.size, p.size)))
		_places[i].tooltip_text = "%s: %s" % [MapFacts.name_of(map[i]), MapFacts.word(map[i], _chart.places[i].state)]
	for k in commands.size():
		var at: int = k
		_cmds.append(_button(L.commands[k], func() -> void: _command(at)))
		_cmds[k].focus_entered.connect(_draw.queue_redraw)
	var first := 0
	while _chart.places[first].state != MapChart.OPEN:
		first += 1
	_pick(first)
	_fit()
	_places[first].grab_focus()


func _faces() -> void:
	var face: float = MapLayout.HERO.face
	for i in heroes.size():
		var cls: String = heroes[i].cls
		if cls == "":
			continue
		var r := Portraits.face({"def": cls, "hp": Content.units[cls].hp}, int(face))
		if r == null:
			continue
		var b: Rect2 = L.heroes[i]
		r.position = Vector2(b.position.x, b.position.y + (b.size.y - face) / 2)
		r.size = Vector2(face, face)
		r.mouse_filter = MOUSE_FILTER_IGNORE
		_root.add_child(r)


func _button(r: Rect2, run: Callable) -> Button:
	var b := Button.new()
	b.flat = true
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.position = r.position
	b.size = r.size
	b.focus_mode = FOCUS_ALL
	# the mouse moves the cursor as the keys do
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.pressed.connect(run)
	_root.add_child(b)
	return b


## the picked place: its box, its ring and Travel; `act` (Enter, A, a tap) also moves on to the commands
func _pick(node: int, act: bool = false) -> void:
	picked = node
	var state: String = _chart.places[node].state
	var here: int = exp.path.back() if exp.path.size() else -1
	facts = MapFacts.facts_of(map, node, state, here)
	var n: Dictionary = map[node]
	commands[0].label = Texts.t("Abrir o baú", "Open the chest") if n.chest else Texts.t("Entrar na sala", "Enter the room")
	commands[0].disabled = state != MapChart.OPEN
	commands[0].note = "" if state == MapChart.OPEN else MapFacts.word(n, state)
	_cmds[0].disabled = commands[0].disabled
	if act:
		_cmds[1 if commands[0].disabled else 0].grab_focus()
	_draw.queue_redraw()


func _command(k: int) -> void:
	match k:
		0:
			_enter(picked)
		1:
			_note = Notices.info(self, Callable())
		2:
			# the 2nd tap confirms: going back ends the descent, alive, so its gold goes home whole
			if not commands[2].armed:
				_arm(true)
				return
			CrawlFlow.retreat(exp)
			main.town()


func _arm(on: bool) -> void:
	commands[2].armed = on
	commands[2].label = Texts.t("Confirmar: encerra a expedição, o ouro achado vai à cidade", "Confirm: ends the expedition, the gold found goes to town") if on else Texts.t("Voltar à cidade", "Back to town")
	_armed_at = Time.get_ticks_msec()
	_draw.queue_redraw()


func _enter(node: int) -> void:
	if not map[node].chest:
		main.room(node)
		return
	var next: Variant = CrawlFlow.take_chest(node)
	if next == null:
		# a stale map: the expedition as it is now, or the town when it ended
		main.expedition_map()
		return
	Sound.play("confirm")
	exp = next
	_build()
	_note = Notices.chest(self, Expedition.node_gold(map[node]))


func _process(_dt: float) -> void:
	# the armed Back to town goes back to itself after a while or once the focus leaves it
	if commands.size() and commands[2].armed and (Time.get_ticks_msec() - _armed_at > ARM_MS or get_viewport().gui_get_focus_owner() != _cmds[2]):
		_arm(false)


func _input(ev: InputEvent) -> void:
	if is_instance_valid(_note) or not ev.is_pressed():
		return
	if ev.is_action("ui_cancel") and commands[2].armed:
		_arm(false)
		get_viewport().set_input_as_handled()
		return
	for d in [["ui_left", Vector2.LEFT], ["ui_right", Vector2.RIGHT], ["ui_up", Vector2.UP], ["ui_down", Vector2.DOWN]]:
		if ev.is_action(d[0]):
			_walk(d[1])
			get_viewport().set_input_as_handled()
			return


## the arrow goes to the nearest place or plaque straight that way, and stays at an edge
func _walk(dir: Vector2) -> void:
	var items: Array = (_places + _cmds).filter(func(b: Button) -> bool: return not b.disabled)
	var boxes: Array = items.map(func(b: Button) -> Rect2: return b.get_meta("walk", Rect2(b.position, b.size)))
	var at := items.find(get_viewport().gui_get_focus_owner())
	items[0 if at < 0 else MapLayout.next_spot(boxes, at, dir)].grab_focus()


## the plaque in focus, or -1
func focus_command() -> int:
	return _cmds.find(get_viewport().gui_get_focus_owner()) if is_inside_tree() else -1


func focus_place() -> int:
	return _places.find(get_viewport().gui_get_focus_owner()) if is_inside_tree() else -1


## the help band: what the command in focus does, else the picked place and its way
func help_text() -> String:
	var k := focus_command()
	if k >= 0:
		var said: String = MapLayout.command_text(commands[k].label, commands[k].note, commands[k].armed).help
		if said != "":
			return said
	return "%s: %s" % [facts.name, facts.facts.back()[1]]

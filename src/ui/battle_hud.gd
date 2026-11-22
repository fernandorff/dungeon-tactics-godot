class_name BattleHud
extends Control
## The battle's HUD in the web game's parchment look (src/ui/hud/*): the turn list on the left, the combat bar along the
## bottom, the command menu and the Agir lists on the bottom right with the action sheet above them, the Height corner,
## the banner, the key hints, the corner buttons and the charge lines; the Status, peek and menu windows. Only shows and
## passes clicks along to the battle screen. Each piece redraws only when what it shows changes, so a cursor step that
## changes nothing on it costs a hash.

var screen_ref: BattleScreen
var _turns: Turn3d
var _queue := {} # the last TurnRows.queue and its key: the projection is redone only when the state or the aim changes
var _bar: Bar3d
var _hints: HudHints
var _hints3d: Hints3d
var _result: Result3d
var _said := "" # the ability playing now: it takes the banner (Hints3d) until the play ends
var _layer := Layer3d.new()
var _menu: Menu3d
var _lines: ChargeLines
var _window: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_lines = ChargeLines.new()
	_lines.view = screen_ref.view
	add_child(_lines)
	_hints = HudHints.new()
	add_child(_hints)
	_hints.pressed.connect(func(what: String) -> void: screen_ref.key(what))
	add_child(_layer)
	_bar = Bar3d.new(_layer)
	_hints3d = Hints3d.new(_layer)
	_hints.device_changed.connect(refresh)
	screen_ref.view.announced.connect(announce)
	_turns = Turn3d.new(_layer, func(id: String) -> void:
		if screen_ref.is_hero_turn() and not screen_ref.busy:
			open_peek(id))
	_menu = Menu3d.new(_layer, {
		"command": func(i: int) -> void: screen_ref.choose(i),
		"pick": _list_pick,
		"page": func(dir: int) -> void:
			if not screen_ref.busy and screen_ref.is_hero_turn():
				screen_ref._apply(ActTurn.page(screen_ref.screen, dir)),
		"hover": _hover_row,
	})
	_result = Result3d.new(_layer) # last: over every other screen of the layer


## the end of the battle (BattleEnd's board)
func board(b: Dictionary) -> void:
	_result.show(b)


func _exit_tree() -> void:
	HudSkin.release()


func refresh() -> void:
	if screen_ref == null or _turns == null:
		return
	var sr := screen_ref
	var b := sr.battle
	var s := sr.screen
	var open := sr.is_hero_turn() and not sr.busy
	var p: Variant = sr.preview() if open else null
	var fs := _draw_bar(b, s, p)
	var aim := TurnRows.aim_of(b, s) if open else {}
	var key := hash([b.state.hash(), aim])
	if _queue.get("key") != key:
		_queue = {"key": key, "q": TurnRows.queue(b, aim)}
	# the battle over: the list empties, as the web's queued = null (the result takes the screen)
	_turns.update(b, {"rows": [], "at": -1} if b.over() else _queue.q, fs, "" if b.over() else b.actor().id)
	_draw_menu(MenuView.of(b, s, open))
	var height := HintRows.height_shown(b, s, sr.cursor)
	var line := HudBits.tile_info(b.grid, sr.cursor) if height >= 0 else ""
	var banner := sr.last_log
	if String(sr.scenario.get("id", "")).begins_with(Survival.ID):
		banner = Texts.t("Amanhece em %d turnos", "Dawn in %d turns") % Survival.turns_left(b.state) + ("" if banner == "" else " · " + banner)
	if _said != "":
		banner = _said
	elif b.over():
		banner = "" # the end screen says who won; the pill leaves like the Height and the hints
	var rows := HintRows.hints_for(b, s, open) if _hints.rows_shown() else {"left": [], "right": []}
	_hints3d.update(height, line, banner, rows)
	_hints.show_hints(open and b.can_undo())
	_lines.show_charges(b)


## the ability name the banner shows while it plays; "" gives the pill back to the summary
func announce(text: String) -> void:
	_said = text
	refresh()


## the acting unit's sheet, the aimed strike's plate and the target's sheet (the unit under the cursor otherwise)
## returns the aimed strike on each target, the one under the cursor first
func _draw_bar(b: Battle, s: Dictionary, p: Variant) -> Array:
	if b.over():
		_bar.update({"sheet": {}, "plate": {}, "target": {}})
		return []
	var me := b.actor()
	var under := Pathing.unit_at(b.state, screen_ref.cursor)
	var other: Dictionary = under if not under.is_empty() and under.id != me.id else {}
	var fs: Array = []
	var ability := ""
	if p != null and p.get("ok", false):
		var a := ActTurn.screen_action(b, s)
		if not a.is_empty() and a.k == "ability":
			ability = a.id
			fs = BarView.forecast(b, ability, p)
			# the one under the cursor first
			fs = Util.stable_sort(fs, func(x: Dictionary, y: Dictionary) -> bool: return x.unit.id == other.get("id", "") and y.unit.id != other.get("id", ""))
	_bar.update(BarView.of(b.state, me, other, fs, ability))
	return fs


## the command menu, the Agir lists and the action sheet, drawn in 3D (Menu3d, port of the web's menu3d/)
func _draw_menu(v: Dictionary) -> void:
	_layer.finger = _hints._finger
	_menu.update(v)


## the mouse over a 3D menu row moves the focus there (hero-turn.ts hoverRow): a command's place in COMMANDS on the
## bare menu, a row of the list in play otherwise
func _hover_row(list: String, index: int) -> void:
	var sr := screen_ref
	if list == "abilities":
		if ActTurn.is_act(sr.screen) and not sr.busy:
			_list_hover(index)
		return
	if sr.busy or not sr.is_hero_turn() or sr.screen.k != "menu" or sr.screen.index == index:
		return
	if not Command.menu_rows(sr.battle).has(Command.COMMANDS[index]):
		return
	Sound.play("cursor")
	sr.screen = {"k": "menu", "index": index}
	sr._refresh()


func _list_pick(i: int) -> void:
	var sr := screen_ref
	if not ActTurn.is_act(sr.screen) or sr.busy:
		return
	sr._apply(ActTurn.pick(sr.battle, sr.screen, i))


func _list_hover(i: int) -> void:
	var sr := screen_ref
	sr._apply(ActTurn.hover(sr.battle, sr.screen, i))


# --- windows --------------------------------------------------------------------------------------

func _close_window() -> void:
	if _window:
		_window.queue_free()
		_window = null
	screen_ref.paused = false


func _open(title: String, rows: Array, buttons: Array) -> void:
	_close_window()
	screen_ref.paused = true
	_window = PaperWindow.open(self, title, rows, buttons, func() -> void:
		_window = null
		screen_ref.paused = false)


func open_status(id: String) -> void:
	var u := Combat.find_unit(screen_ref.battle.state, id)
	_open("Status · " + Texts.unit_name(u.def), Texts.unit_status(screen_ref.battle.state, id), [[Texts.t("Fechar", "Close"), _close_window]])


## the look-only menu of another unit (port of unit-peek.ts): its Status, its abilities and its range on the map
func open_peek(id: String) -> void:
	var u := Combat.find_unit(screen_ref.battle.state, id)
	if u.is_empty():
		return
	var name := Texts.unit_name(u.def)
	_open("%s · %s" % [name, Texts.side_name(u.team)], [], [
		["Status", func() -> void: open_status(id)],
		[Texts.t("Habilidades", "Abilities"), func() -> void: _open(Texts.t("Habilidades: %s", "Abilities: %s") % name, ability_rows(u.def), [[Texts.t("Fechar", "Close"), _close_window]])],
		[Texts.t("Mostrar alcance", "Show range"), func() -> void:
			_close_window()
			# paints where the unit walks and strikes until the next tap or key
			screen_ref.ui = Interaction.fresh_ui(screen_ref.battle).merged({"mode": "idle", "inspect": id}, true)
			screen_ref._refresh()],
		[Texts.t("Fechar", "Close"), _close_window],
	])


## one row per ability: its name, then its range (or "around you"), its cost and its charge ticks
static func ability_rows(def: String) -> Array:
	var out: Array = []
	for id: String in Content.units[def].get("abilities", []):
		var a: Dictionary = Content.abilities[id]
		var charge := Texts.t("carrega %d tiq.", "charges %d tk") % a.charge if a.charge else ""
		var parts := [Texts.ability_pages(id)[0][0], Texts.cost_text(a), charge].filter(func(x: String) -> bool: return x != "")
		out.append([Texts.ability_name(id), " · ".join(parts)])
	return out


func open_pause() -> void:
	screen_ref.paused = true
	_window = OptionsWindow.open(self, func() -> void:
		_window = null
		screen_ref.paused = false
		refresh())

class_name BattleHud
extends Control
## The battle's HUD in the web game's parchment look (src/ui/hud/*): the turn list on the left, the combat bar along the
## bottom, the command menu and the Agir lists on the bottom right with the action sheet above them, the Height corner,
## the banner, the key hints, the corner buttons and the charge lines; the Status, peek and menu windows. Only shows and
## passes clicks along to the battle screen. Each piece redraws only when what it shows changes, so a cursor step that
## changes nothing on it costs a hash.

var screen_ref: BattleScreen
var _turns: TurnList
var _bar: CombatBar
var _hints: HudHints
var _main := MenuColumn.new()
var _sub := MenuColumn.new()
var _sheet := ActionSheet.new()
var _glove := Glove.new()
var _lines: ChargeLines
var _window: Control
var _view := {} # the menu view on screen


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_lines = ChargeLines.new()
	_lines.view = screen_ref.view
	add_child(_lines)
	_turns = TurnList.new()
	add_child(_turns)
	_turns.peek.connect(func(id: String) -> void:
		if screen_ref.is_hero_turn() and not screen_ref.busy:
			open_peek(id))
	_bar = CombatBar.new()
	add_child(_bar)
	_hints = HudHints.new()
	add_child(_hints)
	_hints.pressed.connect(func(what: String) -> void: screen_ref.key(what))
	for c in [_main, _sub, _sheet, _glove]:
		c.visible = false
		add_child(c)
	_main.picked.connect(_pick_main)
	_main.hovered.connect(_hover_main)
	_sub.picked.connect(func(i: int) -> void: _list_pick(i))
	_sub.hovered.connect(func(i: int) -> void: _list_hover(i))
	_sheet.turned.connect(func(dir: int) -> void: screen_ref._apply(ActTurn.page(screen_ref.screen, dir)))


func _exit_tree() -> void:
	HudSkin.release()


func refresh() -> void:
	if screen_ref == null or _turns == null:
		return
	var sr := screen_ref
	var b := sr.battle
	var s := sr.screen
	var open := sr.is_hero_turn() and not sr.busy
	var struck := {}
	var p: Variant = sr.preview() if open else null
	if p != null and p.get("ok", false):
		for t in p.targets:
			struck[t.unit] = true
	_turns.show_queue(b, TurnRows.aim_of(b, s) if open else {}, struck)
	_draw_bar(b, s, p)
	_draw_menu(MenuView.of(b, s, open))
	var height := HintRows.height_shown(b, s, sr.cursor)
	var line := HudBits.tile_info(b.grid, sr.cursor) if height >= 0 else ""
	var banner := sr.last_log
	if String(sr.scenario.get("id", "")).begins_with(Survival.ID):
		banner = Texts.t("Amanhece em %d turnos", "Dawn in %d turns") % Survival.turns_left(b.state) + ("" if banner == "" else " · " + banner)
	_hints.show_hints(height, line, banner, HintRows.hints_for(b, s, open), open and b.can_undo())
	_lines.show_charges(b)


## the acting unit's sheet, the aimed strike's plate and the target's sheet (the unit under the cursor otherwise)
func _draw_bar(b: Battle, s: Dictionary, p: Variant) -> void:
	if b.over():
		_bar.show_bar({"sheet": {}, "plate": {}, "target": {}})
		return
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
	_bar.show_bar(BarView.of(b.state, me, other, fs, ability))


## the command menu and the Agir lists, standing on the menu region's foot (menu-layout.ts): the list beside the menu
## opens LEAD px to the right of it; the glove points at the focused row of the column the player moves
func _draw_menu(v: Dictionary) -> void:
	_view = v
	var shown := not v.is_empty()
	_main.visible = shown
	_glove.visible = shown
	_sub.visible = shown and not v.sub.is_empty()
	_sheet.visible = shown and not v.sheet.is_empty()
	if not shown:
		return
	var r := HudSkin.region("menu")
	var foot := r.end.y
	var lead := HudSkin.region("submenu").position.x - r.position.x
	var listing: bool = not v.sub.is_empty()
	_main.show_rows(v.head, v.rows, v.index, not listing)
	_main.position = Vector2(r.position.x, foot - _main.size.y)
	var col := _main
	var at: int = v.index
	if listing:
		_sub.show_rows(v.sub_title, v.sub, v.sub_index, true)
		_sub.position = Vector2(r.position.x + lead, foot - _sub.size.y)
		col = _sub
		at = v.sub_index
	if not v.sheet.is_empty():
		_sheet.show_sheet(v.sheet)
		_sheet.position = HudSkin.region("detail").position
	if at >= 0:
		_glove.point_at(col.position + Vector2(2, HudSkin.px(MenuColumn.HEAD + (at + 0.5) * MenuColumn.ROW)))
	else:
		_glove.visible = false


## a click on the menu column: a command on the bare menu; once a list is open, the column holds the list before it,
## and a click there goes back to it
func _pick_main(i: int) -> void:
	var sr := screen_ref
	if _view.get("sub", []).is_empty():
		sr.choose(_view.commands[i])
		return
	if _view.depth <= 1:
		var c: int = _view.commands[i]
		if c != Command.index_of("act"):
			sr.screen = {"k": "menu", "index": c}
			sr.choose(c)
		return
	var back: Variant = Command.cancel_step(sr.battle, sr.screen)
	if typeof(back) == TYPE_DICTIONARY and not back.is_empty():
		sr._apply({"screen": back, "sound": "cancel"})


func _hover_main(i: int) -> void:
	var sr := screen_ref
	if _view.get("sub", []).is_empty() and sr.screen.k == "menu" and _view.commands[i] != sr.screen.index:
		sr.screen = {"k": "menu", "index": _view.commands[i]}
		Sound.play("cursor")
		sr._refresh()


func _list_pick(i: int) -> void:
	var sr := screen_ref
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

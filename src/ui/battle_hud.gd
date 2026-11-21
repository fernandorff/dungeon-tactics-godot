class_name BattleHud
extends Control
## The battle's HUD: the turn list, the acting unit's card, the menu of the screen in play (commands, the Agir lists, the
## lock and slot steps), the strike preview, the help line and the last action's summary; the Status and pause windows.
## Only shows and passes clicks along to the battle screen.

var screen_ref: BattleScreen
var _turns: VBoxContainer
var _card: Label
var _menu: VBoxContainer
var _menu_title: Label
var _info: Label
var _log: Label
var _help: Label
var _window: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	var tl := Kit.panel(self, Vector2(16, 16), Vector2(250, 0))
	tl.add_child(Kit.label(Texts.t("Ordem dos turnos", "Turn order"), 14, Kit.MUTED))
	_turns = VBoxContainer.new()
	tl.add_child(_turns)
	var card := Kit.panel(self, Vector2(16, -16), Vector2(330, 0), PRESET_BOTTOM_LEFT)
	_card = Kit.label("", 16)
	card.add_child(_card)
	var menu := Kit.panel(self, Vector2(-16, 120), Vector2(360, 0), PRESET_TOP_RIGHT)
	_menu_title = Kit.label("", 15, Kit.MUTED)
	menu.add_child(_menu_title)
	_menu = VBoxContainer.new()
	menu.add_child(_menu)
	var info := Kit.panel(self, Vector2(0, -16), Vector2(620, 0), PRESET_CENTER_BOTTOM)
	_info = Kit.label("", 15)
	info.add_child(_info)
	_log = Kit.label("", 14, Kit.ACCENT)
	info.add_child(_log)
	_help = Kit.label("", 13, Kit.MUTED)
	info.add_child(_help)
	var top := Kit.panel(self, Vector2(-16, 16), Vector2(360, 0), PRESET_TOP_RIGHT)
	var title := Kit.label("", 15)
	title.name = "Title"
	top.add_child(title)
	var pause := Kit.button(Texts.t("Menu (Esc)", "Menu (Esc)"), open_pause)
	top.add_child(pause)


func refresh() -> void:
	if screen_ref == null or _turns == null:
		return
	var b := screen_ref.battle
	(find_child("Title", true, false) as Label).text = Texts.t(screen_ref.scenario.get("name", ""), screen_ref.scenario.get("en", ""))
	for c in _turns.get_children():
		c.queue_free()
	for e in TurnQueue.preview_order(b.state, 8):
		var u := Combat.find_unit(b.state, e.unit)
		if u.is_empty():
			continue
		var col: Color = Kit.HERO if u.team == "hero" else Kit.FOE
		var ab: String = e.get("ability", "")
		var line := "%s  %d/%d" % [Texts.unit_name(u.def), u.hp, Content.units[u.def].hp]
		if ab != "":
			line = "⏳ %s: %s" % [Texts.unit_name(u.def), Texts.ability_name(ab)]
		_turns.add_child(Kit.label(line, 14, col))
	if not b.over():
		_card.text = _card_text(b.actor())
	_log.text = screen_ref.last_log
	_draw_menu()


func _card_text(u: Dictionary) -> String:
	var def: Dictionary = Content.units[u.def]
	var cls := Roster.class_of(u.def)
	var head := Texts.unit_name(u.def)
	if cls != "":
		head += " · " + Texts.unit_name(cls)
	var lines: Array = [head, "%s %d/%d" % [Texts.t("Vida", "HP"), u.hp, def.hp]]
	for k in Content.RESOURCES:
		if def.get("vars", {}).get(k, 0):
			lines.append("%s %d/%d" % ["Mana" if k == "mana" else "Stamina", Combat.pool_of(u, k), def.vars[k]])
	var turn: Dictionary = screen_ref.battle.state.turn
	var acts: Array = []
	acts.append(Texts.t("principal ", "main ") + ("✗" if turn.main else "✓"))
	acts.append(Texts.t("secundária ", "bonus ") + ("✗" if turn.bonus else "✓"))
	lines.append(" · ".join(acts))
	return "\n".join(lines)


func _row(text: String, on: bool, focused: bool, note: String, pick: Callable, hover: Callable) -> void:
	var b := Kit.button(text + ("" if note == "" else "\n   " + note), pick)
	b.disabled = false
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.modulate = Color(1, 1, 1) if on else Color(0.6, 0.6, 0.62)
	if focused:
		b.add_theme_stylebox_override("normal", Kit.focus_box())
		b.add_theme_stylebox_override("hover", Kit.focus_box())
	b.mouse_entered.connect(hover)
	_menu.add_child(b)


func _draw_menu() -> void:
	for c in _menu.get_children():
		c.queue_free()
	var sr := screen_ref
	var b := sr.battle
	_info.text = ""
	_help.text = Texts.t("Setas/clique: escolher · Enter/A: confirmar · Esc/B: voltar · Q/E: girar · F: virar · Z: desfazer", "Arrows/click: choose · Enter/A: confirm · Esc/B: back · Q/E: turn · F: face · Z: undo")
	if b.over() or not sr.is_hero_turn():
		_menu_title.text = Texts.t("Vez do inimigo", "Enemy turn") if not b.over() else ""
		return
	var s := sr.screen
	match s.k:
		"menu":
			_menu_title.text = Texts.unit_name(b.actor().def)
			var rows := Command.menu_rows(b)
			for c in rows:
				var i := Command.index_of(c)
				_row(Texts.command_name(c), Command.enabled(b, c), s.index == i, "", func() -> void: sr.choose(i), func() -> void: pass)
		"map":
			_menu_title.text = Texts.t("Mover: escolha a casa", "Move: pick the tile")
			_info.text = Texts.t("Enter ou clique de novo para andar até lá.", "Enter or click again to walk there.")
		"facing":
			_menu_title.text = Texts.t("Virar: escolha o lado", "Face: pick the side")
			_info.text = Texts.t("Setas para virar · Enter termina o turno", "Arrows to turn · Enter ends the turn")
		_:
			_draw_act(s)


func _draw_act(s: Dictionary) -> void:
	var sr := screen_ref
	var b := sr.battle
	var titles := {"acts": Texts.t("Agir", "Act"), "group": "", "targets": Texts.t("Escolher alvo", "Pick a target"), "actions": Texts.t("Ações no alvo", "Actions on the target"), "aim": Texts.t("Onde cai", "Where it lands"), "spot": Texts.t("De onde agir", "Where to act from")}
	_menu_title.text = titles.get(s.k, "")
	if s.k == "group":
		_menu_title.text = {"skills": Texts.t("Técnicas", "Skills"), "magic": Texts.t("Magias", "Magic"), "items": Texts.t("Itens", "Items")}[s.group]
	var st := ActTurn.step_of(s)
	if not st.is_empty():
		for i in st.rows.size():
			var r: String = st.rows[i]
			var label: String = {"unit": Texts.t("Travar no personagem", "Lock on the character"), "tile": Texts.t("Travar na casa", "Lock on the tile"), "main": Texts.t("Ação principal", "Main action"), "bonus": Texts.t("Ação secundária (metade)", "Bonus action (half)")}[r]
			var idx: int = i
			_row(label, true, r == st.at, "", func() -> void: sr._apply(ActTurn.pick(b, sr.screen, idx)), func() -> void: sr._apply(ActTurn.hover(b, sr.screen, idx)))
		_info.text = _preview_text(sr.preview())
		return
	if s.k == "aim" or s.k == "spot":
		var pts := ActTurn.map_points(b, s)
		var a := ActTurn.screen_action(b, s)
		var name := _action_name(a)
		_menu.add_child(Kit.label("%s · %d %s" % [name, pts.size(), Texts.t("opções", "options")], 15))
		_menu.add_child(Kit.label(Texts.t("Setas ou clique no mapa · Enter confirma", "Arrows or click on the map · Enter confirms"), 13, Kit.MUTED))
		_info.text = _preview_text(sr.preview())
		return
	var rows := ActTurn.rows_of(b, s)
	for i in rows.size():
		var r: Dictionary = rows[i]
		var idx := i
		var on: bool = r.get("enabled", true)
		_row(_row_text(b, r), on, s.index == i, "" if on else Texts.act_reason(r), func() -> void: sr._apply(ActTurn.pick(b, sr.screen, idx)), func() -> void: sr._apply(ActTurn.hover(b, sr.screen, idx)))
	if s.index < rows.size():
		var r: Dictionary = rows[s.index]
		if r.k == "ability":
			_info.text = Texts.ability_detail(r.id)
		elif r.k == "item":
			_info.text = Texts.item_detail(r.id)
		elif r.k == "unit":
			_info.text = _unit_line(b, r.unit)


func _action_name(a: Dictionary) -> String:
	if a.is_empty():
		return ""
	return Texts.ability_name(a.id) if a.k == "ability" else Texts.item_name(a.id)


func _row_text(b: Battle, r: Dictionary) -> String:
	match r.k:
		"pick":
			return Texts.t("Escolher alvo", "Pick a target")
		"group":
			return "%s (%d)" % [{"skills": Texts.t("Técnicas", "Skills"), "magic": Texts.t("Magias", "Magic"), "items": Texts.t("Itens", "Items")}[r.group], r.reach]
		"unit":
			var u := Combat.find_unit(b.state, r.unit)
			return "%s  %d/%d · %s" % [Texts.unit_name(u.def), u.hp, Content.units[u.def].hp, Texts.distance_text(ActFlow.distance_to(b, r.unit), b.grid.sub > 1)]
		"direct":
			return "%s (%s)" % [Texts.ability_name(r.ability), Texts.t("no chão", "on the ground")]
		"side":
			return Texts.t("Escolher aliados", "Pick allies") if r.side == "ally" else Texts.t("Escolher inimigos", "Pick foes")
		"ability":
			var a: Dictionary = Content.abilities[r.id]
			var tag := Texts.kind_tag(r)
			var cost := Texts.cost_text(a)
			var extra := ", ".join([cost, tag].filter(func(x: String) -> bool: return x != ""))
			return Texts.ability_name(r.id) + ("" if extra == "" else "  (%s)" % extra)
		"item":
			return "%s ×%d" % [Texts.item_name(r.id), r.get("count", 0)]
	return ""


func _unit_line(b: Battle, id: String) -> String:
	var u := Combat.find_unit(b.state, id)
	return "%s · %s %d/%d" % [Texts.unit_name(u.def), Texts.t("vida", "HP"), u.hp, Content.units[u.def].hp]


func _preview_text(p: Variant) -> String:
	if p == null or not p.get("ok", false):
		return ""
	var lines: Array = []
	var b := screen_ref.battle
	for t in p.targets:
		var u := Combat.find_unit(b.state, t.unit)
		var name: String = Texts.unit_name(u.def) if not u.is_empty() else t.unit
		var parts: Array = []
		if t.dmgMax > 0:
			parts.append(Texts.t("%d%% · dano %s", "%d%% · damage %s") % [t.chance, Texts.range_text([t.dmgMin, t.dmgMax])])
		if t.healMax > 0:
			parts.append(Texts.t("cura %s", "heal %s") % Texts.range_text([t.healMin, t.healMax]))
		if t.get("side", "") in ["side", "back"]:
			parts.append(Texts.t("pelas costas", "from behind") if t.side == "back" else Texts.t("pelo lado", "from the side"))
		lines.append("%s: %s" % [name, ", ".join(parts)])
	return "\n".join(lines)


# --- windows --------------------------------------------------------------------------------------

func _close_window() -> void:
	if _window:
		_window.queue_free()
		_window = null
	screen_ref.paused = false


func open_status(id: String) -> void:
	_close_window()
	screen_ref.paused = true
	var rows := Texts.unit_status(screen_ref.battle.state, id)
	var lines: Array = []
	for r in rows:
		lines.append("%s: %s" % [r[0], r[1]])
	_window = Kit.dialog(self, "Status · " + Texts.unit_name(Combat.find_unit(screen_ref.battle.state, id).def), "\n".join(lines), [[Texts.t("Fechar", "Close"), _close_window]])


func open_pause() -> void:
	_close_window()
	screen_ref.paused = true
	var leave := Texts.t("Sair da sala (perde a expedição)", "Leave the room (loses the expedition)") if screen_ref.room != null else Texts.t("Voltar ao título", "Back to the title")
	_window = Kit.dialog(self, Texts.t("Pausa", "Pause"), "", [
		[Texts.t("Continuar", "Resume"), _close_window],
		[Texts.t("Recomeçar a batalha", "Restart the battle"), func() -> void:
			_close_window()
			screen_ref.restart()],
		[leave, func() -> void:
			_close_window()
			screen_ref.left_battle.emit()],
	])

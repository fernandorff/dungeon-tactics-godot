class_name MenuView
## Pure side of the command menu (port of the web game's menu3d/menu-view.ts): the rows the menu, the Agir lists and the
## lock and slot steps show, which icon stands for each row, and the action sheet of the focused row. No nodes here.
## A row: {label, note, off, icon, below, gauge}; `icon` an atlas id (Icons) or "status"; `gauge` -1 for none.
## A view: {head, rows, commands, index, depth, sub, sub_title, sub_index, sheet}; `sub` empty while the menu is alone.


static func _row(label: String, note: String = "", off: bool = false, icon: String = "strike", below: bool = false, gauge: float = -1.0) -> Dictionary:
	return {"label": label, "note": note, "off": off, "icon": icon, "below": below, "gauge": gauge}


## the menu of a turn screen, or {} while it is closed (`open`: a hero's turn with nothing playing)
static func of(b: Battle, s: Dictionary, open: bool) -> Dictionary:
	if open and ActTurn.is_act(s) and s.k != "aim" and (s.k != "spot" or s.get("lock", "") != "" or s.get("slot", "") != ""):
		return _act_view(b, s)
	if not open or s.k != "menu":
		return {}
	var col := _column(b)
	col.merge({"index": col.commands.find(s.index), "depth": 0, "sub": [], "sub_title": "", "sub_index": -1, "sheet": {}})
	return col


## the command column: the acting unit's name on its head and the rows Command.menu_rows shows
static func _column(b: Battle) -> Dictionary:
	var rows: Array = []
	var cmds: Array = []
	for c in Command.menu_rows(b):
		var note := ""
		var gauge := -1.0
		if c == "act":
			note = act_note(b)
		elif c == "move":
			var most: int = Effects.move_of(b.state, b.actor())
			var left := maxi(0, most - b.state.turn.get("spent", 0))
			note = "%d/%d" % [left, most]
			gauge = float(left) / maxi(1, most)
		rows.append(_row(Texts.command_name(c), note, not Command.enabled(b, c), Icons.COMMAND.get(c, "status"), false, gauge))
		cmds.append(Command.index_of(c))
	return {"head": Texts.unit_name(b.actor().def), "rows": rows, "commands": cmds}


## the Agir row's note (Fernando, Nov 19): a big dot for the main action and a small one for the bonus, hollow once
## spent, after why nothing can be done this turn when so
static func act_note(b: Battle) -> String:
	var turn: Dictionary = b.state.turn
	var dots := "%s %s" % ["◯" if turn.main else "⬤", "○" if turn.bonus else "●"]
	var why := ""
	if not Command.can_act(b):
		why = Texts.t("na água", "in water") if Command.swimming(b) else Texts.t("sem ações", "no actions")
	elif not ActFlow.act_list(b).any(func(r: Dictionary) -> bool: return r.k != "pick" and r.enabled):
		why = Texts.t("sem alvos", "no targets")
	return dots if why == "" else why + "  " + dots


static func _group_name(g: String) -> String:
	return {"skills": Texts.t("Técnicas", "Skills"), "magic": Texts.t("Magias", "Magic"), "items": Texts.t("Itens", "Items")}[g]


## the list a screen shows, its head and its focused row
static func _list(b: Battle, s: Dictionary) -> Dictionary:
	if s.k == "spot":
		var id: String = ActTurn.screen_action(b, s).get("id", "")
		var name := Texts.ability_name(id) if Content.abilities.has(id) else ""
		if s.get("slot", "") != "":
			var share: int = Content.abilities.get(id, {}).get("bonusShare", 100)
			return {"title": Texts.t("%s: qual ação?", "%s: which action?") % name, "index": 1 if s.slot == "bonus" else 0, "rows": [
				_row(Texts.t("Ação principal · 100%", "Main action · 100%"), "", false, "strike"),
				_row(Texts.t("Secundária · %d%%", "Bonus · %d%%") % share, "", false, "move"),
			]}
		return {"title": Texts.t("%s: travar onde?", "%s: lock on?") % name, "index": 1 if s.lock == "tile" else 0, "rows": [
			_row(Texts.t("No personagem", "On the character"), "", false, "strike"),
			_row(Texts.t("Na casa", "On the tile"), "", false, "move"),
		]}
	var rows: Array = []
	for r in ActTurn.rows_of(b, s):
		rows.append(_target_row(b, r) if s.k == "targets" else list_row(b, r))
	var title: String = {"acts": Texts.t("Agir", "Act"), "targets": Texts.t("Alvo", "Target"), "actions": Texts.t("Ação", "Action")}.get(s.k, "")
	if s.k == "group":
		title = _group_name(s.group)
	return {"title": title, "rows": rows, "index": s.index}


## the screen whose list stood beside this one's: it slides into the menu's place while this one opens where it was
## (Fernando's grill, Nov 19); the Agir list's is the menu itself ({}), as is the lock step's
static func _parent(b: Battle, s: Dictionary) -> Dictionary:
	var at := func(rows: Array, ref: Dictionary) -> int:
		for i in rows.size():
			if ActFlow.same_ref(ref, rows[i]):
				return i
		return 0
	if s.k == "group":
		var list := ActFlow.act_list(b)
		for i in list.size():
			if list[i].k == "group" and list[i].group == s.group:
				return {"k": "acts", "index": i}
		return {"k": "acts", "index": 0}
	if s.k == "targets":
		var only: Dictionary = s.get("only", {})
		if only.is_empty():
			return {"k": "acts", "index": 0}
		var g := ActFlow.group_of(b, only)
		if g != "":
			return {"k": "group", "group": g, "index": at.call(ActFlow.act_group(b, g), only)}
		return {"k": "acts", "index": at.call(ActFlow.act_list(b), only)}
	if s.k == "actions":
		var ts := ActFlow.act_targets(b)
		for i in ts.size():
			if ts[i] == s.target:
				return {"k": "targets", "index": i}
		return {"k": "targets", "index": 0}
	return {}


static func _depth(b: Battle, s: Dictionary) -> int:
	return 0 if s.is_empty() else 1 + _depth(b, _parent(b, s))


## the Agir lists beside the command menu with Agir picked; deeper lists slide the one before into the menu's place
static func _act_view(b: Battle, s: Dictionary) -> Dictionary:
	var here := _list(b, s)
	var up := _parent(b, s)
	var v := _column(b)
	if up.is_empty():
		v.index = v.commands.find(Command.index_of("act"))
	else:
		var menu := _list(b, up)
		v.head = menu.title
		v.rows = menu.rows
		v.index = menu.index
	v.depth = _depth(b, s)
	v.sub = here.rows
	v.sub_title = here.title
	v.sub_index = here.index
	var focused: Dictionary = {}
	if s.k in ["acts", "group", "actions"]:
		var rows := ActTurn.rows_of(b, s)
		if s.index >= 0 and s.index < rows.size():
			focused = rows[s.index]
	v.sheet = sheet(b, focused, s.get("page", 0))
	return v


## the sheet of the focused action (on or off: the cursor passes over an off one to read it): an ability's three pages,
## an item's one; {} for the rows that are not an action
static func sheet(b: Battle, a: Dictionary, page: int = 0) -> Dictionary:
	if a.is_empty() or not a.k in ["ability", "item"]:
		return {}
	var owner := Texts.unit_name(b.actor().def)
	if a.k == "item":
		return {"owner": owner, "name": Texts.item_name(a.id), "icon": "heal", "page": 0, "pages": [{"title": Texts.t("Descrição", "Description"), "text": Texts.item_detail(a.id)}]}
	var titles := [Texts.t("Descrição", "Description"), Texts.t("Efeitos", "Effects"), Texts.t("Custo", "Cost")]
	var empty := ["", Texts.t("Nenhum efeito além do golpe.", "No effect beyond the strike."), Texts.t("Sem custo; sai na hora.", "No cost; fires at once.")]
	var pages: Array = []
	var facts_by_page := Texts.ability_pages(a.id)
	for i in facts_by_page.size():
		var lines: Array = []
		for f: String in facts_by_page[i]:
			lines.append(f.left(1).to_upper() + f.substr(1) + ".")
		pages.append({"title": titles[i], "text": "\n".join(lines) if lines.size() else empty[i]})
	return {"owner": owner, "name": Texts.ability_name(a.id), "icon": a.id, "page": posmod(page, pages.size()), "pages": pages}


## a row of the target list: who, its life and how far it is now (half tiles, as Move shows)
static func _target_row(b: Battle, r: Dictionary) -> Dictionary:
	if r.k == "side":
		return _row(Texts.t("Escolher aliados", "Pick allies"), "", false, "shield_bash") if r.side == "ally" else _row(Texts.t("Escolher inimigos", "Pick enemies"))
	if r.k == "direct":
		return _row(Texts.ability_name(r.ability), Texts.t("na área", "on the area"), false, r.ability)
	var u := Combat.find_unit(b.state, r.unit)
	var me := b.actor()
	var far := Texts.t("você", "you") if u.id == me.id else Texts.distance_text(ActFlow.distance_to(b, u.id), b.grid.sub > 1)
	# the shield or the sword says ally or enemy; the word went so the name keeps its size (web, Nov 19)
	return _row(Texts.unit_name(u.def), "%d/%d · %s" % [u.hp, Content.units[u.def].hp, far], false, "shield_bash" if u.team == me.team else "strike")


## a row of the Agir list or of the actions screen: its note (an off one's reason) is a line under the name
static func list_row(b: Battle, a: Dictionary) -> Dictionary:
	if a.k == "pick":
		return _row(Texts.t("Escolher alvo", "Pick a target")) if a.enabled else _row(Texts.t("Escolher alvo", "Pick a target"), Texts.t("sem alvos", "no targets"), true, "strike", true)
	if a.k == "group":
		return _row(_group_name(a.group), reach_text(a) if a.enabled else Texts.t("sem alvos", "no targets"), not a.enabled, Icons.GROUP[a.group], true)
	var parts: Array = [Texts.kind_tag(a)]
	if a.k == "item":
		parts.append("×%d" % a.get("count", 0) if a.enabled else Texts.act_reason(a))
	else:
		var ab: Dictionary = Content.abilities[a.id]
		var note := Texts.cost_text(ab)
		if ab.charge:
			note = (note + " · " if note != "" else "") + Texts.t("%d tiq.", "%d tk") % ab.charge
		parts.append(note if a.enabled else Texts.act_reason(a))
	parts.append(reach_text(a))
	var line := " · ".join(parts.filter(func(x: String) -> bool: return x != ""))
	return _row(Texts.item_name(a.id) if a.k == "item" else Texts.ability_name(a.id), line, not a.enabled, "heal" if a.k == "item" else a.id, true)


## how many targets a row of the Agir list has this turn
static func reach_text(a: Dictionary) -> String:
	var n: int = a.get("reach", 0)
	if n <= 0:
		return ""
	return Texts.t("%d alvo%s", "%d target%s") % [n, "s" if n > 1 else ""]

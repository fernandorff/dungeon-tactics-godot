class_name Command
## The turn menu FFT style (port of command.ts): Agir · Move · Undo move · Wait · Status, and where Cancel leads from each
## screen. Pure: the battle screen executes and draws. A screen is a Dictionary:
## {k: "menu", index} | {k: "map"} (Move) | {k: "facing"} | {k: "acts", index} | {k: "group", group, index} |
## {k: "targets", index, only?, other?} | {k: "actions", target, index} | {k: "aim", target, action, index, only?} |
## {k: "spot", target, action, index, lock?, slot?, aim?, only?}

const COMMANDS := ["act", "move", "undo", "wait", "status"]
const PAGES := 3


static func index_of(c: String) -> int:
	return COMMANDS.find(c)


## a charge aimed at someone asks next where to lock it: the tile, or that character
static func needs_lock(b: Battle, ability: String, target: Vector2i) -> bool:
	var on := Pathing.unit_at(b.state, target)
	return Content.abilities[ability].charge > 0 and not on.is_empty() and on.id != b.actor().id


static func can_undo_move(b: Battle) -> bool:
	return b.state.turn.moved and b.last_free() and b.can_undo()


## in deep water a unit can only move or wait
static func swimming(b: Battle) -> bool:
	return Grid.is_deep(b.grid.tile(b.actor().pos))


static func can_act(b: Battle) -> bool:
	return Slots.free_slot(b.state.turn, "bonus") != "" and not swimming(b)


static func enabled(b: Battle, c: String) -> bool:
	if c == "move":
		return b.reach().size() > 0
	if c == "undo":
		return can_undo_move(b)
	# greyed like Move once no action is left, and choosing it says no (Fernando, Nov 21; it used to open to look)
	if c == "act":
		return can_act(b)
	return true


## Move always stays, greyed with its gauge at zero once spent or boxed in (Fernando, Nov 21: it used to leave); "Undo
## move" only while there is a move to take back
static func menu_rows(b: Battle) -> Array:
	return COMMANDS.filter(func(c: String) -> bool: return c != "undo" or can_undo_move(b))


## Move if it can still move, else Agir, else Wait; "Undo move" never takes the cursor
static func start_screen(b: Battle) -> Dictionary:
	var r := b.reach().size()
	var c := "move" if r and not b.state.turn.moved else ("act" if can_act(b) else ("move" if r else "wait"))
	return {"k": "menu", "index": index_of(c)}


static func _row_of(rows: Array, pred: Callable) -> int:
	for i in rows.size():
		if pred.call(rows[i]):
			return i
	return 0


## one step back, on the row it came from; "undo" on the menu after a free move; {} with nothing to go back to
static func cancel_step(b: Battle, s: Dictionary) -> Variant:
	match s.k:
		"menu":
			# after a free move Esc undoes it, like Tactics Ogre; on the bare menu nothing, the screen opens Options (Nov 21)
			return "undo" if can_undo_move(b) else {}
		"map":
			return {"k": "menu", "index": index_of("move")}
		"facing":
			return {"k": "menu", "index": index_of("wait")}
		"acts":
			return {"k": "menu", "index": index_of("act")}
		"group":
			return {"k": "acts", "index": _row_of(ActFlow.act_list(b), func(r: Dictionary) -> bool: return r.k == "group" and r.group == s.group)}
		"targets":
			if s.get("other", false):
				return {"k": "targets", "index": _row_of(ActFlow.act_targets(b, s.get("only", {})), func(r: Dictionary) -> bool: return r.k == "side"), "only": s.get("only", {})}
			return _back_to(b, s.only) if s.has("only") else {"k": "acts", "index": 0}
		"actions":
			return {"k": "targets", "index": ActFlow.target_index(ActFlow.act_targets(b), s.target)}
	var only: Dictionary = s.get("only", {})
	var other := false
	if not only.is_empty():
		other = not ActFlow.act_targets(b, only).any(func(r: Dictionary) -> bool: return Util.diff(r, s.target) == "")
	var out: Dictionary
	if not only.is_empty():
		out = {"k": "targets", "index": ActFlow.target_index(ActFlow.act_targets(b, only, other), s.target), "only": only}
		if other:
			out.other = true
	else:
		out = {"k": "actions", "target": s.target, "index": s.action}
	if s.k == "aim":
		return out
	if s.get("lock", "") != "" or s.get("slot", "") != "":
		var back := {"k": "spot", "target": s.target, "action": s.action, "index": s.index}
		if s.has("aim"):
			back.aim = s.aim
		if not only.is_empty():
			back.only = only
		return back
	if not s.has("aim"):
		return out
	var aims := ActFlow.act_aims(ActFlow.act_actions(b, s.target)[s.action])
	var aim := {"k": "aim", "target": s.target, "action": s.action, "index": maxi(0, aims.find(s.aim))}
	if not only.is_empty():
		aim.only = only
	return aim


## where an action's target list goes back to: its row on the Agir list (the basic attack) or in its group's column
static func _back_to(b: Battle, only: Dictionary) -> Dictionary:
	var group := ActFlow.group_of(b, only)
	if group == "":
		return {"k": "acts", "index": _row_of(ActFlow.act_list(b), func(r: Dictionary) -> bool: return ActFlow.same_ref(only, r))}
	return {"k": "group", "group": group, "index": _row_of(ActFlow.act_group(b, group), func(r: Dictionary) -> bool: return ActFlow.same_ref(only, r))}


static func turn_page(page: int, dir: int) -> int:
	return (page + dir + PAGES) % PAGES


## up or down the menu skipping what is greyed out, wrapping around as in FFT
static func step_index(index: int, dir: int, on: Array) -> int:
	var n := on.size()
	for k in range(1, n + 1):
		var i := (index + dir * k + n * k) % n
		if on[i]:
			return i
	return index

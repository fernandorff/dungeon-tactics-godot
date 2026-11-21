class_name Battle
extends RefCounted
## The battle aggregate (port of battle.ts): owner of the state, the undo history and the save. The rules live in the
## static engine classes; only what has a lifecycle lives here.

const UNDO_LIMIT := 3
const SAVE_VERSION := 2

var grid: Grid
var state: Dictionary
var undos_left: int
## [{before: state without rng, paid: bool}]
var history: Array
var _reach_memo: Variant = null
var _reach_key := 0


func _init(g: Grid, s: Dictionary, undos: int = UNDO_LIMIT, hist: Array = []) -> void:
	grid = g
	state = s
	undos_left = undos
	history = hist


static func start(scenario: Dictionary, seed: int) -> Battle:
	var s := Scenarios.initial_state(scenario, seed)
	TurnQueue.start_next_turn(scenario.grid, s)
	return Battle.new(scenario.grid, s)


func actor() -> Dictionary:
	return Combat.find_unit(state, state.turn.actor)


func over() -> bool:
	return state.outcome != "ongoing"


## the last step was a free walk: the menu offers "Undo move"
func last_free() -> bool:
	if history.is_empty():
		return false
	var last: Dictionary = history.back()
	return not last.paid and last.before.turn.main == state.turn.main and last.before.turn.bonus == state.turn.bonus


func can_undo() -> bool:
	if history.is_empty():
		return false
	var last: Dictionary = history.back()
	return not last.paid or undos_left > 0


func reach() -> Dictionary:
	if over():
		return {}
	# a 2x2 token's walk costs ~120 ms and the screens ask for it several times a key press: once per state
	var key := state.hash()
	if _reach_memo == null or key != _reach_key:
		var left: int = Effects.move_of(state, actor()) - state.turn.get("spent", 0)
		_reach_memo = {} if left <= 0 else Pathing.reachable(grid, state, actor().id, left)
		_reach_key = key
	return _reach_memo


func preview(ability_id: String, target: Vector2i) -> Dictionary:
	return Combat.preview(grid, state, actor().id, ability_id, target)


func move(to: Vector2i) -> Array:
	var r := reach()
	var path: Variant = Pathing.path_to(r, to)
	if path == null:
		return []
	_remember(false)
	var from: Vector2i = actor().pos
	var id: String = actor().id
	var owed := Counter.pending(grid, state, id, to)
	var first: Array = []
	var later: Array = []
	for c in owed:
		if c.at == from:
			first.append(c)
		else:
			later.append(c)
	var hit := Counter.play(grid, state, id, first)
	if hit.size():
		history = []
	state.outcome = Outcome.check(state)
	if Combat.find_unit(state, id).is_empty() or over():
		return hit
	var turn: Dictionary = state.turn
	turn.spent = turn.get("spent", 0) + r[Grid.pos_key(to)].cost
	var a := actor()
	if a.has("facing"):
		a.facing = Grid.facing_to(path[path.size() - 2] if path.size() >= 2 else from, to)
	a.pos = to
	turn.moved = true
	var full: Array = [from]
	full.append_array(path)
	var walk := {"k": "move", "unit": id, "path": full}
	var shot := Counter.play(grid, state, id, later)
	if shot.size():
		history = []
	state.outcome = Outcome.check(state)
	return hit + [walk] + shot


## `lock`: "tile" or "unit" for a charge ("" = the ability's default); `as_slot`: the slot picked for a dual action
func act(ability_id: String, target: Vector2i, lock: String = "", as_slot: String = "") -> Array:
	if not Content.abilities.has(ability_id):
		return []
	var ability: Dictionary = Content.abilities[ability_id]
	var slot := Slots.slot_for(state.turn, ability, as_slot)
	if over() or slot == "" or not preview(ability_id, target).ok:
		return []
	_remember(ability.charge == 0)
	var a := actor()
	if a.has("facing") and target != a.pos:
		a.facing = Pathing.turned_to(grid, state, a, a.pos, Grid.facing_to(a.pos, target))
	var events: Array
	var turn: Dictionary = state.turn
	if ability.charge > 0:
		Pools.pay(a, ability)
		var left := maxi(0, Effects.move_of(state, a) - turn.get("spent", 0))
		turn.spent = turn.get("spent", 0) + Util.ceil_div(left, 2)
		var lk := lock if lock != "" else ("tile" if ability.get("panel", false) else "unit")
		var follow: Variant = null
		if lk == "unit":
			var t := Pathing.unit_at(state, target)
			follow = t.id if not t.is_empty() else null
		var charges: Array = []
		for c in state.charges:
			if c.unit != a.id:
				charges.append(c)
		charges.append({"unit": a.id, "ability": ability_id, "target": target, "follow": follow, "ticks": ability.charge})
		state.charges = charges
		events = [{"k": "charge", "unit": a.id, "ability": ability_id, "target": target}]
	else:
		events = Combat.resolve(grid, state, a.id, ability_id, target, false, Slots.slot_scale(ability, slot))
		var owed: Array = turn.get("engaged", []).duplicate()
		for e in events:
			if e.k == "hit" or e.k == "miss":
				var foe := Combat.find_unit(state, e.unit)
				if not foe.is_empty() and Counter.can_counter(a, ability_id, foe) and not owed.has(foe.id):
					owed.append(foe.id)
		if owed.size():
			turn.engaged = owed
	turn[slot] = ability_id
	return events


## the Item command (bag.gd): no die, so undoing it is free and gives the item back
func use_item(item: String, target: Vector2i) -> Array:
	if over() or Bag.item_effect(grid, state, actor().id, item, target).is_empty():
		return []
	_remember(false)
	var a := actor()
	if a.has("facing") and target != a.pos:
		a.facing = Pathing.turned_to(grid, state, a, a.pos, Grid.facing_to(a.pos, target))
	return Bag.apply_item(grid, state, a.id, item, target)


func face(dir: int) -> void:
	var a := actor()
	if not over() and a.has("facing") and dir >= 0 and dir < 4 and Pathing.body_fits(grid, state, a, a.pos, dir):
		a.facing = dir


func end_turn() -> Array:
	history = []
	if over():
		return []
	var spiked := Combat.spike_at_turn_end(grid, state)
	TurnQueue.finish_turn(state)
	state.outcome = Outcome.check(state)
	return spiked + ([] if over() else TurnQueue.start_next_turn(grid, state))


func undo() -> bool:
	if not can_undo():
		return false
	var e: Dictionary = history.pop_back()
	if e.paid:
		undos_left -= 1
	var rng: int = state.rng
	state = e.before.duplicate(true)
	state.rng = rng
	return true


func clone() -> Battle:
	return Battle.new(grid, state.duplicate(true), undos_left, history.duplicate(true))


func save() -> String:
	return JSON.stringify({"v": SAVE_VERSION, "state": Util.plain(state), "undosLeft": undos_left, "history": Util.plain(history)})


## a save may be old, edited or broken: any doubt returns null
static func load_save(json: String) -> Battle:
	if json == "":
		return null
	var raw: Variant = JSON.parse_string(json)
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	raw = Util.ints(raw)
	if raw.get("v") != SAVE_VERSION:
		return null
	var s: Variant = ParseState.parse(raw.get("state"))
	var undos: Variant = raw.get("undosLeft")
	if s == null or typeof(undos) != TYPE_INT or undos < 0 or undos > UNDO_LIMIT:
		return null
	var hist: Variant = raw.get("history")
	if typeof(hist) != TYPE_ARRAY or hist.size() > 4:
		return null
	var out: Array = []
	for e in hist:
		if typeof(e) != TYPE_DICTIONARY or typeof(e.get("paid")) != TYPE_BOOL or typeof(e.get("before")) != TYPE_DICTIONARY:
			return null
		var b: Dictionary = e.before.duplicate()
		b.rng = 0
		var frame: Variant = ParseState.parse(b)
		if frame == null:
			return null
		if frame.scenario != s.scenario or frame.turn.actor != s.turn.actor:
			out = []
			break
		frame.erase("rng")
		out.append({"before": frame, "paid": e.paid})
	return Battle.new(Content.scenarios[s.scenario].grid, s, undos, out)


func _remember(paid: bool) -> void:
	var before := state.duplicate(true)
	before.erase("rng")
	history.append({"before": before, "paid": paid})

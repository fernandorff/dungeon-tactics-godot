class_name ActTurn
## The keys, taps and rows of the Agir screens on a hero's turn (port of act-turn.ts and act-marks.ts). Pure: each call
## takes the battle and the screen and returns what follows: {screen, focus?: Vector2i, run?: {action, spot, lock, slot},
## sound: "cursor"/"confirm"/"cancel"/""}. The battle screen applies it. The aim step holds a free cursor `at`.

const LOCKS := ["unit", "tile"]
const SLOT_ROWS := ["main", "bonus"]


static func is_act(s: Dictionary) -> bool:
	return ["acts", "group", "targets", "actions", "aim", "spot"].has(s.k)


## the two-row step on the tile choice (a charge's lock or a dual action's slot)
static func step_of(s: Dictionary) -> Dictionary:
	if s.k != "spot":
		return {}
	if s.get("lock", "") != "":
		return {"rows": LOCKS, "at": s.lock}
	if s.get("slot", "") != "":
		return {"rows": SLOT_ROWS, "at": s.slot}
	return {}


static func default_lock(a: Dictionary) -> String:
	return "tile" if a.get("panel", false) else "unit"


static func _cells_of_target(b: Battle, t: Dictionary) -> Array:
	if t.k != "unit":
		return []
	var u := Combat.find_unit(b.state, t.unit)
	return Pathing.footprint(u) if not u.is_empty() else []


## the cells an aim covers: the unit standing there, else its ground tile
static func aim_cells(b: Battle, aim: Vector2i) -> Array:
	var u := Pathing.unit_at(b.state, aim)
	return Pathing.footprint(u) if not u.is_empty() else Pathing.cells_of(aim, b.grid.sub)


## the action the screen is on (on the tile choice after an aim, only the tiles aiming there)
static func screen_action(b: Battle, s: Dictionary) -> Dictionary:
	if s.k == "acts" or s.k == "group" or s.k == "targets":
		return {}
	var acts := ActFlow.act_actions(b, s.target)
	var i: int = s.index if s.k == "actions" else s.action
	if i < 0 or i >= acts.size():
		return {}
	var a: Dictionary = acts[i]
	# past the aim step the area may land anywhere it reaches, not only on the picked target (free_area)
	if s.k == "aim":
		return ActFlow.free_area(b, a)
	return ActFlow.with_aim(ActFlow.free_area(b, a), s.aim) if s.k == "spot" and s.has("aim") else a


## the aim under the free cursor of the aim step, or null where the area cannot land this turn
static func aim_at(b: Battle, s: Dictionary) -> Variant:
	var a := screen_action(b, s)
	if a.is_empty():
		return null
	for aim in ActFlow.act_aims(a):
		if aim_cells(b, aim).has(s.at):
			return aim
	return null


## the aim step's free cursor moved to `p` (anywhere on the map; Nov 21: it used to jump between the target's aims only)
static func aim_to(s: Dictionary, p: Vector2i, follow: bool = true) -> Dictionary:
	var n := s.duplicate()
	n.at = p
	return _out(n, "cursor", p if follow else null)


static func _same_aim(b: Battle, p: Vector2i, q: Vector2i) -> bool:
	return Pathing.aim_tile(b.grid, b.state, p) == Pathing.aim_tile(b.grid, b.state, q)


static func rows_of(b: Battle, s: Dictionary) -> Array:
	match s.k:
		"acts":
			return ActFlow.act_list(b)
		"group":
			return ActFlow.act_group(b, s.group)
		"targets":
			return ActFlow.act_targets(b, s.get("only", {}), s.get("other", false))
		"actions":
			return ActFlow.act_actions(b, s.target)
	return []


## where the Agir list opens: on the unit's last action while it is on, else on "Escolher alvo"
static func start(b: Battle, last: Dictionary = {}) -> Dictionary:
	if last.is_empty():
		return {"k": "acts", "index": 0}
	var group := ActFlow.group_of(b, last)
	var list := ActFlow.act_list(b)
	var pool: Array = ActFlow.act_group(b, group) if group != "" else list
	var on := pool.any(func(r: Dictionary) -> bool: return ActFlow.same_ref(last, r) and r.enabled)
	if not on:
		return {"k": "acts", "index": 0}
	for i in list.size():
		var r: Dictionary = list[i]
		if (group != "" and r.k == "group" and r.group == group) or (group == "" and ActFlow.same_ref(last, r)):
			return {"k": "acts", "index": i}
	return {"k": "acts", "index": 0}


static func _out(s: Dictionary, sound: String = "", focus: Variant = null) -> Dictionary:
	var o := {"screen": s, "sound": sound}
	if focus != null:
		o.focus = focus
	return o


## up or down a list (every row takes the cursor, an off one too: it shows its facts and Confirm only says no)
static func step(b: Battle, s: Dictionary, dir: int) -> Dictionary:
	var st := step_of(s)
	if not st.is_empty():
		return hover(b, s, 0 if dir < 0 else 1)
	if s.k == "spot":
		var pts := map_points(b, s)
		if pts.is_empty():
			return _out(s)
		var n := s.duplicate()
		n.index = (s.index + dir + pts.size()) % pts.size()
		return _out(n, "cursor", pts[n.index])
	var rows := rows_of(b, s)
	if rows.is_empty():
		return _out(s)
	var n := s.duplicate()
	n.index = (s.index + dir + rows.size()) % rows.size()
	n.erase("page")
	return _select(b, n)


## the mouse or Tab on a list row focuses it
static func hover(b: Battle, s: Dictionary, index: int) -> Dictionary:
	var n := s.duplicate()
	if s.k == "spot" and s.get("lock", "") != "":
		if index < LOCKS.size() and LOCKS[index] != s.lock:
			n.lock = LOCKS[index]
			return _out(n, "cursor")
		return _out(s)
	if s.k == "spot" and s.get("slot", "") != "":
		if index < SLOT_ROWS.size() and SLOT_ROWS[index] != s.slot:
			n.slot = SLOT_ROWS[index]
			return _out(n, "cursor")
		return _out(s)
	if not is_act(s) or s.index == index:
		return _out(s)
	if s.k == "spot":
		if index < 0 or index >= map_points(b, s).size():
			return _out(s)
		n.index = index
		return _out(n, "cursor", map_points(b, s)[index])
	if index < 0 or index >= rows_of(b, s).size():
		return _out(s)
	n.index = index
	n.erase("page")
	return _select(b, n)


static func _select(b: Battle, s: Dictionary) -> Dictionary:
	if s.k == "targets":
		var rows := rows_of(b, s)
		if s.index < rows.size() and rows[s.index].k == "unit":
			return _out(s, "cursor", rows[s.index].pos)
	return _out(s, "cursor")


static func page(s: Dictionary, dir: int) -> Dictionary:
	if s.k != "actions" and s.k != "acts" and s.k != "group":
		return _out(s)
	var n := s.duplicate()
	n.page = Command.turn_page(s.get("page", 0), dir)
	return _out(n, "cursor")


## what the arrows walk on the tile choice (the tiles to act from); empty elsewhere
static func map_points(b: Battle, s: Dictionary) -> Array:
	if s.k != "spot":
		return []
	var a := screen_action(b, s)
	if a.is_empty():
		return []
	return a.spots.map(func(sp: Dictionary) -> Vector2i: return sp.pos)


## the row a map tile stands for on this screen; -1 for none
static func index_at(b: Battle, s: Dictionary, p: Vector2i) -> int:
	if s.k == "targets":
		return ActFlow.target_at(rows_of(b, s), b, p)
	if s.k == "spot" and step_of(s).is_empty():
		return ActFlow.spot_at(screen_action(b, s), p, Content.units[b.actor().def].get("size", 1))
	return -1


## a tap on the map: a unit picks its row (twice: goes on), on the tile choice a tile does the same; null: not an Agir map
static func tap(b: Battle, s: Dictionary, p: Vector2i) -> Variant:
	if not is_act(s):
		return null
	if s.k == "aim":
		return pick(b, s, 0) if _same_aim(b, p, s.at) else aim_to(s, p, false)
	var i := index_at(b, s, p)
	if i < 0:
		return _out(s)
	if i == s.index:
		return pick(b, s, i)
	var n := s.duplicate()
	n.index = i
	return _out(n, "cursor")


## Confirm (or a click on a row): a target opens its actions, an action on opens its tiles, a tile runs it
static func pick(b: Battle, s: Dictionary, index: int) -> Dictionary:
	if s.k == "acts" or s.k == "group":
		var rows := rows_of(b, s)
		if index < 0 or index >= rows.size() or not rows[index].enabled:
			return _out(s, "cancel")
		var row: Dictionary = rows[index]
		if row.k == "group":
			var col := ActFlow.act_group(b, row.group)
			var first := 0
			for i in col.size():
				if col[i].enabled:
					first = i
					break
			return _out({"k": "group", "group": row.group, "index": first}, "confirm")
		return _open_targets(b, {} if row.k == "pick" else {"k": row.k, "id": row.id})
	if s.k == "targets":
		var rows := rows_of(b, s)
		if index < 0 or index >= rows.size():
			return _out(s)
		var target: Dictionary = rows[index]
		if target.k == "side":
			return _open_targets(b, s.get("only", {}), not s.get("other", false))
		var acts := ActFlow.act_actions(b, target)
		if s.has("only") and not s.only.is_empty():
			for i in acts.size():
				if acts[i].k == s.only.k and acts[i].id == s.only.id:
					return _open_action(b, target, i, s.only)
			return _out(s, "cancel")
		var first := 0
		for i in acts.size():
			if acts[i].enabled:
				first = i
				break
		return _out({"k": "actions", "target": target, "index": first}, "confirm")
	if s.k == "actions":
		var acts := ActFlow.act_actions(b, s.target)
		if index < 0 or index >= acts.size() or not acts[index].enabled:
			return _out(s, "cancel")
		return _open_action(b, s.target, index)
	if s.k == "aim":
		# the free cursor may stand where the area cannot land: it says no
		var aim: Variant = aim_at(b, s)
		if aim == null:
			return _out(s, "cancel")
		var a := ActFlow.with_aim(screen_action(b, s), aim)
		var best := ActFlow.best_spot(a, b)
		var n := {"k": "spot", "target": s.target, "action": s.action, "index": best, "aim": aim}
		if s.has("only"):
			n.only = s.only
		return _out(n, "confirm", a.spots[best].pos)
	var a := screen_action(b, s)
	var st := step_of(s)
	var at: int = s.index if not st.is_empty() else index
	if a.is_empty() or at < 0 or at >= a.spots.size():
		return _out(s, "cancel")
	var spot: Dictionary = a.spots[at]
	if s.get("lock", "") == "" and a.k == "ability" and Command.needs_lock(b, a.id, spot.aim):
		var n := s.duplicate()
		n.index = index
		n.lock = default_lock(Content.abilities[a.id])
		return _out(n, "confirm")
	if s.get("slot", "") == "" and ActFlow.needs_slot(b, a):
		var n := s.duplicate()
		n.index = index
		n.slot = "main"
		return _out(n, "confirm")
	var lock: String = LOCKS[index] if s.get("lock", "") != "" and index < 2 else ""
	var as_slot: String = SLOT_ROWS[index] if s.get("slot", "") != "" and index < 2 else ""
	return {"screen": s, "sound": "confirm", "run": {"action": a, "spot": spot, "lock": lock, "slot": as_slot}}


static func _open_targets(b: Battle, only: Dictionary, other: bool = false) -> Dictionary:
	var s := {"k": "targets", "index": 0}
	if not only.is_empty():
		s.only = only
	if other:
		s.other = true
	var rows := ActFlow.act_targets(b, only, other)
	return _out(s, "confirm", rows[0].pos if rows.size() and rows[0].k == "unit" else null)


static func _open_action(b: Battle, target: Dictionary, action: int, only: Dictionary = {}) -> Dictionary:
	var a: Dictionary = ActFlow.act_actions(b, target)[action]
	# several aims (an area): where it lands first, the free cursor starting on the best aim at the picked target
	var area := ActFlow.act_aims(ActFlow.free_area(b, a)).size() > 0
	var best: Dictionary = a.spots[ActFlow.best_spot(a, b)]
	var s: Dictionary
	if area:
		s = {"k": "aim", "target": target, "action": action, "at": best.aim}
	else:
		s = {"k": "spot", "target": target, "action": action, "index": ActFlow.best_spot(a, b)}
	if not only.is_empty():
		s.only = only
	return _out(s, "confirm", best.aim if area else best.pos)


static func _mark(tiles: Array, cells: Array, kind: String) -> void:
	for p in cells:
		tiles.append({"pos": p, "kind": kind})


## what the map marks on an Agir screen: {tiles, path, preview, size}
static func marks(b: Battle, s: Dictionary) -> Dictionary:
	var tiles: Array = []
	var me := b.actor()
	var size: int = Content.units[me.def].get("size", 1)
	if s.k == "acts" or s.k == "group":
		var rows := rows_of(b, s)
		if s.index < rows.size() and rows[s.index].k == "ability":
			var a: Dictionary = Content.abilities[rows[s.index].id]
			var own := Pathing.footprint(me)
			if a.range[1] == 0:
				_mark(tiles, Interaction.attack_marks(b, a, me.pos).map(func(m: Dictionary) -> Vector2i: return m.pos), "range")
			else:
				for y in b.grid.height:
					for x in b.grid.width:
						var p := Vector2i(x, y)
						var one: Array[Vector2i] = [p]
						var ends := Pathing.closest(own, one)
						if not own.has(p) and Reach.in_ability_range(b.grid, a, ends[0], ends[1]):
							tiles.append({"pos": p, "kind": "range"})
		_mark(tiles, Pathing.footprint(me), "actor")
		return {"tiles": tiles, "path": null, "preview": null}
	if s.k == "targets":
		var rows := rows_of(b, s)
		for i in rows.size():
			_mark(tiles, _cells_of_target(b, rows[i]), "target" if i == s.index else "range")
		_mark(tiles, Pathing.footprint(me), "actor")
		return {"tiles": tiles, "path": null, "preview": null}
	var a := screen_action(b, s)
	if s.k == "aim" and not a.is_empty():
		# where it can land, and the area under the free cursor (with its best tile's preview when it can land there)
		var on: Variant = aim_at(b, s)
		for p in ActFlow.act_aims(a):
			if on == null or p != on:
				_mark(tiles, aim_cells(b, p), "range")
		_mark(tiles, _cells_of_target(b, s.target), "target")
		_mark(tiles, Pathing.footprint(me), "actor")
		tiles.append_array(Interaction.attack_marks(b, Content.abilities[a.id], on if on != null else Pathing.aim_tile(b.grid, b.state, s.at)))
		var preview: Variant = null
		if on != null:
			var here := ActFlow.with_aim(a, on)
			var bi := ActFlow.best_spot(here, b)
			if bi >= 0:
				preview = here.spots[bi].get("preview")
		return {"tiles": tiles, "path": null, "preview": preview}
	var spots: Array = a.get("spots", [])
	var seen := {}
	for sp in spots:
		for c in Pathing.cells_of(sp.pos, size):
			if not seen.has(c):
				seen[c] = true
				tiles.append({"pos": c, "kind": "move"})
	_mark(tiles, _cells_of_target(b, s.target), "target")
	var picked: Dictionary = spots[s.index] if s.k == "spot" and s.index >= 0 and s.index < spots.size() else {}
	if picked.is_empty():
		_mark(tiles, Pathing.footprint(me), "actor")
		return {"tiles": tiles, "path": null, "preview": null}
	_mark(tiles, Pathing.cells_of(picked.pos, size), "actor")
	if a.k == "ability" and Content.abilities[a.id].radius > 0:
		tiles.append_array(Interaction.attack_marks(b, Content.abilities[a.id], picked.aim))
	var walk: Variant = null if picked.pos == me.pos else Pathing.path_to(b.reach(), picked.pos)
	return {"tiles": tiles, "path": walk, "preview": ActFlow.spot_preview(b, a, picked, s.get("slot", "")), "size": size}

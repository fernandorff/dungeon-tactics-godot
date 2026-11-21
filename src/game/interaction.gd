class_name Interaction
## What a tile does in battle and what the map marks (port of interaction.ts): Move mode with its picked tile, the threat
## of an inspected unit, the facing choice, an ability's area and the queued charges. Pure: the scene only draws it.
## A ui is {mode: "move"/"idle", pending: Vector2i or null, inspect: id or "", invalid}.
## Marks are {pos, kind} with kind in actor, move, range, threat, area, target, nogo, counter.


static func default_mode(b: Battle) -> String:
	return "move" if not b.over() and b.reach().size() and not b.state.turn.moved else "idle"


static func _with_mode(mode: String) -> Dictionary:
	return {"mode": mode, "pending": null, "inspect": "", "invalid": false}


static func fresh_ui(b: Battle) -> Dictionary:
	return _with_mode(default_mode(b))


static func select_mode(b: Battle, ui: Dictionary, mode: String) -> Dictionary:
	return _with_mode(mode) if mode == "idle" or b.reach().size() > 0 else ui


static func tap_tile(b: Battle, ui: Dictionary, pos: Vector2i) -> Dictionary:
	var other := Pathing.unit_at(b.state, pos)
	if ui.mode == "move" and b.reach().has(Grid.pos_key(pos)):
		var out := ui.duplicate()
		out.pending = pos
		out.inspect = ""
		out.invalid = false
		return out
	if not other.is_empty() and other.id != b.actor().id:
		var out := _with_mode(ui.mode)
		out.inspect = other.id
		return out
	var out := _with_mode(ui.mode)
	out.invalid = other.is_empty() and ui.mode != "idle"
	return out


## the cursor shows the same as a tap, without the warning
static func hover_tile(b: Battle, ui: Dictionary, pos: Vector2i) -> Dictionary:
	var out := tap_tile(b, ui, pos)
	out.invalid = false
	return out


static func cancel(ui: Dictionary) -> Dictionary:
	return _with_mode(ui.mode) if ui.pending != null or ui.inspect != "" else ui


## {events, ui}: the walk to the picked tile
static func confirm(b: Battle, ui: Dictionary) -> Dictionary:
	if ui.mode != "move" or ui.pending == null:
		return {"events": [], "ui": ui}
	var events := b.move(ui.pending)
	var alive := not Combat.find_unit(b.state, b.state.turn.actor).is_empty()
	return {"events": events, "ui": fresh_ui(b) if events.size() and alive else ui}


static var _threat_key := 0
static var _threat: Array = []


## what the unit can hit on its next turn: walk, then any ability (a wide warning, sight not checked)
static func threat(b: Battle, unit_id: String) -> Array:
	# ~100 ms on a half map, asked again on every cell of a foe the cursor crosses: once per state and unit
	var key := hash([b.state.hash(), unit_id, b.grid.width, b.grid.height])
	if key != _threat_key:
		_threat = _threat_of(b, unit_id)
		_threat_key = key
	return _threat


static func _threat_of(b: Battle, unit_id: String) -> Array:
	var u := Combat.find_unit(b.state, unit_id)
	var def: Dictionary = Content.units[u.def]
	if def.abilities.is_empty():
		return []
	var spots: Array = [u.pos]
	for s in Pathing.reachable(b.grid, b.state, unit_id).values():
		spots.append(s.pos)
	var size: int = def.get("size", 1)
	# the farthest any ability reaches with the map's biggest drop: a spot farther than that (in king steps, which
	# neither range measure undercuts) cannot hit, so it is skipped (a hover on a foe took 1.3 s on a half map)
	var lo := 1 << 30
	var hi := -(1 << 30)
	for t in b.grid.tiles:
		lo = mini(lo, Grid.stand_h(t))
		hi = maxi(hi, Grid.stand_h(t))
	var far := 0
	for a in def.abilities:
		var ab: Dictionary = Content.abilities[a]
		far = maxi(far, Reach.far_cells(b.grid, ab.range[1] + (hi - lo if ab.heightRange else 0)))
	var by_area := {} # the cells of one whole tile share its area: worked out once
	var out: Array = []
	for y in b.grid.height:
		for x in b.grid.width:
			var t := Vector2i(x, y)
			var area := Pathing.area_of(b.grid, b.state, Pathing.aim_tile(b.grid, b.state, t))
			if not by_area.has(area[0]):
				by_area[area[0]] = _threatens(b, def, spots, size, area, far)
			if by_area[area[0]]:
				out.append(t)
	return out


static func _threatens(b: Battle, def: Dictionary, spots: Array, size: int, area: Array[Vector2i], far: int) -> bool:
	var lo: Vector2i = area[0]
	var hi: Vector2i = area.back()
	for s in spots:
		var gap := maxi(maxi(0, maxi(lo.x - (s.x + size - 1), s.x - hi.x)), maxi(0, maxi(lo.y - (s.y + size - 1), s.y - hi.y)))
		if gap > far:
			continue
		var ends := Pathing.closest(Pathing.cells_of(s, size), area)
		for a in def.abilities:
			if Reach.in_ability_range(b.grid, Content.abilities[a], ends[0], ends[1]):
				return true
	return false


static func _mark(tiles: Dictionary, pos: Vector2i, kind: String) -> void:
	tiles[Grid.pos_key(pos)] = {"pos": pos, "kind": kind}


## another unit's range: where it walks, what it could strike after walking, its square and the actor's
static func range_marks(b: Battle, unit_id: String) -> Array:
	var tiles := {}
	var u := Combat.find_unit(b.state, unit_id)
	if not u.is_empty():
		for p in threat(b, unit_id):
			_mark(tiles, p, "threat")
		var size: int = Content.units[u.def].get("size", 1)
		for s in Pathing.reachable(b.grid, b.state, unit_id).values():
			for c in Pathing.cells_of(s.pos, size):
				_mark(tiles, c, "move")
		for c in Pathing.footprint(u):
			_mark(tiles, c, "actor")
	for c in Pathing.footprint(b.actor()):
		_mark(tiles, c, "actor")
	return tiles.values()


## {tiles, path, size, invalid}; `cursor`: a big unit's square under the cursor shows whether it fits
static func highlights(b: Battle, ui: Dictionary, cursor: Variant = null) -> Dictionary:
	var tiles := {}
	var path: Variant = null
	var size: int = Content.units[b.actor().def].get("size", 1) if ui.mode == "move" else 1
	var reach: Variant = b.reach() if ui.mode == "move" else null
	if ui.inspect != "" and not Combat.find_unit(b.state, ui.inspect).is_empty():
		for p in threat(b, ui.inspect):
			_mark(tiles, p, "threat")
	if reach != null:
		# after a strike, a stop that draws a counter of a unit struck this turn is framed red
		var safe := {}
		for s in reach.values():
			var red: bool = b.state.turn.has("engaged") and Counter.pending(b.grid, b.state, b.actor().id, s.pos).size() > 0
			for c in Pathing.cells_of(s.pos, size):
				if not red:
					safe[Grid.pos_key(c)] = true
					_mark(tiles, c, "move")
				elif not safe.has(Grid.pos_key(c)):
					_mark(tiles, c, "counter")
		if ui.pending != null:
			path = Pathing.path_to(reach, ui.pending)
	if not b.over():
		for c in Pathing.footprint(b.actor()):
			_mark(tiles, c, "actor")
	if reach != null:
		var at: Variant = (ui.pending if ui.pending != null else cursor) if size > 1 else ui.pending
		if at != null and at != b.actor().pos:
			var fits: bool = reach.has(Grid.pos_key(at))
			for c in Pathing.cells_of(at, size):
				if b.grid.in_bounds(c):
					_mark(tiles, c, "target" if fits else "nogo")
	return {"tiles": tiles.values(), "path": path, "size": size, "invalid": ui.invalid}


## the tiles beside each side of the actor's square, the faced side marked
static func facing_highlights(b: Battle) -> Array:
	var me := b.actor()
	var s: int = Content.units[me.def].get("size", 1)
	var out: Array = []
	for i in 4:
		var d: Vector2i = Grid.FACING[i]
		for k in s:
			var p := Vector2i(me.pos.x + s if d.x > 0 else (me.pos.x - 1 if d.x < 0 else me.pos.x + k), me.pos.y + s if d.y > 0 else (me.pos.y - 1 if d.y < 0 else me.pos.y + k))
			if b.grid.in_bounds(p):
				out.append({"pos": p, "kind": "target" if i == me.get("facing", -1) else "range"})
	for c in Pathing.footprint(me):
		out.append({"pos": c, "kind": "actor"})
	return out


## every cell of the whole tiles an area touches
static func area_cells(grid: Grid, area: Array, radius: int, square: bool = false) -> Array:
	var k := grid.sub
	var out: Array = []
	for y in range(0, grid.height, k):
		for x in range(0, grid.width, k):
			var tile := Pathing.cells_of(Vector2i(x, y), k)
			if Pathing.in_area(grid, area, radius, tile, square):
				out.append_array(tile)
	return out


## the aimed cell as the target and the ability's area around it
static func attack_marks(b: Battle, a: Dictionary, target: Vector2i) -> Array:
	var out: Array = [{"pos": target, "kind": "target"}]
	if a.radius > 0:
		for p in area_cells(b.grid, Pathing.area_of(b.grid, b.state, Pathing.aim_tile(b.grid, b.state, target)), a.radius, Reach.is_melee(a)):
			if p != target:
				out.append({"pos": p, "kind": "area"})
	return out


## the tiles the queued charges will hit: pos key → the ability landing there
static func charge_danger(grid: Grid, state: Dictionary) -> Dictionary:
	var out := {}
	for c in state.charges:
		var aim := TurnQueue.charge_aim(state, c)
		var center := aim
		if not Combat.find_unit(state, c.unit).is_empty():
			var shot := Combat.preview(grid, state, c.unit, c.ability, aim, true)
			if shot.ok:
				center = shot.center
		var area := Pathing.area_of(grid, state, Pathing.aim_tile(grid, state, center))
		for p in area_cells(grid, area, Content.abilities[c.ability].radius, Reach.is_melee(Content.abilities[c.ability])):
			out[Grid.pos_key(p)] = c.ability
	return out

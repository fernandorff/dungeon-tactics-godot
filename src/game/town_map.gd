class_name TownMap
## The walkable town's rules (port of town-map.ts): the halved map, who stands where (the party, the townsfolk), the
## places and their doors, the walker's fluid movement that slides along walls and people, and what the action button
## acts on. Pure; the scene and the input live in town_screen.gd.

const ME := "me"
const SUB := 2
const BODY := 0.8
const TALK := 3.0
const AHEAD := 0.5
const DOOR := 1.25
const PLACE_ACT := {"guild": "party", "shop": "shop", "tavern": "tavern", "gate": "quest"}


static func town() -> Dictionary:
	return Content.data.town


static func cell(p: Variant) -> Vector2i:
	return Vector2i(p.x * SUB, p.y * SUB)


static func member_unit(id: String) -> String:
	return "p-" + id


## the town in half tiles, registered whole too
static func scenario() -> Dictionary:
	var sc := Content.scenario_from(town().map)
	Content.scenarios[sc.id] = sc
	return Half.halve(sc)


static func state(sc: Dictionary) -> Dictionary:
	var units: Array = []
	for s in sc.spawns:
		units.append({"id": s.id, "def": s.def, "team": s.team, "pos": Vector2i(s.x, s.y), "hp": 1, "ct": 0})
	return {"scenario": sc.id, "units": units, "rng": 0, "turn": {"actor": ME, "moved": false, "main": null, "bonus": null}, "charges": [], "outcome": "ongoing", "turnsPlayed": 0}


## the first who goes to battle walks, the rest wait at the Guild; returns the ids that left
static func cast_party(st: Dictionary, g: Dictionary) -> Array:
	var lead := Party.member(g, g.deployed[0])
	if lead.is_empty():
		lead = g.members[0]
	var want := {ME: Half.half_def(lead.cls)}
	for m in g.members:
		if m.id != lead.id:
			want[member_unit(m.id)] = Half.half_def(m.cls)
	var at := cell(town().start)
	for u in st.units:
		if u.id == ME:
			at = u.pos
	var dropped: Array = []
	for u in st.units:
		if (u.id == ME or u.id.begins_with("p-")) and want.get(u.id) != u.def:
			dropped.append(u.id)
	st.units = st.units.filter(func(u: Dictionary) -> bool: return not dropped.has(u.id))
	for id in want:
		if st.units.any(func(u: Dictionary) -> bool: return u.id == id):
			continue
		var pos := at
		if id != ME:
			pos = cell(town().guild_spots[0])
			for s in town().guild_spots:
				var c := cell(s)
				if Pathing.cells_of(c, SUB).all(func(q: Vector2i) -> bool: return Pathing.unit_at(st, q).is_empty()):
					pos = c
					break
		st.units.append({"id": id, "def": want[id], "team": "hero", "pos": pos, "hp": Content.units[want[id]].hp, "ct": 0})
	return dropped


static func centre_of(p: Vector2i) -> Vector2:
	return Vector2(p.x + SUB / 2.0, p.y + SUB / 2.0)


static func cell_under(c: Vector2) -> Vector2i:
	return Vector2i(roundi(c.x - SUB / 2.0), roundi(c.y - SUB / 2.0))


## a screen vector on the ground under the camera's yaw
static func ground_dir(v: Vector2, yaw: float) -> Vector2:
	return Vector2(v.x * cos(yaw) + v.y * sin(yaw), v.y * cos(yaw) - v.x * sin(yaw))


## the walker's centre after moving by `d`: pushed out of every cell that is not floor and of everyone's square, so it
## slides along walls; a dead-on corner goes round to the side it leans
static func slide(grid: Grid, st: Dictionary, at: Vector2, d: Vector2) -> Vector2:
	var solid := func(c: Vector2i) -> bool:
		if not grid.in_bounds(c) or grid.tile(c).terrain != "floor":
			return true
		var u := Pathing.unit_at(st, c)
		return not u.is_empty() and u.id != ME
	var hops := maxi(1, ceili(d.length() / (BODY / 2.0)))
	var x := at.x
	var y := at.y
	for i in hops:
		x += d.x / hops
		y += d.y / hops
		for tries in 3:
			var x0 := floori(x - BODY)
			var y0 := floori(y - BODY)
			var hit := Vector3(0, 0, BODY) # dx, dy, len
			for cy in range(y0, y0 + 3):
				for cx in range(x0, x0 + 3):
					if not solid.call(Vector2i(cx, cy)):
						continue
					var dx := x - minf(maxf(x, cx), cx + 1)
					var dy := y - minf(maxf(y, cy), cy + 1)
					var l := sqrt(dx * dx + dy * dy)
					if l > 0.0 and l < hit.z:
						hit = Vector3(dx, dy, l)
			if hit.z == BODY:
				break
			var nx := hit.x / hit.z
			var ny := hit.y / hit.z
			x += nx * (BODY - hit.z)
			y += ny * (BODY - hit.z)
			var along := (d.y * nx - d.x * ny) / hops
			var hop := d.length() / hops
			if tries or hit.x == 0.0 or hit.y == 0.0 or d.x * nx + d.y * ny >= 0.0 or absf(along) >= 0.25 * hop:
				continue
			var slip := (1.0 if along > 1e-9 * hop else -1.0) * (hop - absf(along))
			x -= ny * slip
			y += nx * slip
	return Vector2(x, y)


## what the action button acts on: {act, unit} | {act, place} | {}
static func free_target(st: Dictionary, at: Vector2, facing: Vector2) -> Dictionary:
	var beside: Array = []
	for u in st.units:
		if u.id != ME and (centre_of(u.pos) - at).length() <= TALK:
			beside.append(u)
	beside = Util.stable_sort(beside, func(a: Dictionary, b: Dictionary) -> bool: return (centre_of(a.pos) - at).length() < (centre_of(b.pos) - at).length())
	for u in beside:
		var off := centre_of(u.pos) - at
		if off.dot(facing) >= AHEAD * off.length() * facing.length():
			return {"act": "talk", "unit": u}
	for p in town().places:
		var door := centre_of(cell(p.door))
		if maxf(absf(door.x - at.x), absf(door.y - at.y)) <= DOOR:
			return {"act": "soon" if p.has("soon") else PLACE_ACT.get(p.id, "enter"), "place": p}
	return {"act": "talk", "unit": beside[0]} if beside.size() else {}

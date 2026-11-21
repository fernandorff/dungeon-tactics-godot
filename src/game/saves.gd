class_name Saves
## Save slots (port of saves.ts): the game reads and writes its progress keys as before; a slot is a stored copy of them
## in the dt:saves manifest. Loading a slot writes the live game back into its own slot first, so nothing is lost.
## A manifest is {active: id or null, slots: [{id, data: {key: text}}]}.

const SAVES_KEY := "dt:saves"
const CRAWL_KEY := "dt:crawl"
const ROOM_KEY := "dt:battle:expedition"
const PLAYED_KEY := "dt:played"
const PROGRESS_KEYS := ["dt:party", "dt:chest", "dt:equip", CRAWL_KEY, ROOM_KEY]
## played goes last: restoring the progress keys stamps it, the slot's own time must win
const SLOT_KEYS := PROGRESS_KEYS + [PLAYED_KEY]


static func _json(v: String) -> Variant:
	return null if v == "" else Util.ints(JSON.parse_string(v))


## trust boundary: a slot needs a whole positive id of its own; its copy keeps only the slot keys with text values
static func parse_manifest(raw: Variant) -> Dictionary:
	var r: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var slots: Array = []
	for x in r.get("slots", []) if typeof(r.get("slots")) == TYPE_ARRAY else []:
		var e: Dictionary = x if typeof(x) == TYPE_DICTIONARY else {}
		var id: Variant = e.get("id")
		if typeof(id) != TYPE_INT or id < 1 or slots.any(func(s: Dictionary) -> bool: return s.id == id):
			continue
		var d: Dictionary = e.get("data") if typeof(e.get("data")) == TYPE_DICTIONARY else {}
		var kept := {}
		for k in SLOT_KEYS:
			if typeof(d.get(k)) == TYPE_STRING and d[k] != "":
				kept[k] = d[k]
		slots.append({"id": id, "data": kept})
	var active: Variant = r.get("active")
	var ok := slots.any(func(s: Dictionary) -> bool: return s.id == active)
	return {"active": active if ok else null, "slots": slots}


## the live game's keys, without the cleared ones
static func snapshot() -> Dictionary:
	var out := {}
	for k in SLOT_KEYS:
		var v := Store.get_key(k)
		if v != "":
			out[k] = v
	return out


static func _next_id(m: Dictionary) -> int:
	var id := 1
	while m.slots.any(func(x: Dictionary) -> bool: return x.id == id):
		id += 1
	return id


## the manifest as it stands: the active slot holds the live game; live progress with no slot becomes a new active slot
static func read_saves() -> Dictionary:
	var m := parse_manifest(_json(Store.get_key(SAVES_KEY)))
	var live := snapshot()
	if m.active != null:
		for x in m.slots:
			if x.id == m.active:
				x.data = live
		return m
	if not PROGRESS_KEYS.any(func(k: String) -> bool: return live.has(k)):
		return m
	var id := _next_id(m)
	m.slots.append({"id": id, "data": live})
	m.active = id
	return m


static func _write(m: Dictionary) -> void:
	Store.put(SAVES_KEY, JSON.stringify(m))


static func _switch_to(m: Dictionary, id: Variant, data: Dictionary) -> bool:
	for k in SLOT_KEYS:
		Store.put(k, data.get(k, ""))
	m.active = id
	_write(m)
	return true


## the live game stays in its slot and a clean game starts in a new one, with 0 gold and the story members' weapons
static func new_game(now: int) -> bool:
	var m := read_saves()
	var id := _next_id(m)
	m.slots.append({"id": id, "data": {}})
	return _switch_to(m, id, {"dt:equip": JSON.stringify(Chest.starting_equip()), PLAYED_KEY: str(now)})


static func load_slot(id: int) -> bool:
	var m := read_saves()
	for x in m.slots:
		if x.id == id:
			return _switch_to(m, id, x.data)
	return false


## deleting the game in play clears the live keys too
static func delete_slot(id: int) -> bool:
	var m := read_saves()
	var was_active: bool = m.active == id
	m.slots = m.slots.filter(func(x: Dictionary) -> bool: return x.id != id)
	if was_active:
		return _switch_to(m, null, {})
	_write(m)
	return true


## a row of the Continue list, read from the slot's copy by the game's own parsers
static func summary(slot: Dictionary) -> Dictionary:
	var data: Dictionary = slot.data
	var g := Party.parse_group(_json(data.get("dt:party", "")))
	var names: Array = []
	for id in g.deployed:
		names.append(Party.member(g, id).name)
	var exp: Variant = Expedition.parse(_json(data.get(CRAWL_KEY, "")))
	var floor: Variant = null
	var open: Array = []
	if exp != null:
		var map := Expedition.map_of(exp.seed)
		open = Expedition.open_nodes(map, exp.path)
		if open.size():
			floor = map[open[0]].floor
	var played := int(data.get(PLAYED_KEY, "0")) if str(data.get(PLAYED_KEY, "")).is_valid_int() else 0
	return {
		"id": slot.id,
		"leader": Party.member(g, g.deployed[0]).cls,
		"names": names,
		"gold": Chest.parse_chest(_json(data.get("dt:chest", ""))).gold,
		"floor": floor,
		"room": data.get(ROOM_KEY, "") != "" and open.size() > 0,
		"played": played if played > 0 and played <= 8640000000000000 else null,
	}


## the latest played first; a slot never played after them, newest slot first
static func by_played(a: Dictionary, b: Dictionary) -> bool:
	var pa: int = a.played if a.played != null else 0
	var pb: int = b.played if b.played != null else 0
	return pa > pb if pa != pb else a.id > b.id

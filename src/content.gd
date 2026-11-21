class_name Content
## The game's data, read once from data/content.json (exported from the web game by tools/export.ts): classes and enemies,
## abilities, items, maps, the crawl tables and the town. Also the registries the rules read and fill at run time: unit
## sheets (a half-tile token `<id>½` is added per battle, half.gd) and scenarios (crawl rooms, halved maps).

const HALF := "½"
const OBJECTIVE_DEF := "beacon"
const ELEMENTS := ["fire", "ice", "lightning", "shadow", "wind", "light"]
const RESOURCES := ["mana", "stamina"]
const RESIST_RANGE := [-100, 60]
const DODGE_MAX := 50

static var data: Dictionary = {}
static var units: Dictionary = {}
static var abilities: Dictionary = {}
static var items: Dictionary = {}
static var consumables: Array = []
static var consumable: Dictionary = {}
static var buffs: Dictionary = {}
static var scenarios: Dictionary = {}
static var maps: Array = []


static func ensure() -> void:
	if not data.is_empty():
		return
	data = Util.load_json("res://data/content.json")
	for u in data.units:
		units[u.id] = u
	for a in data.abilities:
		abilities[a.id] = a
	for i in data.items:
		items[i.id] = i
	consumables = data.consumables
	for c in consumables:
		consumable[c.id] = c
		if c.has("buff"):
			buffs[c.id] = c.buff
	# abilities leave timed effects too (Nov 21: stun, sand, focus), after the items as in effects.ts
	for a in data.abilities:
		if a.has("buff"):
			buffs[a.id] = a.buff
	for m in data.maps:
		var sc := scenario_from(m)
		scenarios[sc.id] = sc
		maps.append(sc)


## a scenario as the web game writes it ({id, name, en, grid, spawns}) with its grid as a Grid
static func scenario_from(m: Dictionary) -> Dictionary:
	var sc := m.duplicate()
	sc.grid = Grid.from_dict(m.grid)
	return sc


static func unit(def: String) -> Dictionary:
	return units[def]


static func ability(id: String) -> Dictionary:
	return abilities[id]


static func base_def(def: String) -> String:
	return def.substr(0, def.length() - HALF.length()) if def.ends_with(HALF) else def


static func is_objective(def: String) -> bool:
	return base_def(def) == OBJECTIVE_DEF


static func resist_of(d: Dictionary, k: String, shift: int = 0) -> int:
	return clampi(d.get("resist", {}).get(k, 0) + shift, RESIST_RANGE[0], RESIST_RANGE[1])


static func dodge_of(d: Dictionary) -> int:
	return clampi(d.get("dodge", 0), 0, DODGE_MAX)

class_name Roster
## A cast turned into a scenario (port of dev-roster.ts): each unit becomes its own sheet (dev-h0, e1…) with its class's
## numbers and its equipment on top, on the map's starting tiles in order. The expedition rooms use this path.
## A unit is {base, name, en?, hp, speed, move, jump?, items?, abilities}.

static var _base := {}


static func unit_from(base: String, name: String = "") -> Dictionary:
	var d: Dictionary = Content.units[base]
	return {"base": base, "name": name if name != "" else d.name, "hp": d.hp, "speed": d.speed, "move": d.move, "jump": d.get("jump", Pathing.MAX_JUMP), "abilities": d.abilities.duplicate()}


## a map's starting tiles per side (the objective aside)
static func slots_of(map: String) -> Dictionary:
	var out := {"hero": [], "enemy": [], "objective": []}
	var sc: Dictionary = Content.scenarios.get(map, {})
	for s in sc.get("spawns", []):
		if Content.is_objective(s.def):
			out.objective.append(s)
		else:
			out[s.team].append(s)
	return out


## the class a sheet built here came from (dev-h0 → warrior); the half-tile token too
static func class_of(def: String) -> String:
	return _base.get(Content.base_def(def), "")


## no objective: the last side standing wins (the default rule would lose at once without the Beacon)
static func _last_standing(state: Dictionary) -> String:
	var heroes := false
	var enemies := false
	for u in state.units:
		if u.team == "enemy":
			enemies = true
		if u.team == "hero":
			heroes = true
	return "victory" if not enemies else ("defeat" if not heroes else "ongoing")


## registers the sheets and the scenario in Content, like the web game's lists
static func build_scenario(setup: Dictionary, scenario_id: String = "dev", title: Array = ["Desenvolvedor", "Developer"]) -> Dictionary:
	var base: Dictionary = Content.scenarios[setup.map]
	var s := slots_of(setup.map)
	var spawns: Array = s.objective.duplicate()
	for side in [[setup.heroes, s.hero, "hero", "h"], [setup.enemies, s.enemy, "enemy", "e"]]:
		var units: Array = side[0]
		var slots: Array = side[1]
		for i in mini(units.size(), slots.size()):
			var u: Dictionary = units[i]
			var id := "%s-%s%d" % [scenario_id, side[3], i]
			var cls: Dictionary = Content.units[u.base]
			_base[id] = u.base
			var en: String = u.get("en", cls.en if u.name == cls.name else u.name)
			var sheet := {"id": id, "name": u.name, "en": en, "hp": u.hp, "speed": u.speed, "move": u.move, "abilities": u.abilities.duplicate(), "jump": u.get("jump", cls.get("jump", Pathing.MAX_JUMP))}
			for k in ["resist", "dodge", "physPower", "magPower", "size", "tint", "undead"]:
				if cls.get(k):
					sheet[k] = cls[k]
			for k in ["vars", "regen"]:
				if cls.has(k):
					sheet[k] = cls[k].duplicate()
			Content.units[id] = Equipment.with_gear(sheet, u.get("items"))
			spawns.append({"id": "%s%d" % [side[3], i], "def": id, "team": side[2], "x": slots[i].x, "y": slots[i].y})
	var sc := {"id": scenario_id, "name": title[0], "en": title[1], "grid": base.grid, "spawns": spawns}
	if s.objective.is_empty():
		sc.rules = {"outcome": _last_standing}
	Content.scenarios[scenario_id] = sc
	return sc

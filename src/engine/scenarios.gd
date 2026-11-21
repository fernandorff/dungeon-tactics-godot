class_name Scenarios
## Scenario = map + who spawns where (port of scenarios.ts). The state keeps only the scenario id.


static func initial_state(scenario: Dictionary, seed: int) -> Dictionary:
	var units: Array = []
	for s in scenario.spawns:
		var d: Dictionary = Content.units[s.def]
		var u := {"id": s.id, "def": s.def, "team": s.team, "pos": Vector2i(s.x, s.y), "hp": d.hp, "ct": 0}
		if d.speed > 0:
			var foes: Array = []
			for o in scenario.spawns:
				if o.team != s.team:
					foes.append(Vector2i(o.x, o.y))
			u.facing = Grid.face_nearest(Vector2i(s.x, s.y), foes)
		if d.has("vars"):
			u.vars = d.vars.duplicate()
		units.append(u)
	return {
		"scenario": scenario.id,
		"units": units,
		"rng": Util.i32(seed),
		"turn": {"actor": "", "moved": false, "main": null, "bonus": null},
		"charges": [],
		"outcome": "ongoing",
		"turnsPlayed": 0,
	}

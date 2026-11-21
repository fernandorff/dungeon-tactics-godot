class_name Outcome
## Who won (port of outcome.ts, split from combat.gd): the battle's own rule, else no enemies left is a victory and the fall
## of the Beacon or of every hero a defeat.


## Victory: no enemies. Defeat: the target to protect fell or all heroes died
static func check(state: Dictionary) -> String:
	var sc: Dictionary = Content.scenarios.get(state.scenario, {})
	var rules: Dictionary = sc.get("rules", {})
	if rules.has("outcome"):
		return rules.outcome.call(state)
	var heroes := 0
	var objective := false
	var enemies := false
	for u in state.units:
		if u.team == "hero" and not Content.is_objective(u.def):
			heroes += 1
		if Content.is_objective(u.def):
			objective = true
		if u.team == "enemy":
			enemies = true
	var had_objective := true
	if not sc.is_empty():
		had_objective = false
		for s in sc.spawns:
			if Content.is_objective(s.def):
				had_objective = true
	if (had_objective and not objective) or heroes == 0:
		return "defeat"
	if not enemies:
		return "victory"
	return "ongoing"

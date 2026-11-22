class_name ResultTests
## The battle's tally (the web's tests/tally.test.ts, case by case) and the 3D result's pure parts against the web
## game's own numbers (tests/golden/result.json, written by tools/export-result.mjs from result3d/result-layout.ts).

const TEAM := {"h1": "hero", "h2": "hero", "e1": "enemy", "e2": "enemy"}
const AT := Vector2i(0, 0)


func test_tally_adds_damage_and_knockdowns_by_the_attacker() -> String:
	var t := Tally.new()
	t.add_events([
		{"k": "attack", "unit": "h1", "ability": "strike", "target": AT},
		{"k": "hit", "unit": "e1", "dmg": 8, "chance": 90},
		{"k": "push", "unit": "e1", "to": AT},
		{"k": "bump", "unit": "e1", "dmg": 3},
		{"k": "die", "unit": "e1"},
	], TEAM)
	return "" if t.scores.get("h1") == {"dmg": 11, "kills": 1} else "h1 %s" % t.scores.get("h1")


func test_tally_skips_its_own_side() -> String:
	var t := Tally.new()
	t.add_events([
		{"k": "attack", "unit": "h1", "ability": "blast", "target": AT},
		{"k": "hit", "unit": "h2", "dmg": 5, "chance": 90},
		{"k": "heal", "unit": "h2", "amount": 4},
		{"k": "spike", "unit": "h1", "dmg": 6},
	], TEAM)
	return "" if not t.scores.has("h1") else "h1 %s" % t.scores.h1


func test_tally_spike_is_the_pushers_only() -> String:
	var t := Tally.new()
	t.add_events([{"k": "attack", "unit": "h1", "ability": "strike", "target": AT}, {"k": "hit", "unit": "e1", "dmg": 4, "chance": 90}], TEAM)
	t.add_events([{"k": "spike", "unit": "e2", "dmg": 6}, {"k": "die", "unit": "e2"}], TEAM)
	if t.scores.h1 != {"dmg": 4, "kills": 0}:
		return "after the stop %s" % t.scores.h1
	t.add_events([{"k": "attack", "unit": "h1", "ability": "shield_bash", "target": AT}, {"k": "push", "unit": "e1", "to": AT}, {"k": "spike", "unit": "e1", "dmg": 6}], TEAM)
	return "" if t.scores.h1 == {"dmg": 10, "kills": 0} else "after the push %s" % t.scores.h1


func test_tally_mvp_most_downed_then_damage() -> String:
	var t := Tally.new()
	t.add_events([
		{"k": "attack", "unit": "h1", "ability": "strike", "target": AT},
		{"k": "hit", "unit": "e1", "dmg": 20, "chance": 90},
		{"k": "attack", "unit": "h2", "ability": "shot", "target": AT},
		{"k": "hit", "unit": "e2", "dmg": 5, "chance": 90},
		{"k": "die", "unit": "e2"},
		{"k": "attack", "unit": "e1", "ability": "strike", "target": AT},
		{"k": "hit", "unit": "h1", "dmg": 9, "chance": 90},
	], TEAM)
	if t.mvp(TEAM, "hero") != ["h2", {"dmg": 5, "kills": 1}]:
		return "hero %s" % [t.mvp(TEAM, "hero")]
	if t.mvp(TEAM, "enemy")[0] != "e1":
		return "enemy %s" % [t.mvp(TEAM, "enemy")]
	return "" if Tally.new().mvp(TEAM, "hero").is_empty() else "empty tally has an mvp"


func test_tally_end_heroes_skip_the_beacon() -> String:
	var t := Tally.new()
	var roster := {"h1": {"team": "hero", "def": "warrior"}, "h2": {"team": "hero", "def": "archer"}, "b": {"team": "hero", "def": "beacon"}, "e1": {"team": "enemy", "def": "soldier"}}
	t.add_events([{"k": "attack", "unit": "h2", "ability": "shot", "target": AT}, {"k": "hit", "unit": "e1", "dmg": 12, "chance": 90}], {"h1": "hero", "h2": "hero", "b": "hero", "e1": "enemy"})
	var want := [
		{"id": "h1", "def": "warrior", "hp": 0, "max": Content.units.warrior.hp, "dmg": 0, "kills": 0, "mvp": false},
		{"id": "h2", "def": "archer", "hp": 7, "max": Content.units.archer.hp, "dmg": 12, "kills": 0, "mvp": true},
	]
	var got := t.end_heroes(roster, [{"id": "h2", "hp": 7}])
	return "" if str(got) == str(want) else "%s" % [got]


func test_result_layout_matches_web() -> String:
	var golden: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/result.json"))
	for g: Dictionary in golden:
		var o: Dictionary = g.out
		var mine := ResultLayout.layout(StageLayout.stage(g.w, g.h), g.w, g.heroes, g.spoils, g.actions)
		var at := "%dx%d %d/%d/%d" % [g.w, g.h, g.heroes, g.spoils, g.actions]
		for k in ["band", "rule", "left", "right"]:
			if not MenuTests._box(mine[k], o[k]):
				return "%s %s %s, web %s" % [at, k, mine[k], o[k]]
		for k in ["heroes", "faces", "spoils", "buttons"]:
			if mine[k].size() != o[k].size():
				return "%s %s count" % [at, k]
			for i in o[k].size():
				if not MenuTests._box(mine[k][i], o[k][i]):
					return "%s %s %d %s, web %s" % [at, k, i, mine[k][i], o[k][i]]
		var pairs := [[mine.title.x, o.title.x], [mine.title.y, o.title.y], [mine.note.x, o.note.x], [mine.note.y, o.note.y],
			[mine.note.w, o.note.w], [mine.who, o.who], [mine.did.y, o.did.y], [mine.did.dmg, o.did.dmg], [mine.did.kills, o.did.kills],
			[mine.mvp.x, o.mvp.x], [mine.mvp.name, o.mvp.name], [mine.mvp.line, o.mvp.line]]
		for i in pairs.size():
			if not MenuTests._near(pairs[i][0], pairs[i][1]):
				return "%s value %d: %s, web %s" % [at, i, pairs[i][0], pairs[i][1]]
		if not MenuTests._box(mine.mvp.rule, o.mvp.rule):
			return "%s mvp rule" % at
	return ""

class_name UnitTests
## Edge cases of the port's own helpers, and of the Nov 21 rules the AI's golden battles may not reach: melee on the
## diagonal, the abilities' timed effects (stun, sand, focus), the Shove and the corpses of small bodies.


func test_rng_matches_mulberry32() -> String:
	# first values of the web game's nextRng from seed 7 (node: nextRng(7))
	var r := Rng.next(7)
	if r[1] != Util.i32(7 + 0x6D2B79F5):
		return "next state %d" % r[1]
	return ""


func test_stable_sort_keeps_ties() -> String:
	var arr := [{"k": 1, "i": 0}, {"k": 0, "i": 1}, {"k": 1, "i": 2}, {"k": 0, "i": 3}]
	var out := Util.stable_sort(arr, func(a: Dictionary, b: Dictionary) -> bool: return a.k < b.k)
	var order := out.map(func(x: Dictionary) -> int: return x.i)
	return "" if order == [1, 3, 0, 2] else "order %s" % [order]


func test_floor_div_rounds_down() -> String:
	return "" if Util.floor_div(-3, 2) == -2 and Util.ceil_div(3, 2) == 2 and Util.ceil_div(-3, 2) == -1 else "floor/ceil"


## a flat 6x6 map without a scenario, with the units given as [id, def, team, pos]; the first one acts
func _flat(spec: Array) -> Array:
	var tiles: Array = []
	for i in 36:
		tiles.append({"terrain": "floor", "h": 0})
	var grid := Grid.from_dict({"width": 6, "height": 6, "tiles": tiles})
	var units: Array = []
	for s in spec:
		var d: Dictionary = Content.units[s[1]]
		var u := {"id": s[0], "def": s[1], "team": s[2], "pos": s[3], "hp": d.hp, "ct": 0}
		if d.has("vars"):
			u.vars = d.vars.duplicate()
		units.append(u)
	var state := {"scenario": "", "units": units, "rng": 7, "turn": {"actor": spec[0][0], "moved": false, "main": null, "bonus": null}, "charges": [], "outcome": "ongoing", "turnsPlayed": 0}
	return [grid, state]


## resolves until the blow lands (a seed per try), so the test does not hang on one roll
func _landed(grid: Grid, state: Dictionary, actor: String, ability: String, target: Vector2i) -> Array:
	for seed in range(1, 40):
		var s: Dictionary = state.duplicate(true)
		s.rng = seed
		var events := Combat.resolve(grid, s, actor, ability, target)
		if not events.any(func(e: Dictionary) -> bool: return e.k == "miss"):
			return [s, events]
	return [state, []]


func test_melee_reaches_the_diagonal() -> String:
	var gs := _flat([["w", "warrior", "hero", Vector2i(2, 2)], ["s", "soldier", "enemy", Vector2i(3, 3)]])
	if not Combat.preview(gs[0], gs[1], "w", "strike", Vector2i(3, 3)).ok:
		return "strike does not reach the diagonal"
	if Reach.reach_dist(Content.abilities["shot"], Vector2i(2, 2), Vector2i(3, 3)) != 2:
		return "a shot still measures the cross"
	return ""


func test_shield_bash_stuns() -> String:
	var gs := _flat([["w", "warrior", "hero", Vector2i(2, 2)], ["s", "soldier", "enemy", Vector2i(2, 3)]])
	var r := _landed(gs[0], gs[1], "w", "shield_bash", Vector2i(2, 3))
	var state: Dictionary = r[0]
	if not r[1].any(func(e: Dictionary) -> bool: return e.k == "effect" and e.item == "shield_bash" and e.turns == 1):
		return "no effect event: %s" % [r[1]]
	if Combat.preview(gs[0], state, "s", "strike", Vector2i(2, 2)).get("reason", "") != "stunned":
		return "a stunned unit still acts"
	var soldier := Combat.find_unit(state, "s")
	var full: int = Content.units["soldier"].move
	return "" if Effects.move_of(state, soldier) == Util.floor_div(full * 50, 100) else "stun does not halve movement"


func test_shove_and_sand_deal_no_damage() -> String:
	var gs := _flat([["w", "warrior", "hero", Vector2i(2, 2)], ["s", "soldier", "enemy", Vector2i(2, 3)]])
	var r := _landed(gs[0], gs[1], "w", "shove", Vector2i(2, 3))
	if r[1].any(func(e: Dictionary) -> bool: return e.k == "hit"):
		return "the Shove shows a hit"
	if Combat.find_unit(r[0], "s").pos == Vector2i(2, 3):
		return "the Shove did not push"
	gs = _flat([["a", "archer", "hero", Vector2i(2, 2)], ["s", "soldier", "enemy", Vector2i(2, 3)]])
	r = _landed(gs[0], gs[1], "a", "sand", Vector2i(2, 3))
	if r[1].any(func(e: Dictionary) -> bool: return e.k == "hit") or Combat.find_unit(r[0], "s").hp != Content.units["soldier"].hp:
		return "sand hurts"
	return "" if Effects.hit_share(r[0], "s") == 75 else "sand leaves %d%% aim" % Effects.hit_share(r[0], "s")


func test_focus_lasts_until_the_next_attack() -> String:
	var gs := _flat([["a", "archer", "hero", Vector2i(2, 2)], ["s", "soldier", "enemy", Vector2i(2, 3)]])
	var state: Dictionary = gs[1]
	Combat.resolve(gs[0], state, "a", "focus", Vector2i(2, 2))
	if Effects.damage_share(state, "a") != 125 or Effects.hit_share(state, "a") != 125:
		return "focus gives %d%% damage" % Effects.damage_share(state, "a")
	Combat.resolve(gs[0], state, "a", "dagger", Vector2i(2, 3))
	return "" if Effects.damage_share(state, "a") == 100 else "the attack did not spend focus"


func test_small_bodies_leave_no_corpse() -> String:
	var gs := _flat([["w", "warrior", "hero", Vector2i(2, 2)], ["r", "rat", "enemy", Vector2i(2, 3)], ["s", "soldier", "enemy", Vector2i(4, 4)]])
	var state: Dictionary = gs[1]
	Combat._hurt(state, Combat.find_unit(state, "r"), 999, [])
	if state.get("corpses", []).size():
		return "a rat left a corpse"
	Combat._hurt(state, Combat.find_unit(state, "s"), 999, [])
	return "" if state.get("corpses", []).size() else "a soldier left no corpse"


func test_sound_bars_parse() -> String:
	if Util.diff(Sound.parse(null, ""), Sound.DEFAULT) != "":
		return "no save: %s" % [Sound.parse(null, "")]
	# a save from before the split: its single bar fills interface, world and dialogue
	if Util.diff(Sound.parse(null, "0.3"), {"music": 25, "ui": 30, "world": 30, "voice": 30}) != "":
		return "old bar: %s" % [Sound.parse(null, "0.3")]
	var bad := Sound.parse({"music": 7, "ui": 150, "world": "x", "voice": 40}, "")
	return "" if Util.diff(bad, {"music": 25, "ui": 50, "world": 50, "voice": 40}) == "" else "bad values: %s" % [bad]

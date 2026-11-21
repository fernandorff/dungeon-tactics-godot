class_name Survival
## "Until Dawn" (port of survival.ts): the 4 heroes hold out in Ash Wood against tougher enemies already on their side of
## the river until the queue reaches SURVIVE_TURNS turns; downing everyone also wins. The record is kept (dt:dawn).

const ID := "survival"
const SURVIVE_TURNS := 40
const TOUGH := 1.5
const BEST_KEY := "dt:dawn"
const AMBUSH := [Vector2i(1, 7), Vector2i(6, 6), Vector2i(9, 7), Vector2i(11, 6)]


static func parse_best(raw: String) -> int:
	return int(raw) if raw.is_valid_int() and int(raw) >= 0 and int(raw) <= SURVIVE_TURNS else 0


static func best() -> int:
	return parse_best(Store.get_key(BEST_KEY))


static func turns_left(state: Dictionary) -> int:
	return maxi(0, SURVIVE_TURNS - state.turnsPlayed)


static func survived(state: Dictionary) -> int:
	return mini(state.turnsPlayed, SURVIVE_TURNS)


static func _outcome(st: Dictionary) -> String:
	var heroes: bool = st.units.any(func(u: Dictionary) -> bool: return u.team == "hero")
	var enemies: bool = st.units.any(func(u: Dictionary) -> bool: return u.team == "enemy")
	return "defeat" if not heroes else ("victory" if not enemies or st.turnsPlayed >= SURVIVE_TURNS else "ongoing")


static func scenario() -> Dictionary:
	var heroes: Array = []
	for b in ["warrior", "archer", "mage", "rogue"]:
		heroes.append(Roster.unit_from(b))
	var enemies: Array = []
	for b in ["brute", "skeleton_archer", "dark_mage", "brute"]:
		var u := Roster.unit_from(b)
		u.hp = roundi(u.hp * TOUGH)
		enemies.append(u)
	var s := Roster.build_scenario({"map": "ash_wood", "heroes": heroes, "enemies": enemies}, ID, ["Até o amanhecer", "Until Dawn"])
	var k := 0
	for sp in s.spawns:
		if sp.team == "enemy":
			sp.x = AMBUSH[k].x
			sp.y = AMBUSH[k].y
			k += 1
	s.rules = {"outcome": _outcome}
	return s

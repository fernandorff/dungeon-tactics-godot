class_name Tally
## The battle's tally for the highlight at the end (port of the web game's tally.ts): damage dealt and enemies downed per
## unit. Reads the events in the order they play: everything after an "attack" belongs to whoever attacked (hit, bump,
## fall and a pushed spike) until the next "attack". Only damage to the other side counts. Lives only in memory: a
## battle reopened from its save starts it again, as the web's.

var by := ""
var scores := {} # unit id -> {dmg, kills}


func add_events(events: Array, team: Dictionary) -> void:
	# a spike with no push right before (stopped on it at the end of a turn) is nobody's merit, nor the death after it
	var own_fault := {}
	for i in events.size():
		var e: Dictionary = events[i]
		var prev: Dictionary = events[i - 1] if i > 0 else {}
		if e.k == "spike" and not (prev.get("k") == "push" and prev.get("unit") == e.unit):
			own_fault[e.unit] = true
	for e: Dictionary in events:
		if e.k == "attack":
			by = e.unit
		if (e.k == "spike" or e.k == "die") and own_fault.has(e.unit):
			continue
		if by == "" or not team.has(e.get("unit", "")) or team[e.unit] == team.get(by):
			continue
		if not scores.has(by):
			scores[by] = {"dmg": 0, "kills": 0}
		if e.has("dmg"):
			scores[by].dmg += int(e.dmg)
		if e.k == "die":
			scores[by].kills += 1


## who on the side did the most: most downed, tie broken by damage; [] if nobody on it scored
func mvp(team: Dictionary, side: String) -> Array:
	var list: Array = []
	for id: String in scores:
		var s: Dictionary = scores[id]
		if team.get(id) == side and (s.dmg > 0 or s.kills > 0):
			list.append([id, s])
	list.sort_custom(func(a: Array, b: Array) -> bool:
		return a[1].kills > b[1].kills or (a[1].kills == b[1].kills and a[1].dmg > b[1].dmg))
	return list[0] if not list.is_empty() else []


## the heroes' rows at the end: everyone who started on the heroes' side but the Beacon, with the life left (0 for the
## fallen: the state drops them), the tally and the highlight. `roster`: id -> {team, def} as the battle started
func end_heroes(roster: Dictionary, units: Array) -> Array:
	var team := {}
	for id: String in roster:
		team[id] = roster[id].team
	var best: Array = mvp(team, "hero")
	var out: Array = []
	for id: String in roster:
		var r: Dictionary = roster[id]
		if r.team != "hero" or Content.is_objective(r.def):
			continue
		var hp := 0
		for u: Dictionary in units:
			if u.id == id:
				hp = u.hp
		var s: Dictionary = scores.get(id, {"dmg": 0, "kills": 0})
		out.append({"id": id, "def": r.def, "hp": hp, "max": Content.units[r.def].hp, "dmg": s.dmg, "kills": s.kills, "mvp": not best.is_empty() and best[0] == id})
	return out


## the side and sheet of each unit as the battle starts (the dead leave the state)
static func roster_of(units: Array) -> Dictionary:
	var out := {}
	for u: Dictionary in units:
		out[u.id] = {"team": u.team, "def": u.def}
	return out


## a hero's line at the end of a battle with nothing carried on: what it did, or that it fell. [text, tone]
static func tally_line(h: Dictionary) -> Array:
	if h.hp <= 0:
		return [Texts.t("Caído", "Fallen"), "fell"]
	var k: int = h.kills
	return [Texts.t("%d de dano · %d derrubado%s" % [h.dmg, k, "" if k == 1 else "s"], "%d damage · %d %s" % [h.dmg, k, "takedown" if k == 1 else "takedowns"]), ""]


## an expedition room's line: the life the hero takes into the next room, or that it fell and comes back with it;
## with nothing carried (a lost or finished expedition), what it did
static func room_line(h: Dictionary, carried: Variant = null) -> Array:
	if carried == null:
		return tally_line(h)
	var life := "%d/%d" % [carried.hp, carried.max]
	if h.hp <= 0:
		return [Texts.t("Caiu · volta com %s de vida" % life, "Fell · back at %s HP" % life), "fell"]
	return [Texts.t("Segue com %s de vida" % life, "Goes on with %s HP" % life), "gain"]

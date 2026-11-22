class_name TurnRows
## Pure side of the turn list (port of the web game's turn-list.ts): the current round and the next, the queue projection
## while aiming a charge (the spell goes in where it fires and whoever it hits is marked), and each card's lines.

# rows of the projection the list reads: today's speeds show 12 units twice in about 60 rows
# shortcut: a unit too slow to show within the cap is left off the list; raise it if a battle ever needs more
const CAP := 128


## rows up to the one that completes the round: every unit that plays and every queued charge shows at least once
static func round_length(rows: Array) -> int:
	var seen := {}
	var n := 0
	for i in rows.size():
		var r: Dictionary = rows[i]
		var key: String = r.unit + ("/" + r.charge if r.has("charge") else "")
		if seen.has(key):
			continue
		seen[key] = true
		n = i + 1
	return n


## the current round and the next (Fernando, Nov 15); each row carries its round
static func two_rounds(rows: Array) -> Array:
	var first := round_length(rows)
	var both := first + round_length(rows.slice(first))
	var out: Array = []
	for i in mini(both, rows.size()):
		var r: Dictionary = rows[i].duplicate()
		r.round = 1 if i < first else 2
		out.append(r)
	return out


## the charge being aimed on an Agir tile screen, {ability, target}, or {} (no screen, no charge, nowhere to land)
static func aim_of(b: Battle, s: Dictionary) -> Dictionary:
	if not s.k in ["spot", "aim"]:
		return {}
	var a := ActTurn.screen_action(b, s)
	if a.is_empty() or a.k != "ability" or not Content.abilities[a.id].charge:
		return {}
	var at: Variant = ActTurn.aim_at(b, s) if s.k == "aim" else (a.spots[s.index].aim if s.index < a.spots.size() else null)
	return {} if at == null else {"ability": a.id, "target": at}


## the turn list: every unit that plays, from the one acting now through this round and the next, with each queued
## charge where it fires and its ticks left. While aiming, the one acting pays the cost of acting after what it already
## did, and a charge goes in where it will fire (`at`) with whoever it hits in `targets`. A copy: the state is not changed
static func queue(b: Battle, aim: Dictionary) -> Dictionary:
	var me: String = b.actor().id
	var ab: Dictionary = Content.abilities[aim.ability] if not aim.is_empty() else {}
	var charges: Array = b.state.charges
	if not ab.is_empty():
		charges = charges.filter(func(c: Dictionary) -> bool: return c.unit != me)
		var on := Pathing.unit_at(b.state, aim.target) if not ab.get("panel", false) else {}
		charges.append({"unit": me, "ability": aim.ability, "target": aim.target, "follow": on.get("id"), "ticks": ab.charge})
	var state := b.state.duplicate()
	state.charges = charges
	var now := {"moved": b.state.turn.moved, "acted": true} if not aim.is_empty() else {"moved": true, "acted": true}
	var all := TurnQueue.preview_order(state, CAP, now)
	for r in all:
		if r.has("charge"):
			for c in charges:
				if c.unit == r.unit and c.ability == r.charge:
					r.ticks = c.ticks
	var at := -1
	var targets := {}
	if not ab.is_empty():
		for i in all.size():
			if all[i].unit == me and all[i].get("charge", "") == aim.ability:
				at = i
				break
		var p := b.preview(aim.ability, aim.target)
		if p.get("ok", false):
			for t in p.targets:
				targets[t.unit] = true
	return {"rows": two_rounds(all), "targets": targets, "at": at}


## a unit's first card: its name, then life and mana, then stamina and CT (Fernando, Nov 20); a pool it lacks is left out
static func card_lines(u: Dictionary) -> Array:
	var def: Dictionary = Content.units[u.def]
	var pools: Dictionary = def.get("vars", {})
	var pool := func(k: String, label: String) -> String:
		return "%s %d/%d" % [label, Pools.pool_of(u, k), pools[k]] if pools.has(k) else ""
	var join := func(parts: Array) -> String:
		return " · ".join(parts.filter(func(x: String) -> bool: return x != ""))
	var ct := clampi(u.ct, 0, TurnQueue.THRESHOLD)
	return [Texts.unit_name(u.def), join.call(["HP %d/%d" % [maxi(0, u.hp), def.hp], pool.call("mana", "MP")]), join.call([pool.call("stamina", "ST"), "CT %d/%d" % [ct, TurnQueue.THRESHOLD]])]


## how full each bar of a first card is, 0 to 1: life, mana, stamina and CT; under 0 for a pool the unit lacks
static func card_bars(u: Dictionary) -> Array:
	var def: Dictionary = Content.units[u.def]
	var pools: Dictionary = def.get("vars", {})
	var fill := func(k: String) -> float:
		return clampf(float(Pools.pool_of(u, k)) / pools[k], 0.0, 1.0) if pools.get(k, 0) > 0 else -1.0
	return [clampf(float(u.hp) / def.hp, 0.0, 1.0), fill.call("mana"), fill.call("stamina"), clampf(float(u.ct) / TurnQueue.THRESHOLD, 0.0, 1.0)]


## the long line the hover tells: life with what comes back each turn and CT with what each tick gives
static func stats_text(u: Dictionary) -> String:
	var def: Dictionary = Content.units[u.def]
	var regen: int = def.get("hpRegen", 0)
	var hp := "%s %d/%d" % [Texts.t("Vida", "HP"), maxi(0, u.hp), def.hp]
	var ct := "CT %d/%d" % [clampi(u.ct, 0, TurnQueue.THRESHOLD), TurnQueue.THRESHOLD]
	return hp + (Texts.t(" (+%d por turno)", " (+%d per turn)") % regen if regen else "") + " · " + ct + Texts.t(" (+%d por tique)", " (+%d per tick)") % def.speed

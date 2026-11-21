class_name TurnQueue
## FFT turn queue (port of turn-queue.ts): each unit gains `speed` CT per tick and acts on reaching 100; charges count down
## and fire before the next turn opens. Source: Battle Mechanics Handbook v6.1, 1.1 and A.2.

const THRESHOLD := 100


## CT at the end of the turn: moving and acting costs 100, one of the two 80, neither 60; never above 60
static func turn_ct(ct: int, moved: bool, acted: bool) -> int:
	return mini(60, ct - (100 if moved and acted else (80 if moved or acted else 60)))


static func _slots_of(state: Dictionary) -> Array:
	var enemies: Array = []
	var heroes: Array = []
	for u in state.units:
		var speed: int = Content.units[u.def].speed
		if speed <= 0:
			continue
		var s := {"id": u.id, "ct": u.ct, "speed": speed}
		if u.team == "enemy":
			enemies.append(s)
		else:
			heroes.append(s)
	return enemies + heroes


static func _ticks_to(s: Dictionary) -> int:
	return Util.ceil_div(THRESHOLD - s.ct, s.speed)


static func _list_order(state: Dictionary, charges: Array) -> Array:
	var rank := func(id: String) -> int:
		for i in state.units.size():
			if state.units[i].id == id:
				return (0 if state.units[i].team == "enemy" else 10000) + i
		return 10000 - 1
	return Util.stable_sort(charges, func(a: Dictionary, b: Dictionary) -> bool: return rank.call(a.unit) < rank.call(b.unit))


## Opens the next turn following each FFT tick's phases; returns the events of the charges that fired on the way
static func start_next_turn(grid: Grid, state: Dictionary) -> Array:
	var events: Array = []
	while true:
		var slots := _slots_of(state)
		for s in slots:
			if s.ct >= THRESHOLD:
				state.turn = {"actor": s.id, "moved": false, "main": null, "bonus": null}
				events.append_array(Combat.regen(Combat.find_unit(state, s.id)))
				return events
		var to_turn := Util.BIG
		for s in slots:
			to_turn = mini(to_turn, _ticks_to(s))
		var to_charge := Util.BIG
		for c in state.charges:
			to_charge = mini(to_charge, c.ticks)
		if slots.is_empty() and state.charges.is_empty():
			return events
		if to_turn < to_charge:
			_gain(state, to_turn)
			for c in state.charges:
				c.ticks -= to_turn
			continue
		_gain(state, to_charge - 1)
		for c in state.charges:
			c.ticks -= to_charge
		var due_raw: Array = []
		var keep: Array = []
		for c in state.charges:
			if c.ticks <= 0:
				due_raw.append(c)
			else:
				keep.append(c)
		var due := _list_order(state, due_raw)
		state.charges = keep
		for c in due:
			if Combat.find_unit(state, c.unit).is_empty():
				continue
			var aim := Pathing.aim_tile(grid, state, charge_aim(state, c))
			var out := Combat.resolve(grid, state, c.unit, c.ability, aim, true)
			var landed := false
			for e in out:
				if e.k != "attack":
					landed = true
			if not landed and out.size() and out[0].k == "attack" and out[0].target != aim:
				landed = true
			if landed:
				events.append_array(out)
			else:
				events.append({"k": "fizzle", "unit": c.unit, "ability": c.ability})
			if state.outcome != "ongoing":
				return events
		_gain(state, 1)
	return events


static func _gain(state: Dictionary, ticks: int) -> void:
	for s in _slots_of(state):
		Combat.find_unit(state, s.id).ct += ticks * s.speed


## where a charge aims when it fires: the locked tile, or the followed unit's tile nearest to its caster
static func charge_aim(state: Dictionary, c: Dictionary) -> Vector2i:
	var followed := Combat.find_unit(state, c.follow) if c.follow != null else {}
	var caster := Combat.find_unit(state, c.unit)
	if followed.is_empty():
		return c.target
	return Pathing.nearest_tile(followed, caster.pos) if not caster.is_empty() else followed.pos


static func finish_turn(state: Dictionary) -> void:
	var actor := Combat.find_unit(state, state.turn.actor)
	if not actor.is_empty():
		actor.ct = turn_ct(actor.ct, state.turn.moved, state.turn.main != null or state.turn.bonus != null)
	Effects.tick_effects(state, state.turn.actor)
	state.turnsPlayed += 1


## The next `n` in the queue, starting with whoever plays now, with the charges where they fire: [{unit, charge?}]
static func preview_order(state: Dictionary, n: int, now: Dictionary = {"moved": true, "acted": true}) -> Array:
	var slots := _slots_of(state)
	var charges: Array = []
	for c in _list_order(state, state.charges):
		charges.append(c.duplicate())
	var order: Array = []
	for s in slots:
		if s.id == state.turn.actor:
			order.append({"unit": s.id})
			s.ct = turn_ct(s.ct, now.moved, now.acted)
			break
	while order.size() < n and (slots.size() or charges.size()):
		var to_turn := Util.BIG
		var ready := false
		for s in slots:
			if s.ct >= THRESHOLD:
				ready = true
		if ready:
			to_turn = 0
		else:
			for s in slots:
				to_turn = mini(to_turn, _ticks_to(s))
		var to_charge := Util.BIG
		for c in charges:
			to_charge = mini(to_charge, c.ticks)
		if to_charge <= to_turn:
			for s in slots:
				s.ct += (to_charge - 1) * s.speed
			for c in charges:
				c.ticks -= to_charge
			var left: Array = []
			for c in charges:
				if c.ticks <= 0:
					order.append({"unit": c.unit, "charge": c.ability})
				else:
					left.append(c)
			charges = left
			for s in slots:
				s.ct += s.speed
			continue
		for c in charges:
			c.ticks -= to_turn
		var nxt := _advance(slots)
		order.append({"unit": nxt.id})
		nxt.ct = turn_ct(nxt.ct, true, true)
	return order.slice(0, n)


static func _advance(slots: Array) -> Dictionary:
	var any := false
	for s in slots:
		if s.ct >= THRESHOLD:
			any = true
	if not any:
		var ticks := Util.BIG
		for s in slots:
			ticks = mini(ticks, _ticks_to(s))
		for s in slots:
			s.ct += ticks * s.speed
	for s in slots:
		if s.ct >= THRESHOLD:
			return s
	return {}

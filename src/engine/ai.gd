class_name Ai
## The enemy (and simulated hero) AI (port of ai.ts): greedy for one turn, no rolls, so the same situation plays the same.
## Weights in "expected life points"; LIFE scales them with the x5 life of Nov 15.

const LIFE := 5
const KILL := 8 * LIFE
const OBJECTIVE := 1.5
const FRIENDLY := 1.5
const CHARGE := 0.5 * LIFE
const COVER := 1 * LIFE
const HEIGHT := 0.4 * LIFE
const APPROACH := 0.35 * LIFE
const OBJECTIVE_PULL := 3
const THREAT := 0.25
const ADVANCE := 1.2 * LIFE
const GUARD := 2 * LIFE
const ESCAPE := 0.4
const LINE := 1
const KIN := 0.5 * LIFE
const GUARD_RADIUS := 10


static func _avg(r: Array) -> float:
	return (r[0] + r[1]) / 2.0


static func _with_unit_at(state: Dictionary, actor: Dictionary, spot: Vector2i) -> Dictionary:
	var moved := state.duplicate()
	var units: Array = []
	for u in state.units:
		if is_same(u, actor):
			var c: Dictionary = u.duplicate()
			c.pos = spot
			units.append(c)
		else:
			units.append(u)
	moved.units = units
	return moved


static func attack_score(grid: Grid, state: Dictionary, actor: Dictionary, ability_id: String, target: Vector2i, charged: bool = false, tile: Variant = null) -> float:
	var ability: Dictionary = Content.abilities[ability_id]
	var on_tile: bool = tile if tile != null else ability.get("panel", false)
	var p := Combat.preview(grid, state, actor.id, ability_id, target, charged)
	if not p.ok:
		return -INF
	var total: float = -CHARGE * ability.charge
	for t in p.targets:
		var u := Combat.find_unit(state, t.unit)
		var chance: float = t.chance / 100.0
		if t.healMax > 0:
			var healed: float = chance * minf((t.healMin + t.healMax) / 2.0, Content.units[u.def].hp - u.hp)
			total += healed if u.team == actor.team else -healed * FRIENDLY
			continue
		var push_dmg: int = Push.simulate(grid, state, u, p.center, actor.pos, ability.push).dmg if ability.push > 0 else 0
		var dmg: float = (t.dmgMin + t.dmgMax) / 2.0
		var expected: float = chance * (minf(dmg + push_dmg, u.hp) + (KILL if dmg + push_dmg >= u.hp else 0))
		var foe: bool = u.team != actor.team
		var leaves := 1.0
		if on_tile and ability.charge and u.ct + Content.units[u.def].speed * ability.charge >= TurnQueue.THRESHOLD:
			leaves = ESCAPE
		total += (expected * (OBJECTIVE if Content.is_objective(u.def) else 1.0) if foe else -expected * FRIENDLY) * leaves
	return total


static func _candidate_targets(grid: Grid, state: Dictionary, actor: Dictionary, ability: Dictionary) -> Array:
	if ability.range[1] == 0:
		return [actor.pos]
	var out := {}
	for u in state.units:
		if u.id == actor.id:
			continue
		for f in Pathing.footprint(u):
			out[Grid.pos_key(f)] = f
			if ability.radius > 0:
				for n in grid.neighbors(f):
					out[Grid.pos_key(n)] = n
	return out.values()


## on-foot distance from each tile to the nearest enemy, in movement points, read from the enemies' side
static func walk_map(grid: Grid, state: Dictionary, actor: Dictionary) -> Dictionary:
	var jump := Pathing.jump_of(state, actor.def)
	var size := Pathing.size_of(actor.def)
	var best := {}
	var queue: Array = []
	for o in state.units:
		if o.team == actor.team:
			continue
		var cost: int = -OBJECTIVE_PULL * grid.sub if Content.is_objective(o.def) else 0
		var k := Grid.pos_key(o.pos)
		if best.has(k) and best[k] <= cost:
			continue
		best[k] = cost
		queue.append([o.pos, cost])
	var never := func(_c: Vector2i) -> bool: return false
	var i := 0
	while i < queue.size():
		var p: Vector2i = queue[i][0]
		var cost: int = queue[i][1]
		i += 1
		var pk := Grid.pos_key(p)
		if best.has(pk) and cost > best[pk]:
			continue
		if size > 1:
			for m in Pathing.square_moves(grid, p, size, jump, never):
				var k := Grid.pos_key(m.to)
				if best.has(k) and best[k] <= cost + m.cost:
					continue
				best[k] = cost + m.cost
				queue.append([m.to, cost + m.cost])
			continue
		var here := grid.tile(p)
		for n in grid.neighbors(p):
			var t := grid.tile(n)
			var nxt := cost + Grid.step_cost(here)
			var k := Grid.pos_key(n)
			if not Grid.can_stand(t) or absi(t.h - here.h) > jump or (best.has(k) and best[k] <= nxt):
				continue
			best[k] = nxt
			queue.append([n, nxt])
		for lp in Pathing.leaps(grid, p, jump):
			var nxt: int = cost + lp.over.size() + Grid.step_cost(here)
			var k := Grid.pos_key(lp.to)
			if best.has(k) and best[k] <= nxt:
				continue
			best[k] = nxt
			queue.append([lp.to, nxt])
	return best


static func _position_score(grid: Grid, state: Dictionary, actor: Dictionary, at: Vector2i, attacking: bool, walk: Dictionary) -> float:
	var size := Pathing.size_of(actor.def)
	var cells: Array = []
	for c in Pathing.cells_of(at, size):
		cells.append(grid.tile(c))
	var sub := float(grid.sub)
	var spiked := false
	var all_cover := true
	for t in cells:
		if t.get("spikes", false):
			spiked = true
		if not Grid.cover(t):
			all_cover = false
	var spike: float = 0.0 if not spiked else (1000.0 if actor.hp <= Combat.SPIKE_DAMAGE else float(Combat.SPIKE_DAMAGE))
	var score: float = (COVER if all_cover else 0.0) + HEIGHT * Pathing.square_h(grid, at, size) - spike
	var nearest := INF
	for o in state.units:
		if o.team == actor.team:
			if not attacking and Content.is_objective(o.def):
				score -= GUARD * maxf(0.0, Grid.dist(at, o.pos) / sub - GUARD_RADIUS)
			continue
		nearest = minf(nearest, Grid.dist(at, o.pos) / sub - (OBJECTIVE_PULL if Content.is_objective(o.def) else 0))
		var def: Dictionary = Content.units[o.def]
		if not attacking or def.speed == 0 or def.abilities.is_empty():
			continue
		var far := -Util.BIG
		for a in def.abilities:
			far = maxi(far, Content.abilities[a].range[1])
		var reach: float = def.move / sub + far
		var ready: Dictionary = o.duplicate()
		Combat.regen(ready)
		if Grid.dist(at, o.pos) / sub <= reach:
			var worst := 0.0
			for a in def.abilities:
				if Combat.can_pay(ready, Content.abilities[a]):
					worst = maxf(worst, _avg(Combat.damage_range(state, o, Content.abilities[a], actor)))
			score -= THREAT * worst
	var key := Grid.pos_key(at)
	if walk.has(key):
		nearest = walk[key] / sub
	return score - (APPROACH if attacking else ADVANCE) * (nearest if is_finite(nearest) else 0.0) - LINE * _in_line(grid, state, actor)


static func _in_line(grid: Grid, state: Dictionary, actor: Dictionary) -> float:
	var lost := 0.0
	for c in state.charges:
		if c.unit == actor.id:
			continue
		var p := Combat.preview(grid, state, c.unit, c.ability, TurnQueue.charge_aim(state, c), true)
		for t in p.targets:
			if t.unit == actor.id:
				lost += (t.chance / 100.0) * _avg([t.dmgMin, t.dmgMax])
				break
	return lost


static func _kin_near(state: Dictionary, me: Dictionary) -> int:
	if not Content.units[me.def].get("swarm", false):
		return 0
	var mine := Pathing.footprint(me)
	var n := 0
	for o in state.units:
		if o.id == me.id or o.team != me.team or not Content.units[o.def].get("swarm", false):
			continue
		var touch := false
		for c in Pathing.footprint(o):
			for m in mine:
				if maxi(absi(c.x - m.x), absi(c.y - m.y)) <= 1:
					touch = true
					break
			if touch:
				break
		if touch:
			n += 1
	return n


## best move of the turn: {moveTo (Vector2i or null), ability ({id, target} or null), score}
static func choose_turn(grid: Grid, state: Dictionary, unit_id: String) -> Dictionary:
	var actor := Combat.find_unit(state, unit_id)
	var spots: Array = [actor.pos]
	for s in Pathing.reachable(grid, state, unit_id).values():
		spots.append(s.pos)
	var walk := walk_map(grid, state, actor)
	# how far each ability can possibly reach (the tallest drop counted): a target past it fails the range check anyway,
	# so it is skipped before the costly preview; the same bound action_options uses, decisions unchanged
	var lo := Util.BIG
	var hi := -Util.BIG
	for t in grid.tiles:
		lo = mini(lo, Grid.stand_h(t))
		hi = maxi(hi, Grid.stand_h(t))
	var far := {}
	for id in Content.units[actor.def].abilities:
		var a: Dictionary = Content.abilities[id]
		far[id] = Reach.far_cells(grid, a.range[1] + (hi - lo if a.heightRange else 0)) + 2 * (grid.sub - 1)
	var plans: Array = []
	for i in spots.size():
		var spot: Vector2i = spots[i]
		var moved := _with_unit_at(state, actor, spot)
		var me := Combat.find_unit(moved, unit_id)
		var body := 0
		for c in Pathing.footprint(me):
			body = maxi(body, Grid.dist(spot, c))
		var attack: Variant = null
		var attack_best := 0.0
		for id in Content.units[actor.def].abilities:
			# a preview reads only the whole tile a target stands for: the first cell of each tile scores it, and a later
			# cell of the same tile can only tie, which never replaces the plan
			var tried := {}
			for target in _candidate_targets(grid, moved, me, Content.abilities[id]):
				if Grid.dist(spot, target) - body > far[id]:
					continue
				var aim := Pathing.aim_tile(grid, moved, target)
				if tried.has(aim):
					continue
				tried[aim] = true
				var s := attack_score(grid, moved, me, id, target)
				if s > attack_best:
					attack_best = s
					attack = {"id": id, "target": target}
		var score := attack_best + _position_score(grid, moved, me, spot, attack != null, walk)
		plans.append({"plan": {"moveTo": null if i == 0 else spot, "ability": attack, "score": score}, "kin": KIN * _kin_near(moved, me)})
	var top: Dictionary = plans[0]
	for p in plans:
		if p.plan.score > top.plan.score:
			top = p
	var best: Variant = null
	for p in plans:
		if (p.plan.ability != null) != (top.plan.ability != null):
			continue
		if best == null or p.plan.score + p.kin > best.plan.score + best.kin:
			best = p
	return best.plan


static func _counter_cost(grid: Grid, state: Dictionary, me: Dictionary, to: Vector2i) -> float:
	var lost := 0.0
	for c in Counter.pending(grid, state, me.id, to):
		for t in c.preview.targets:
			if t.unit == me.id:
				var dmg := _avg([t.dmgMin, t.dmgMax]) * Combat.COUNTER
				lost += (t.chance / 100.0) * (minf(dmg, me.hp) + (KILL if dmg >= me.hp else 0))
				break
	return lost


static func choose_retreat(grid: Grid, state: Dictionary, unit_id: String, reach: Dictionary) -> Variant:
	var me := Combat.find_unit(state, unit_id)
	var walk := walk_map(grid, state, me)
	var own: Variant = null
	for c in state.charges:
		if c.unit == unit_id:
			own = c
			break
	var value := func(spot: Vector2i, stay: bool) -> float:
		var moved := _with_unit_at(state, me, spot)
		var at := Combat.find_unit(moved, unit_id)
		var s := _position_score(grid, moved, at, spot, true, walk)
		if own != null:
			s += attack_score(grid, moved, at, own.ability, TurnQueue.charge_aim(moved, own), true, own.follow == null)
		s += KIN * _kin_near(moved, at)
		return s if stay else s - _counter_cost(grid, state, me, spot)
	var best: Variant = null
	var best_score: float = value.call(me.pos, true)
	for step in reach.values():
		var v: float = value.call(step.pos, false)
		if v > best_score + 0.5 * LIFE:
			best_score = v
			best = step.pos
	return best


static func _extra_action(battle: Battle, kind: String) -> Variant:
	var me := battle.actor()
	var best: Variant = null
	var best_score := 0.0
	for id in Content.units[me.def].abilities:
		var a: Dictionary = Content.abilities[id]
		if Slots.kind_of(a) != kind or Slots.free_slot(battle.state.turn, kind) == "":
			continue
		for target in _candidate_targets(battle.grid, battle.state, me, a):
			var s := attack_score(battle.grid, battle.state, me, id, target)
			if s > best_score:
				best_score = s
				best = {"id": id, "target": target}
	return best


## plays the whole turn of the current unit and returns the events
static func play_turn(battle: Battle) -> Array:
	var plan := choose_turn(battle.grid, battle.state, battle.actor().id)
	var events: Array = []
	if plan.moveTo != null:
		events.append_array(battle.move(plan.moveTo))
	if plan.ability != null:
		events.append_array(battle.act(plan.ability.id, plan.ability.target))
	for kind in ["main", "bonus"]:
		var extra: Variant = _extra_action(battle, kind) if plan.ability != null and not battle.over() else null
		if extra != null:
			events.append_array(battle.act(extra.id, extra.target))
	if not battle.over() and plan.ability != null:
		var to: Variant = choose_retreat(battle.grid, battle.state, battle.actor().id, battle.reach())
		if to != null:
			events.append_array(battle.move(to))
	if not battle.over() and not Combat.find_unit(battle.state, battle.state.turn.actor).is_empty() and battle.actor().has("facing"):
		var me := battle.actor()
		var foes: Array = []
		for u in battle.state.units:
			if u.team != me.team:
				foes.append(u)
		if foes.size():
			var near: Dictionary = foes[0]
			for f in foes:
				if Grid.dist(me.pos, f.pos) < Grid.dist(me.pos, near.pos):
					near = f
			battle.face(Grid.facing_to(me.pos, near.pos))
	events.append_array(battle.end_turn())
	return events

class_name Combat
## Hit chance, damage, heals and their preview (port of combat.ts). The preview is what the interface shows before Confirm;
## `resolve` applies it with the rolls in a fixed order (per unit hit, in list order: hit, then damage).

const DIST_PENALTY := 3
const HEIGHT_BONUS := 5
const COVER_PENALTY := 20
const MIN_CHANCE := 5
const MAX_CHANCE := 95
const BUMP_DAMAGE := 25
const FALL_FREE := 1
const FALL_DAMAGE := 45
const SPIKE_DAMAGE := 50
const SIDE_BONUS := 15
const BACK_BONUS := 30
const DODGE_BY_SIDE := {"front": 100, "side": 75, "back": 50}
const CHARGING_PHYS := 50
const CHARGING_MAG := 25
const FRIENDLY_FIRE := 0.5
const UNDEAD_HEAL := 0.5
const COUNTER := 0.5


static func find_unit(state: Dictionary, id: String) -> Dictionary:
	for u in state.units:
		if u.id == id:
			return u
	return {}


static func _with_power(state: Dictionary, actor: Dictionary, a: Dictionary) -> Array:
	var d: Dictionary = Content.units[actor.def]
	var p := 0
	if a.damage[1] > 0:
		p = d.get("magPower", 0) if a.get("magic", false) else d.get("physPower", 0) + Effects.power_bonus(state, actor.id)
	return [a.damage[0] + p, a.damage[1] + p]


static func _heal_range(actor: Dictionary, a: Dictionary) -> Array:
	var p: int = Content.units[actor.def].get("magPower", 0) if a.heal[1] > 0 else 0
	return [a.heal[0] + p, a.heal[1] + p]


static func is_heal(a: Dictionary) -> bool:
	return a.heal[1] > 0 or a.get("ally", false)


static func _side_share(actor: Dictionary, u: Dictionary, heal: bool) -> float:
	return FRIENDLY_FIRE if (u.team == actor.team) != heal else 1.0


static func _heal_hurts(a: Dictionary, u: Dictionary) -> bool:
	return a.heal[1] > 0 and Content.units[u.def].get("undead", false)


static func in_deep(grid: Grid, u: Dictionary) -> bool:
	for c in Pathing.footprint(u):
		if not Grid.is_deep(grid.tile(c)):
			return false
	return true


static func hit_chance(grid: Grid, ability: Dictionary, from: Vector2i, to: Vector2i, side: String = "front") -> int:
	if is_heal(ability):
		return 100
	var d := Reach.whole_tiles(grid, Reach.reach_dist(ability, from, to))
	var dh := Grid.stand_h(grid.tile(from)) - Grid.stand_h(grid.tile(to))
	var cover := COVER_PENALTY if d > 1 and Grid.cover(grid.tile(to)) else 0
	var flank := BACK_BONUS if side == "back" else (SIDE_BONUS if side == "side" else 0)
	var raw: int = ability.accuracy - DIST_PENALTY * maxi(0, d - 1) + HEIGHT_BONUS * dh - cover + flank
	return maxi(MIN_CHANCE, mini(MAX_CHANCE, raw))


static func _affected(grid: Grid, state: Dictionary, actor: Dictionary, ability: Dictionary, center: Vector2i) -> Array:
	if ability.radius > 0:
		var area := Pathing.area_of(grid, state, center)
		var out: Array = []
		for u in state.units:
			if u.id != actor.id and Pathing.in_area(grid, area, ability.radius, Pathing.footprint(u), Reach.is_melee(ability)):
				out.append(u)
		return out
	var u := Pathing.unit_at(state, center)
	if u.is_empty():
		return []
	var wanted: bool
	if u.id == actor.id:
		wanted = ability.get("ally", false) and ability.range[0] == 0
	else:
		wanted = not ability.get("ally", false) or ability.heal[1] > 0 or u.team == actor.team
	return [u] if wanted else []


static func _defence(state: Dictionary, actor: Dictionary, a: Dictionary, u: Dictionary) -> int:
	var d: Dictionary = Content.units[u.def]
	var charging := false
	for c in state.charges:
		if c.unit == u.id:
			charging = true
	var magic: bool = a.get("magic", false)
	var kind := "mag" if magic else "phys"
	var drop := 0 if not charging else (CHARGING_MAG if magic else CHARGING_PHYS)
	var element: String = a.get("element", "" if magic else Effects.hit_element(state, actor.id))
	var elem_resist := Content.resist_of(d, element, Effects.resist_bonus(state, u.id, element)) if element != "" else 0
	return (100 - Content.resist_of(d, kind, Effects.resist_bonus(state, u.id, kind) - drop)) * (100 - elem_resist)


static func facing_side(actor: Dictionary, u: Dictionary) -> String:
	var c := Pathing.closest(Pathing.footprint(actor), Pathing.footprint(u))
	return "front" if not u.has("facing") else Grid.side_of(c[1], Grid.FACING[u.facing], c[0])


## a blow with no damage (the Shove, the sand) lands none; the attacker's effects' damage share applies (Focus, Nov 21)
static func _landed(state: Dictionary, actor: Dictionary, a: Dictionary, u: Dictionary, roll: int, scale: float = 1.0) -> int:
	if a.damage[1] == 0:
		return 0
	var keep := _defence(state, actor, a, u) * Effects.damage_share(state, actor.id)
	var flank: int = 100 + Content.units[actor.def].get("flankDamage", {}).get(facing_side(actor, u), 0)
	return maxi(1, floori(float(roll * keep) * scale * _side_share(actor, u, false) * flank / 100000000.0))


static func after_dodge(chance: int, dodge: int, side: String) -> int:
	return maxi(MIN_CHANCE, Util.floor_div(chance * (10000 - dodge * DODGE_BY_SIDE[side]) + 5000, 10000))


## the attacker's effects' share of the hit chance (sand 75%, Focus 125%; Nov 21), rounded down inside the bounds
static func _aimed(share: int, chance: int) -> int:
	return chance if share == 100 else maxi(MIN_CHANCE, mini(MAX_CHANCE, Util.floor_div(chance * share, 100)))


static func damage_range(state: Dictionary, actor: Dictionary, a: Dictionary, u: Dictionary, scale: float = 1.0) -> Array:
	var r := _with_power(state, actor, a)
	var lo: int = _landed(state, actor, a, u, r[0], scale) if r[0] > 0 else 0
	var hi: int = _landed(state, actor, a, u, r[1], scale) if r[1] > 0 else 0
	return [lo, hi]


static func _fail(reason: String, center: Vector2i) -> Dictionary:
	return {"ok": false, "reason": reason, "center": center, "targets": []}


## What the ability would do if confirmed, without touching the state. `origin`: where the actor would act from (null: where
## it stands). `scale`: the damage share (a dual action in the secondary slot)
static func preview(grid: Grid, state: Dictionary, actor_id: String, ability_id: String, target: Vector2i, charged: bool = false, origin: Variant = null, scale: float = 1.0) -> Dictionary:
	var actor := find_unit(state, actor_id)
	if not actor.is_empty() and origin != null and origin != actor.pos:
		var moved := state.duplicate()
		var units: Array = []
		for u in state.units:
			if is_same(u, actor):
				var c: Dictionary = u.duplicate()
				c.pos = origin
				units.append(c)
			else:
				units.append(u)
		moved.units = units
		return preview(grid, moved, actor_id, ability_id, target, charged, null, scale)
	var ability: Dictionary = Content.abilities.get(ability_id, {})
	var center: Vector2i = actor.pos if not ability.is_empty() and ability.range[1] == 0 and not actor.is_empty() else target
	if actor.is_empty() or ability.is_empty() or not Content.units[actor.def].abilities.has(ability_id) or not grid.in_bounds(center):
		return _fail("unknown", center)
	center = Pathing.aim_tile(grid, state, center)
	if not charged and not Pools.can_pay(actor, ability):
		return _fail("spent", center)
	if not charged and in_deep(grid, actor):
		return _fail("water", center)
	if Effects.stunned(state, actor.id):
		return _fail("stunned", center)  # no actions, counters and charges included (Nov 21)
	var ends := Pathing.aim_ends(grid, state, actor, center)
	if not Reach.in_ability_range(grid, ability, ends[0], ends[1]):
		return _fail("range", center)
	var shot: Variant = Shot.trace(grid, state, actor, center, ability.get("arc", false)) if ability.needsSight else null
	var stop: Variant = shot.stop if shot != null else null
	if stop != null:
		center = stop.pos
	var hit: Array
	if stop != null and ability.radius == 0:
		var blocker := find_unit(state, stop.unit) if stop.unit != null else {}
		hit = [blocker] if not blocker.is_empty() else []
	else:
		hit = _affected(grid, state, actor, ability, center)
	var targets: Array = []
	var hr := _heal_range(actor, ability)
	for u in hit:
		var c := Pathing.closest(Pathing.footprint(actor), Pathing.footprint(u))
		var side := facing_side(actor, u)
		var hurts := _heal_hurts(ability, u)
		var dr := damage_range(state, actor, ability, u, scale)
		var share := _side_share(actor, u, true)
		var chance: int
		if is_heal(ability):
			chance = 100
		else:
			var base := mini(MAX_CHANCE, hit_chance(grid, ability, c[0], c[1], side) + Content.units[actor.def].get("hit", 0))
			chance = _aimed(Effects.hit_share(state, actor.id), after_dodge(base, Content.dodge_of(Content.units[u.def]), side))
		targets.append({
			"unit": u.id,
			"side": side,
			"chance": chance,
			"dmgMin": floori(hr[0] * UNDEAD_HEAL) if hurts else dr[0],
			"dmgMax": floori(hr[1] * UNDEAD_HEAL) if hurts else dr[1],
			"healMin": 0 if hurts else floori(hr[0] * share),
			"healMax": 0 if hurts else floori(hr[1] * share),
		})
	var out := {"ok": true, "center": center, "targets": targets}
	if shot != null:
		out.shot = shot
	return out


## Applies the ability to the state and returns the events. `scale`: fraction of the damage (the counter at half)
static func resolve(grid: Grid, state: Dictionary, actor_id: String, ability_id: String, target: Vector2i, charged: bool = false, scale: float = 1.0) -> Array:
	var p := preview(grid, state, actor_id, ability_id, target, charged)
	if not p.ok:
		return []
	var actor := find_unit(state, actor_id)
	var ability: Dictionary = Content.abilities[ability_id]
	var attack := {"k": "attack", "unit": actor_id, "ability": ability_id, "target": p.center}
	if p.has("shot"):
		attack.shot = p.shot
	var events: Array = [attack]
	if not charged:
		Pools.pay(actor, ability)
	for t in p.targets:
		var unit := find_unit(state, t.unit)
		if is_heal(ability):
			if ability.heal[1] == 0:
				_leave_effect(state, unit, ability_id, events)
				continue
			var hr := _heal_range(actor, ability)
			var r := Rng.roll_int(state.rng, hr[0], hr[1])
			var amount: int = r[0]
			state.rng = r[1]
			if _heal_hurts(ability, unit):
				var dmg := maxi(1, floori(amount * UNDEAD_HEAL))
				events.append({"k": "hit", "unit": unit.id, "dmg": dmg, "chance": 100})
				_hurt(state, unit, dmg, events)
				continue
			var healed := mini(floori(amount * _side_share(actor, unit, true)), Content.units[unit.def].hp - unit.hp)
			unit.hp += healed
			events.append({"k": "heal", "unit": unit.id, "amount": healed})
			continue
		var rr := Rng.next(state.rng)
		state.rng = rr[1]
		if float(rr[0]) * 100 >= t.chance:
			events.append({"k": "miss", "unit": unit.id, "chance": t.chance})
			continue
		var wp := _with_power(state, actor, ability)
		var dr := Rng.roll_int(state.rng, wp[0], wp[1])
		state.rng = dr[1]
		var dmg2 := _landed(state, actor, ability, unit, dr[0], scale)
		# a blow with no damage (the Shove, the sand) shows no −0 (Nov 21)
		if ability.damage[1] > 0:
			events.append({"k": "hit", "unit": unit.id, "dmg": dmg2, "chance": t.chance})
		if not _hurt(state, unit, dmg2, events):
			continue
		_leave_effect(state, unit, ability_id, events)
		if ability.push == 0:
			continue
		if ability.has("pushChance"):
			var pr := Rng.next(state.rng)
			state.rng = pr[1]
			if float(pr[0]) * 100 >= ability.pushChance:
				continue
		_push(grid, state, unit, p.center, actor.pos, ability.push, events)
	if ability.damage[1] > 0:
		Effects.spend_once(state, actor.id)  # the attack Focus was waiting for
	state.outcome = Outcome.check(state)
	return events


## an ability's timed effect, if it leaves one (stun, sand, focus), said in the log and over the unit
static func _leave_effect(state: Dictionary, unit: Dictionary, ability_id: String, events: Array) -> void:
	if Effects.add_effect(state, unit.id, ability_id):
		events.append({"k": "effect", "unit": unit.id, "item": ability_id, "turns": Content.buffs[ability_id].turns})


## removes life; false if the unit died (and left the list)
static func _hurt(state: Dictionary, unit: Dictionary, dmg: int, events: Array) -> bool:
	unit.hp -= dmg
	if unit.hp > 0:
		return true
	var units: Array = []
	for u in state.units:
		if not is_same(u, unit):
			units.append(u)
	state.units = units
	# only bodies of a whole tile and up stay (Fernando, Nov 21): a half-tile creature (a rat, a bat) leaves its ground free
	if Content.units[Content.base_def(unit.def)].get("halfSize", 2) >= 2:
		var fp := Pathing.footprint(unit)
		var corpses: Array = state.get("corpses", []).duplicate()
		corpses.append_array(fp)
		state.corpses = corpses
		var defs: Dictionary = state.get("corpseDefs", {}).duplicate()
		for c in fp:
			defs[Grid.pos_key(c)] = unit.def
		state.corpseDefs = defs
	if state.turn.has("engaged"):
		var turn: Dictionary = state.turn
		var left: Array = []
		for id in turn.engaged:
			if id != unit.id:
				left.append(id)
		turn.engaged = left
	var charges: Array = []
	for c in state.charges:
		if c.unit == unit.id:
			continue
		if c.follow == unit.id:
			var cc: Dictionary = c.duplicate()
			cc.follow = null
			cc.target = unit.pos
			charges.append(cc)
		else:
			charges.append(c)
	state.charges = charges
	events.append({"k": "die", "unit": unit.id})
	return false


static func spike_at_turn_end(grid: Grid, state: Dictionary) -> Array:
	var actor := find_unit(state, state.turn.actor)
	if actor.is_empty():
		return []
	var spiked := false
	for c in Pathing.footprint(actor):
		if grid.tile(c).get("spikes", false):
			spiked = true
	if not spiked:
		return []
	var events: Array = [{"k": "spike", "unit": actor.id, "dmg": SPIKE_DAMAGE}]
	_hurt(state, actor, SPIKE_DAMAGE, events)
	return events


static func _push(grid: Grid, state: Dictionary, unit: Dictionary, center: Vector2i, origin: Vector2i, steps: int, events: Array) -> void:
	var r := Push.simulate(grid, state, unit, center, origin, steps)
	unit.pos = r.to
	events.append_array(r.events)
	if r.dmg > 0:
		_hurt(state, unit, r.dmg, events)

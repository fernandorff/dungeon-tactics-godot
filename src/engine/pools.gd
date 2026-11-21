class_name Pools
## A unit's pools (mana, stamina): what is left, paying an ability's cost and the regen at the start of its turns (port of
## pools.ts, split from combat.gd as the web game split it on Nov 21).


## what a unit has left of a counter (mana, stamina): absent reads as the sheet's start value
static func pool_of(u: Dictionary, k: String) -> int:
	var v: Dictionary = u.get("vars", {})
	if v.has(k):
		return v[k]
	return Content.units[u.def].get("vars", {}).get(k, 0)


static func can_pay(u: Dictionary, a: Dictionary) -> bool:
	return not a.has("cost") or pool_of(u, a.cost[0]) >= a.cost[1]


static func pay(u: Dictionary, a: Dictionary) -> void:
	if a.has("cost"):
		var v: Dictionary = u.get("vars", {}).duplicate()
		v[a.cost[0]] = pool_of(u, a.cost[0]) - a.cost[1]
		u.vars = v


## pools and life back at the start of each of the unit's turns, never above the sheet's max
static func regen(u: Dictionary) -> Array:
	var d: Dictionary = Content.units[u.def]
	for k in d.get("regen", {}):
		var v: Dictionary = u.get("vars", {}).duplicate()
		v[k] = mini(d.get("vars", {}).get(k, 0), pool_of(u, k) + d.regen[k])
		u.vars = v
	var amount := mini(d.get("hpRegen", 0), d.hp - u.hp)
	if amount <= 0:
		return []
	u.hp += amount
	return [{"k": "regen", "unit": u.id, "amount": amount}]

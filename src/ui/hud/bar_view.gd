class_name BarView
## Pure side of the combat bar (port of the web game's forecast.ts and bar3d/bar-view.ts): what a strike does to each
## target (hit, damage or heal, push, life after), the acting unit's and the target's sheets and the plate between them.

## the strike preview `p` (Combat.preview) of `ability` on each target
static func forecast(b: Battle, ability: String, p: Dictionary) -> Array:
	var a: Dictionary = Content.abilities[ability]
	var out: Array = []
	for tg in p.get("targets", []):
		var u := Combat.find_unit(b.state, tg.unit)
		if u.is_empty():
			continue
		var most: int = Content.units[u.def].hp
		var heal: Array = [tg.healMin, tg.healMax] if tg.get("healMax", 0) > 0 else []
		var support: bool = a.get("ally", false) and heal.is_empty()
		# push: the extra damage from collision, fall and spikes, to see the combo before confirming (web, Nov 12)
		var shove := Push.simulate(b.grid, b.state, u, p.center, b.actor().pos, a.push) if a.get("push", 0) and heal.is_empty() and not support else {}
		var push: int = shove.get("dmg", 0)
		var sure := push if not a.has("pushChance") else 0
		var after: Array
		if not heal.is_empty():
			after = [mini(most, u.hp + heal[0]), mini(most, u.hp + heal[1])]
		elif support:
			after = [u.hp, u.hp]
		else:
			after = [maxi(0, u.hp - tg.dmgMax - sure), maxi(0, u.hp - tg.dmgMin - sure)]
		out.append({
			"unit": u, "chance": tg.chance, "dmg": [] if not heal.is_empty() or support else [tg.dmgMin, tg.dmgMax],
			"heal": heal, "push": push, "spikes": shove.get("events", []).any(func(e: Dictionary) -> bool: return e.k == "spike"),
			"after": after, "ally": heal.is_empty() and not support and u.team == b.actor().team, "support": support,
			"side": "front" if not heal.is_empty() or support else tg.get("side", "front"),
		})
	return out


static func _frac(v: float, most: float) -> float:
	return clampf(v / most, 0.0, 1.0)


## a unit's sheet: name, the enemy tag, life with what the aimed strike `f` changes, the pools, CT and the class strip
static func sheet(state: Dictionary, u: Dictionary, f: Dictionary = {}) -> Dictionary:
	var def: Dictionary = Content.units[u.def]
	var pools: Array = []
	for k in ["mana", "stamina"]:
		if def.get("vars", {}).get(k, 0):
			pools.append({"label": "MP" if k == "mana" else "ST", "value": Pools.pool_of(u, k), "max": def.vars[k]})
	var name := Texts.unit_name(u.def)
	var cls_id := Roster.class_of(u.def)
	var cls := Texts.unit_name(cls_id if cls_id != "" else u.def)
	var now := _frac(u.hp, def.hp)
	var struck: bool = not f.is_empty() and not f.support and (not f.heal.is_empty() or not f.dmg.is_empty())
	var change := {"left": now, "sure": now, "up_to": now, "gain": false}
	if struck and not f.heal.is_empty():
		change = {"left": now, "sure": _frac(f.after[0], def.hp), "up_to": _frac(f.after[1], def.hp), "gain": true}
	elif struck:
		change = {"left": _frac(f.after[0], def.hp), "sure": _frac(f.after[1], def.hp), "up_to": now, "gain": false}
	var line: Array = []
	if cls != name:
		line.append(cls)
	for c in state.charges:
		if c.unit == u.id:
			line.append(Texts.t("Carregando %s (%d tiques)", "Charging %s (%d ticks)") % [Texts.ability_name(c.ability), c.ticks])
			break
	return {
		"unit": u, "enemy": u.team == "enemy", "name": name, "tag": Texts.t("Inimigo", "Enemy") if u.team == "enemy" else "",
		"hp": {"label": Texts.t("Vida", "HP"), "value": maxi(0, u.hp), "max": def.hp}, "change": change, "pools": pools.slice(0, 2),
		"ct": {"label": "CT", "value": mini(u.ct, TurnQueue.THRESHOLD), "max": TurnQueue.THRESHOLD} if def.get("speed", 0) > 0 else {},
		"line": " · ".join(line),
		# the turn list's "+4" after the life: the life back at each of its turns (empty without a piece that gives it)
		"hp_regen": "+%d" % def.hpRegen if def.get("hpRegen", 0) else "",
	}


## the plate between the sheets: the chance, the big number ("9 ≈ 12", "+7 ≈ 10"), what it is, the ability and how many
## more targets it reaches; `warn` when it strikes the user's own side
static func plate(f: Dictionary, ability: String, more: int) -> Dictionary:
	var about := func(r: Array) -> String: return Texts.range_text(r).replace("–", " ≈ ")
	var amount: String = "+" + about.call(f.heal) if not f.heal.is_empty() else (about.call(f.dmg) if not f.dmg.is_empty() else "")
	var others := (" · +%d %s" % [more, Texts.t("alvo" if more == 1 else "alvos", "target" if more == 1 else "targets")]) if more else ""
	var hits: bool = amount != "" and f.heal.is_empty()
	var flank := ("↶+%d" % Combat.BACK_BONUS) if f.side == "back" else (("⇥+%d" % Combat.SIDE_BONUS) if f.side == "side" else "")
	var chance := ""
	if amount != "":
		chance = "⊕ %d%%" % f.chance + (" " + flank if hits and flank != "" else "")
	var label: String = Texts.t("Cura", "Heal") if not f.heal.is_empty() else (Texts.t("Dano", "Damage") if not f.dmg.is_empty() else Texts.t("Apoio", "Support"))
	if f.push and hits:
		label += " · " + Texts.t("empurrão +%d", "push +%d") % f.push + ("!" if f.spikes else "")
	if f.ally:
		label += " · " + Texts.t("ALIADO!", "ALLY!")
	return {
		"chance": chance, "amount": amount if amount != "" else Texts.ability_name(ability), "big": amount != "", "label": label,
		"name": (Texts.ability_name(ability) if amount != "" else "") + others, "warn": f.ally,
	}


## what the bar shows: `me` acts; `fs` the aimed strike on each target, the one under the cursor first; without a strike,
## `other` is the unit under the cursor
static func of(state: Dictionary, me: Dictionary, other: Dictionary, fs: Array, ability: String) -> Dictionary:
	var main: Dictionary = fs[0] if ability != "" and fs.size() else {}
	var target := {}
	if not main.is_empty():
		target = sheet(state, main.unit, main)
	elif not other.is_empty():
		target = sheet(state, other)
	return {
		"sheet": sheet(state, me) if not me.is_empty() else {},
		"plate": plate(main, ability, fs.size() - 1) if not main.is_empty() else {},
		"target": target,
	}

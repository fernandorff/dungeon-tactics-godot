class_name Texts
## The player's language and the battle texts (port of i18n.ts and battle-text.ts): t(pt, en) at the point of use, the
## names of units, abilities and items, an ability's facts, the summary of the last action, the Status sheet.

const LANG_KEY := "dt:lang"

static var lang := ""


## the saved choice wins; without it, a Portuguese system opens in Portuguese and the rest in English
static func current() -> String:
	if lang == "":
		var saved := Store.get_key(LANG_KEY)
		lang = saved if saved == "pt" or saved == "en" else ("pt" if OS.get_locale_language() == "pt" else "en")
	return lang


static func set_lang(l: String) -> void:
	lang = l
	Store.set_key(LANG_KEY, l)


static func t(pt: String, en: String) -> String:
	return en if current() == "en" else pt


static func unit_name(def: String) -> String:
	var d: Dictionary = Content.units[def]
	return t(d.name, d.en)


static func ability_name(id: String) -> String:
	var a: Dictionary = Content.abilities[id]
	return t(a.name, a.en)


static func item_name(id: String) -> String:
	var c: Dictionary = Content.consumable.get(id, {})
	if not c.is_empty():
		return t(c.name, c.en)
	var it: Dictionary = Content.items.get(id, {})
	return t(it.name, it.en) if not it.is_empty() else id


static func range_text(r: Array) -> String:
	return "%d" % r[0] if r[0] == r[1] else "%d–%d" % [r[0], r[1]]


static func side_name(team: String) -> String:
	return t("herói", "hero") if team == "hero" else t("inimigo", "enemy")


static func cost_text(a: Dictionary) -> String:
	return "%d %s" % [a.cost[1], a.cost[0]] if a.get("cost") else ""


static func command_name(c: String) -> String:
	return {"move": t("Mover", "Move"), "undo": t("Desfazer movimento", "Undo move"), "act": t("Agir", "Act"), "wait": t("Esperar", "Wait"), "status": "Status"}[c]


static func signed(v: int) -> String:
	return "%s%d%%" % ["+" if v > 0 else ("−" if v < 0 else ""), absi(v)]


static func element_name(e: String) -> String:
	return {"fire": t("fogo", "fire"), "ice": t("gelo", "ice"), "lightning": t("raio", "lightning"), "shadow": t("sombra", "shadow"), "wind": t("vento", "wind"), "light": t("luz", "light")}[e]


## the tag on an Agir row: which of the turn's two actions it takes (only the secondary ones are tagged)
static func kind_tag(a: Dictionary) -> String:
	if a.k == "ability" and Content.abilities[a.id].has("bonusShare"):
		return t("principal ou secundária", "main or bonus")
	return t("secundária", "bonus") if ActFlow.act_kind(a) == "bonus" else ""


## the facts in three groups: reach and hit, what else it does, what it costs
static func ability_pages(id: String) -> Array:
	var a: Dictionary = Content.abilities[id]
	var hit: Array = [t("em volta de você", "around you") if a.range[1] == 0 else t("alcance %s", "range %s") % range_text(a.range)]
	if a.damage[1]:
		hit.append(t("dano %s", "damage %s") % range_text(a.damage))
		hit.append(t("acerto %d%%", "accuracy %d%%") % a.accuracy)
	if a.heal[1]:
		hit.append(t("cura %s", "heals %s") % range_text(a.heal))
	var more: Array = []
	if a.radius:
		more.append(t("área de raio %d (pega aliados)", "area of radius %d (hits allies)") % a.radius)
	if a.get("push", 0):
		more.append(t("empurra %d", "pushes %d") % a.push)
	if a.get("needsSight", false):
		more.append(t("tiro em curva: passa por cima do que é baixo", "arcing shot: flies over what is low") if a.get("arc", false) else t("tiro reto: para no primeiro obstáculo", "straight shot: stops at the first obstacle"))
	elif a.get("magic", false) and a.range[1] > 0:
		more.append(t("conjurada no alvo, sem linha de visão", "cast on the target, no line of sight"))
	if a.get("heightRange", false):
		more.append(t("+1 de alcance por nível acima", "+1 range per level above"))
	var cost: Array = []
	if a.get("cost"):
		cost.append(t("gasta %s", "costs %s") % cost_text(a))
	if a.charge:
		cost.append(t("carrega %d tiques; trava na casa ou no personagem; começar gasta metade do movimento que sobra", "charges %d ticks; locks on the tile or the character; starting it costs half the movement left") % a.charge)
	return [hit, more, cost]


static func ability_detail(id: String) -> String:
	var all: Array = []
	for p in ability_pages(id):
		all.append_array(p)
	return " · ".join(all)


static func item_detail(id: String) -> String:
	var c: Dictionary = Content.consumable.get(id, {})
	if c.is_empty():
		return ""
	var out: Array = []
	if c.get("heal", 0):
		out.append(t("cura %d", "heals %d") % c.heal)
	if c.get("mana", 0):
		out.append(t("+%d de mana", "+%d mana") % c.mana)
	var f: Dictionary = c.get("buff", {})
	if not f.is_empty():
		var parts: Array = []
		if f.get("physPower", 0):
			parts.append(t("+%d de força", "+%d power") % f.physPower)
		if f.get("element"):
			parts.append(t("golpe de %s", "%s strikes") % element_name(f.element))
		for r in f.get("resist", {}):
			var what: String = t("dano físico", "physical damage") if r == "phys" else (t("magia", "magic") if r == "mag" else element_name(r))
			parts.append(t("%s de resistência a %s", "%s %s resistance") % [signed(f.resist[r]), what])
		if f.get("move", 0):
			parts.append(t("%d de movimento", "%d move") % f.move)
		out.append(t("por %d turnos: ", "for %d turns: ") % f.turns + ", ".join(parts))
	return " · ".join(out)


## why an Agir action is off, in a short line under its row
static func act_reason(a: Dictionary) -> String:
	if a.get("reason") == "spent" and a.has("pool"):
		return t("faltam %d de %s", "%d %s short") % [a.missing, a.pool]
	var words := {
		"used": t("ação já usada neste turno", "action already used this turn"),
		"range": t("fora de alcance, mesmo andando", "out of reach, even walking"),
		"sight": t("sem linha de visão", "no line of sight"),
		"no-target": t("não atinge este alvo", "cannot reach this target"),
		"water": t("nadando: só anda ou espera", "swimming: only walk or wait"),
		"stunned": t("atordoado: só anda ou espera", "stunned: only walk or wait"),
		"none": t("acabou", "none left"),
	}
	return words.get(a.get("reason", ""), "")


## the summary of what the last action did, one sentence per action; whoever died has left the state
static func event_log(events: Array, state: Dictionary) -> String:
	var name := func(id: String) -> String:
		var u := Combat.find_unit(state, id)
		if u.is_empty():
			for s in Content.scenarios[state.scenario].spawns:
				if s.id == id:
					return unit_name(s.def)
			return id
		return unit_name(u.def)
	var out: Array = []
	var head := [""]
	var parts: Array = []
	var flush := func() -> void:
		if parts.size():
			out.append(head[0] + " · ".join(parts))
		elif head[0] != "":
			out.append(head[0].left(-3))
		head[0] = ""
		parts.clear()
	for e in events:
		match e.k:
			"attack":
				flush.call()
				head[0] = "%s: %s → " % [name.call(e.unit), ability_name(e.ability)]
			"item":
				flush.call()
				head[0] = "%s: %s → " % [name.call(e.unit), item_name(e.item)]
			"mana":
				parts.append(t("%s +%d de mana", "%s +%d mana") % [name.call(e.unit), e.amount])
			"effect":
				if Content.abilities.has(e.item):
					parts.append("%s %s: %s" % [name.call(e.unit), effect_word(e.item).to_lower(), effect_text(e.item)])
				else:
					parts.append(t("%s por %d turnos", "%s for %d turns") % [name.call(e.unit), e.turns])
			"charge":
				flush.call()
				out.append(t("%s carrega %s", "%s charges %s") % [name.call(e.unit), ability_name(e.ability)])
			"fizzle":
				flush.call()
				out.append(t("%s: %s não achou o alvo", "%s: %s found no target") % [name.call(e.unit), ability_name(e.ability)])
			"hit":
				parts.append("%s −%d" % [name.call(e.unit), e.dmg])
			"miss":
				parts.append(t("errou %s (%d%%)", "missed %s (%d%%)") % [name.call(e.unit), e.chance])
			"heal":
				parts.append("%s +%d" % [name.call(e.unit), e.amount])
			"regen":
				flush.call()
				out.append(t("%s +%d de regeneração", "%s +%d regen") % [name.call(e.unit), e.amount])
			"bump":
				parts.append(t("%s bateu −%d", "%s crashed −%d") % [name.call(e.unit), e.dmg])
			"fall":
				parts.append(t("%s caiu de altura −%d", "%s fell −%d") % [name.call(e.unit), e.dmg])
			"spike":
				parts.append(t("%s nos espinhos −%d", "%s on the spikes −%d") % [name.call(e.unit), e.dmg])
			"die":
				parts.append(t("%s caiu", "%s is down") % name.call(e.unit))
	flush.call()
	return " | ".join(out)


## a timed effect an ability leaves (Nov 21): the word over the unit
static func effect_word(source: String) -> String:
	var f: Dictionary = Content.abilities.get(source, {}).get("buff", {})
	if f.get("stun", false):
		return t("Atordoado", "Stunned")
	if f.get("damage", 0) > 0:
		return t("Focado", "Focused")
	if f.get("accuracy", 0) < 0:
		return t("Ofuscado", "Blinded")
	return ability_name(source)


## what an ability's timed effect does, for the log: "sem ações, −50% de movimento"
static func effect_text(source: String) -> String:
	var f: Dictionary = Content.abilities.get(source, {}).get("buff", {})
	var parts: Array = []
	if f.get("stun", false):
		parts.append(t("sem ações", "no actions"))
	for k in [["accuracy", "acerto", "aim"], ["damage", "dano", "damage"], ["moveShare", "movimento", "move"]]:
		var v: int = f.get(k[0], 0)
		if v:
			parts.append(t("%s de %s" % [signed(v), k[1]], "%s %s" % [signed(v), k[2]]))
	return ", ".join(parts)


static func _tiles(n: int, half: bool) -> String:
	var one := n == 1
	if half:
		return t("%d meia casa" if one else "%d meias casas", "%d half tile" if one else "%d half tiles") % n
	return t("%d casa" if one else "%d casas", "%d tile" if one else "%d tiles") % n


static func distance_text(n: int, half: bool) -> String:
	return _tiles(n, half)


static func attr_rows(def: Dictionary) -> Array:
	var rows: Array = [[t("Poder físico", "Physical power"), str(def.get("physPower", 0))], [t("Poder mágico", "Magic power"), str(def.get("magPower", 0))]]
	rows.append([t("Resistência física", "Physical resistance"), signed(Content.resist_of(def, "phys"))])
	rows.append([t("Resistência mágica", "Magic resistance"), signed(Content.resist_of(def, "mag"))])
	rows.append([t("Esquiva", "Dodge"), "%d%%" % Content.dodge_of(def)])
	var els: Array = []
	for e in Content.ELEMENTS:
		if Content.resist_of(def, e):
			els.append("%s %s" % [element_name(e), signed(Content.resist_of(def, e))])
	if els.size():
		rows.append([t("Elementos", "Elements"), " · ".join(els)])
	return rows


## the Status sheet: what the unit is now, as [label, value] rows
static func unit_status(state: Dictionary, unit_id: String) -> Array:
	var u := Combat.find_unit(state, unit_id)
	var def: Dictionary = Content.units[u.def]
	var half: bool = Content.base_def(u.def) != u.def
	var hp := "%d/%d" % [u.hp, def.hp]
	if def.get("hpRegen", 0):
		hp += t(", +%d de vida por turno", ", +%d HP per turn") % def.hpRegen
	var rows: Array = [[t("Lado", "Side"), side_name(u.team)], [t("Vida", "HP"), hp]]
	for k in Content.RESOURCES:
		if def.get("vars", {}).get(k, 0):
			var line := "%d/%d" % [Pools.pool_of(u, k), def.vars[k]]
			if def.get("regen", {}).get(k, 0):
				line += t(", +%d de %s por turno", ", +%d %s per turn") % [def.regen[k], k]
			rows.append(["Mana" if k == "mana" else "Stamina", line])
	rows.append(["CT", "%d/%d" % [clampi(u.ct, 0, TurnQueue.THRESHOLD), TurnQueue.THRESHOLD]])
	rows.append([t("Velocidade", "Speed"), t("%d de CT por tique", "%d CT per tick") % def.speed])
	rows.append([t("Movimento", "Move"), _tiles(def.move, half)])
	var base_size: int = Content.units[Content.base_def(u.def)].get("size", 1)
	rows.append([t("Salto", "Jump"), _tiles(Pathing.jump_of(state, u.def) * def.get("size", 1) / base_size, half)])
	rows.append_array(attr_rows(def))
	for c in state.charges:
		if c.unit == u.id:
			rows.append([t("Carregando", "Charging"), t("%s, sai em %d tiques", "%s, goes off in %d ticks") % [ability_name(c.ability), c.ticks]])
	if u.has("facing"):
		rows.append([t("Olhando para", "Facing"), [t("sul", "south"), t("leste", "east"), t("norte", "north"), t("oeste", "west")][u.facing]])
	var names: Array = def.abilities.map(func(a: String) -> String: return ability_name(a))
	rows.append([t("Habilidades", "Abilities"), ", ".join(names) if names.size() else "—"])
	return rows

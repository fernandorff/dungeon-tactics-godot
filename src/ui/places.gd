class_name Places
extends Control
## The town's windows (port of town3d/screens.ts, party-view.ts and shop-view.ts): the Guild's Party (who goes, class,
## equipment, dismissal), the Shop (buy and sell), the Tavern (recruit) and the dungeon Gate (the quest). Each draws from
## the saved game, runs the pressed button through the same rules (chest.gd, party.gd) and saves.

signal closed

var main: Main
var _v: VBoxContainer
var _said := ""


static func open(parent: Control, m: Main, kind: String) -> Places:
	var p := Places.new()
	p.main = m
	p.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	parent.add_child(p)
	match kind:
		"party":
			p.party()
		"shop":
			p.shop("buy")
		"tavern":
			p.tavern()
		"quest":
			p.gate()
	return p


func _page(title: String) -> VBoxContainer:
	for c in get_children():
		c.queue_free()
	_v = Kit.page(self, title, 720)
	return _v


func _close() -> void:
	closed.emit()
	queue_free()


func _leave_button(label: String = "") -> void:
	var b := Kit.button(label if label != "" else Texts.t("Sair", "Leave"), _close)
	_v.add_child(b)


func _focus_first() -> void:
	for c in _v.get_children():
		if c is Button:
			c.call_deferred("grab_focus")
			return
		for d in c.get_children():
			if d is Button:
				d.call_deferred("grab_focus")
				return


static func _chest() -> Dictionary:
	return Chest.parse_chest(Store.json(Chest.CHEST_KEY))


static func _equip() -> Dictionary:
	return Chest.parse_equip(Store.json(Chest.EQUIP_KEY))


static func _save(key: String, v: Variant) -> void:
	Store.set_key(key, JSON.stringify(v))


static func kind_name(k: String) -> String:
	return {"main": Texts.t("Mão principal", "Main hand"), "off": Texts.t("Mão secundária", "Off hand"), "head": Texts.t("Cabeça", "Head"), "body": Texts.t("Corpo", "Body"), "legs": Texts.t("Pernas", "Legs"), "accessory": Texts.t("Acessório", "Accessory")}[k]


static func slot_name(s: String) -> String:
	return kind_name("accessory") + " " + s.right(1) if s.begins_with("acc") else kind_name(s)


static func rarity(r: String) -> String:
	return {"common": Texts.t("comum", "common"), "rare": Texts.t("rara", "rare"), "epic": Texts.t("épica", "epic")}[r]


## "+20 poder físico · +5 acerto": only what the piece changes
static func item_stats(id: String) -> String:
	var it: Dictionary = Content.items[id]
	var names := {"hp": Texts.t("vida", "HP"), "physPower": Texts.t("poder físico", "physical power"), "magPower": Texts.t("poder mágico", "magic power"), "hit": Texts.t("acerto", "hit"), "dodge": Texts.t("esquiva", "dodge"), "move": Texts.t("movimento", "move"), "jump": Texts.t("salto", "jump"), "speed": Texts.t("velocidade", "speed"), "mana": "mana", "stamina": "stamina", "manaRegen": Texts.t("mana por turno", "mana per turn"), "hpRegen": Texts.t("vida por turno", "HP per turn")}
	var parts: Array = []
	for k in Equipment.STATS:
		if it.get(k, 0):
			parts.append("%s%d %s" % ["+" if it[k] > 0 else "", it[k], names[k]])
	for r in it.get("resist", {}):
		var what: String = Texts.t("física", "physical") if r == "phys" else (Texts.t("mágica", "magic") if r == "mag" else Texts.element_name(r))
		parts.append("%s %s" % [Texts.signed(it.resist[r]), what])
	return " · ".join(parts)


func _gold_line() -> void:
	_v.add_child(Kit.label(Texts.t("Ouro no baú: %d", "Gold in chest: %d") % _chest().gold, 17, Kit.ACCENT))
	if _said != "":
		_v.add_child(Kit.label(_said, 15, Kit.HERO))


# --- Shop -----------------------------------------------------------------------------------------

func shop(tab: String) -> void:
	_page(Texts.t("Loja", "Shop"))
	_gold_line()
	_said = ""
	var chest := _chest()
	var tabs := HBoxContainer.new()
	tabs.add_child(Kit.button(Texts.t("Comprar", "Buy"), func() -> void: shop("buy")))
	tabs.add_child(Kit.button(Texts.t("Vender (%d)", "Sell (%d)") % chest.items.size(), func() -> void: shop("sell")))
	_v.add_child(tabs)
	if tab == "buy":
		_v.add_child(Kit.label(Texts.t("Peças", "Gear"), 18, Kit.ACCENT))
		for it in Content.data.items:
			if it.rarity != "common":
				continue
			var id: String = it.id
			var why := ""
			if chest.items.size() >= Chest.CHEST_MAX:
				why = Texts.t("baú cheio", "chest full")
			elif chest.gold < it.price:
				why = Texts.t("faltam %d de ouro", "%d gold short") % (it.price - chest.gold)
			var b := Kit.button("%s · %s · %d %s\n   %s%s" % [Texts.t(it.name, it.en), kind_name(it.kind), it.price, Texts.t("de ouro", "gold"), item_stats(id), "" if why == "" else " · " + why], func() -> void:
				var next: Variant = Chest.buy(_chest(), id)
				if next == null:
					Sound.play("cancel")
					return
				_save(Chest.CHEST_KEY, next)
				Sound.play("confirm")
				shop("buy"))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			if why != "":
				b.modulate = Color(0.65, 0.65, 0.68)
			_v.add_child(b)
		_v.add_child(Kit.label(Texts.t("Consumíveis", "Consumables"), 18, Kit.ACCENT))
		for c in Content.consumables:
			# the web game lists them off too: the bag is the expedition's, filled at the start and by chests
			var l := Kit.label("%s · %d %s · %s" % [Texts.t(c.name, c.en), c.price, Texts.t("de ouro", "gold"), Texts.t("usar em batalha vem depois", "using it in battle comes later")], 15, Kit.MUTED)
			_v.add_child(l)
	else:
		var seen := {}
		for id in chest.items:
			seen[id] = seen.get(id, 0) + 1
		if seen.is_empty():
			_v.add_child(Kit.label(Texts.t("Nada para vender. O equipamento guardado no baú aparece aqui.", "Nothing to sell. Spare gear in the chest shows up here."), 15, Kit.MUTED))
		for id in seen:
			var it: Dictionary = Content.items[id]
			var pid: String = id
			var b := Kit.button("%s ×%d · %s · %s %d" % [Texts.t(it.name, it.en), seen[id], rarity(it.rarity), Texts.t("vende por", "sells for"), it.price / 2], func() -> void:
				var next: Variant = Chest.sell(_chest(), pid)
				if next != null:
					_save(Chest.CHEST_KEY, next)
					Sound.play("confirm")
				shop("sell"))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_v.add_child(b)
	_leave_button()
	_focus_first()


# --- Tavern ---------------------------------------------------------------------------------------

func tavern() -> void:
	_page(Texts.t("Taverna", "Tavern"))
	_gold_line()
	_said = ""
	var g := Party.parse_group(Store.json(Party.GROUP_KEY))
	_v.add_child(Kit.label(Texts.t("Recrutar custa %d de ouro. Grupo: %d de %d.", "A recruit costs %d gold. Party: %d of %d.") % [Party.RECRUIT_COST, g.members.size(), Party.GROUP_MAX], 15, Kit.MUTED))
	for cls in Party.jobs():
		var c: String = cls
		var d: Dictionary = Content.units[c]
		var b := Kit.button("%s · %s %d · %s\n   %s" % [Texts.unit_name(c), Texts.t("vida", "HP"), d.hp, Texts.t("movimento %d", "move %d") % d.move, ", ".join(d.abilities.map(func(a: String) -> String: return Texts.ability_name(a)))], func() -> void:
			var r: Variant = Party.recruit(Party.parse_group(Store.json(Party.GROUP_KEY)), _chest(), c)
			if r == null:
				Sound.play("cancel")
				_said = Texts.t("Não deu: falta ouro ou o grupo está cheio.", "Not possible: short of gold or the party is full.")
			else:
				_save(Party.GROUP_KEY, r.group)
				_save(Chest.CHEST_KEY, r.chest)
				Sound.play("confirm")
				_said = Texts.t("%s entrou no grupo.", "%s joined the party.") % r.group.members.back().name
			var said := _said
			tavern()
			_said = said
			_v.get_child(2).text = said)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_v.add_child(b)
	_leave_button()
	_focus_first()


# --- Party (the Guild) ----------------------------------------------------------------------------

func party() -> void:
	_page(Texts.t("Grupo", "Party"))
	_gold_line()
	var g := Party.parse_group(Store.json(Party.GROUP_KEY))
	var eq := _equip()
	for m in Party.roster(g):
		var goes: bool = g.deployed.has(m.id)
		var def := Equipment.with_gear(Content.units[m.cls], eq.get(m.id, {}))
		var id: String = m.id
		var b := Kit.button("%s · %s · %s\n   %s %d · %s" % [m.name, Texts.unit_name(m.cls), Texts.t("Vai à batalha", "Goes to battle") if goes else Texts.t("Fica na cidade", "Stays in town"), Texts.t("Vida", "HP"), def.hp, Texts.t("movimento %d", "move %d") % def.move], func() -> void: member(id))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_v.add_child(b)
	_leave_button()
	_focus_first()


func member(id: String, said: String = "") -> void:
	var g := Party.parse_group(Store.json(Party.GROUP_KEY))
	var m := Party.member(g, id)
	if m.is_empty():
		party()
		return
	var eq := _equip()
	var load: Dictionary = eq.get(id, {})
	_page("%s · %s" % [m.name, Texts.unit_name(m.cls)])
	if said != "":
		_v.add_child(Kit.label(said, 15, Kit.HERO))
	var def := Equipment.with_gear(Content.units[m.cls], load)
	var lines: Array = ["%s %d · %s %d · %s %d · %s %d" % [Texts.t("Vida", "HP"), def.hp, Texts.t("Velocidade", "Speed"), def.speed, Texts.t("Movimento", "Move"), def.move, Texts.t("Salto", "Jump"), def.get("jump", Pathing.MAX_JUMP)]]
	for r in Texts.attr_rows(def):
		lines.append("%s: %s" % [r[0], r[1]])
	for k in Content.RESOURCES:
		if def.get("vars", {}).get(k, 0):
			lines.append("%s %d (+%d %s)" % ["Mana" if k == "mana" else "Stamina", def.vars[k], def.get("regen", {}).get(k, 0), Texts.t("por turno", "per turn")])
	_v.add_child(Kit.label("\n".join(lines), 15))
	var goes: bool = g.deployed.has(id)
	_v.add_child(Kit.button(Texts.t("Deixar na cidade", "Leave in town") if goes else Texts.t("Levar à batalha", "Take to battle"), func() -> void:
		var next: Variant = Party.toggle_deploy(Party.parse_group(Store.json(Party.GROUP_KEY)), id)
		if next == null:
			Sound.play("cancel")
			member(id, Texts.t("Vão de 1 a %d à batalha.", "From 1 to %d go to battle.") % Party.DEPLOY_MAX)
			return
		_save(Party.GROUP_KEY, next)
		Sound.play("confirm")
		member(id)))
	_v.add_child(Kit.label(Texts.t("Classe", "Class"), 18, Kit.ACCENT))
	var classes := HBoxContainer.new()
	for cls in Party.jobs():
		var c: String = cls
		var b := Kit.button(Texts.unit_name(c) + (" ✓" if c == m.cls else ""), func() -> void:
			_save(Party.GROUP_KEY, Party.change_class(Party.parse_group(Store.json(Party.GROUP_KEY)), id, c))
			Sound.play("confirm")
			member(id))
		classes.add_child(b)
	_v.add_child(classes)
	_v.add_child(Kit.label(Texts.t("Habilidades", "Abilities"), 18, Kit.ACCENT))
	for a in Content.units[m.cls].abilities:
		_v.add_child(Kit.label("%s: %s" % [Texts.ability_name(a), Texts.ability_detail(a)], 14))
	_v.add_child(Kit.label(Texts.t("Equipamento", "Equipment"), 18, Kit.ACCENT))
	for s in Equipment.SLOTS:
		var slot: String = s
		var worn := Equipment.worn(load, slot)
		var b := Kit.button("%s: %s" % [slot_name(slot), Texts.t(worn.name, worn.en) + " · " + item_stats(worn.id) if not worn.is_empty() else Texts.t("vazio", "empty")], func() -> void: _pick_piece(id, slot))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_v.add_child(b)
	if m.recruit:
		_v.add_child(Kit.button(Texts.t("Dispensar", "Dismiss"), func() -> void:
			Kit.dialog(self, Texts.t("Confirmar: dispensar %s?", "Confirm: dismiss %s?") % m.name, Texts.t("O equipamento volta ao baú.", "The equipment goes back to the chest."), [
				[Texts.t("Dispensar", "Dismiss"), func() -> void:
					var r: Variant = Party.dismiss(Party.parse_group(Store.json(Party.GROUP_KEY)), _equip(), _chest(), id)
					if r == null:
						member(id, Texts.t("O baú está cheio.", "The chest is full."))
						return
					_save(Party.GROUP_KEY, r.group)
					_save(Chest.EQUIP_KEY, r.eq)
					_save(Chest.CHEST_KEY, r.chest)
					party()],
				[Texts.t("Cancelar", "Cancel"), func() -> void: member(id)],
			])))
	_v.add_child(Kit.button(Texts.t("Voltar à lista", "Back to the list"), party))
	_focus_first()


func _pick_piece(id: String, slot: String) -> void:
	var load: Dictionary = _equip().get(id, {})
	var m := Party.member(Party.parse_group(Store.json(Party.GROUP_KEY)), id)
	_page("%s · %s" % [m.name, slot_name(slot)])
	var worn := Equipment.worn(load, slot)
	if not worn.is_empty():
		_v.add_child(Kit.button(Texts.t("Tirar %s", "Take off %s") % Texts.t(worn.name, worn.en), func() -> void: _equip_piece(id, slot, "")))
	var seen := {}
	for it_id in _chest().items:
		var it: Dictionary = Content.items[it_id]
		if it.kind != Equipment.kind_of(slot) or seen.has(it_id):
			continue
		seen[it_id] = true
		var pid: String = it_id
		var next_def := Equipment.with_gear(Content.units[m.cls], load.merged({slot: pid}, true))
		var b := Kit.button("%s · %s\n   %s · %s %d → %d" % [Texts.t(it.name, it.en), rarity(it.rarity), item_stats(pid), Texts.t("vida", "HP"), Equipment.with_gear(Content.units[m.cls], load).hp, next_def.hp], func() -> void: _equip_piece(id, slot, pid))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_v.add_child(b)
	if seen.is_empty() and worn.is_empty():
		_v.add_child(Kit.label(Texts.t("Nenhuma peça deste tipo no baú. A Loja vende.", "No piece of this kind in the chest. The Shop sells them."), 15, Kit.MUTED))
	_v.add_child(Kit.button(Texts.t("Voltar", "Back"), func() -> void: member(id)))
	_focus_first()


func _equip_piece(id: String, slot: String, piece: String) -> void:
	var r: Variant = Chest.equip(_chest(), _equip(), id, slot, piece)
	if r == null:
		Sound.play("cancel")
		member(id, Texts.t("O baú está cheio.", "The chest is full."))
		return
	_save(Chest.CHEST_KEY, r.chest)
	_save(Chest.EQUIP_KEY, r.eq)
	Sound.play("confirm")
	member(id)


# --- Gate (the quest) -----------------------------------------------------------------------------

func gate() -> void:
	_page(Texts.t("Portão da masmorra", "Dungeon gate"))
	var live: Variant = CrawlFlow.live_expedition()
	var r: Dictionary = Content.data.crawl.run
	_v.add_child(Kit.label(Texts.t("A masmorra tem %d andares; o chefe espera no fim. Ninguém desce sozinho.", "The dungeon has %d floors; the boss waits at the end. Nobody goes down alone.") % r.floors, 15))
	var g := Party.parse_group(Store.json(Party.GROUP_KEY))
	_v.add_child(Kit.label(Texts.t("Vão: %s", "Going: %s") % ", ".join(g.deployed.map(func(i: String) -> String: return Party.member(g, i).name)), 15, Kit.HERO))
	if live != null:
		_v.add_child(Kit.button(Texts.t("Continuar a expedição", "Continue the expedition"), func() -> void: main.expedition_map()))
	_v.add_child(Kit.button(Texts.t("Descer (nova expedição)", "Go down (new expedition)") if live == null else Texts.t("Nova expedição (a atual volta com todo o ouro)", "New expedition (the current one returns with all its gold)"), func() -> void:
		CrawlFlow.depart(randi() % 2147483647)
		main.expedition_map()))
	_leave_button(Texts.t("Voltar à rua", "Back to the street"))
	_focus_first()

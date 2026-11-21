class_name ExpeditionScreen
extends Control
## The expedition map (port of game/expedition-map.ts): the floor in view, the party's life, the rooms open now with
## the enemies inside, the chest off the path, the boss at the end, the gold found and the way back to town.

var main: Main
var exp: Dictionary


func _init(m: Main, e: Dictionary) -> void:
	main = m
	exp = e


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build()


func _build(said: String = "") -> void:
	for c in get_children():
		c.queue_free()
	var map := Expedition.map_of(exp.seed)
	var open := Expedition.open_nodes(map, exp.path)
	var floor: int = map[open[0]].floor if open.size() else 1
	var v := Kit.page(self, Texts.t("Expedição · andar %d de %d", "Expedition · floor %d of %d") % [floor, Expedition.run().floors], 720)
	if said != "":
		v.add_child(Kit.label(said, 16, Kit.HERO))
	var g := CrawlFlow.group()
	var party: Array = []
	for h in exp.party:
		var m := Party.member(g, h.id)
		party.append("%s %d/%d" % [m.get("name", h.id), h.hp, h.max] + (" · mana %d" % h.mana if h.has("mana") else ""))
	v.add_child(Kit.label(" · ".join(party), 15))
	v.add_child(Kit.label(Texts.t("Salas vencidas: %d · Ouro achado: %d", "Rooms cleared: %d · Gold found: %d") % [exp.path.size(), Expedition.descent_gold(exp)], 15, Kit.ACCENT))
	v.add_child(Kit.label(Texts.t("Para onde?", "Where to?"), 18, Kit.ACCENT))
	var first: Button
	for i in open:
		var n: Dictionary = map[i]
		var node: int = i
		var b: Button
		if n.chest:
			b = Kit.button(Texts.t("Baú fora do caminho", "Chest off the path"), func() -> void: _chest(node))
		else:
			b = Kit.button(_room_text(n), func() -> void: main.room(node))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(b)
		if first == null:
			first = b
	var back := Kit.button(Texts.t("Voltar à cidade (leva o ouro achado)", "Back to town (brings the gold found)"), func() -> void:
		# the web game says nothing here: the town's gold counter shows it
		CrawlFlow.retreat(exp)
		main.town())
	v.add_child(back)
	(first if first else back).call_deferred("grab_focus")


## "Sala · 2 Esqueleto, Bruto · 40 de ouro"; the boss says that beating it ends the expedition
func _room_text(n: Dictionary) -> String:
	var sc := CrawlFlow.room_scenario(n)
	var count := {}
	for s in sc.get("spawns", []):
		if s.team == "enemy":
			count[s.def] = count.get(s.def, 0) + 1
	var foes: Array = []
	for d in count:
		foes.append(("%d " % count[d] if count[d] > 1 else "") + Texts.unit_name(d))
	var head: String = Texts.t("Chefe", "Boss") if n.boss else Texts.t("Sala", "Room")
	var tail: String = Texts.t(" · vencê-lo encerra a expedição", " · beating it ends the expedition") if n.boss else ""
	# the range before the win, like the web game's goldRange: node_gold rolls inside it
	var lo := 0
	var hi := 0
	for e in CrawlGen.room_group(n.seed, {"depth": n.floor, "boss": n.boss}).group.enemies:
		if Content.data.crawl.gold.has(e):
			lo += Content.data.crawl.gold[e][0]
			hi += Content.data.crawl.gold[e][1]
	var gold: String = Texts.t("sem ouro", "no gold") if hi == 0 else (("%d" % lo if lo == hi else "%d–%d" % [lo, hi]) + Texts.t(" de ouro", " gold"))
	return "%s · %s · %s%s" % [head, ", ".join(foes), gold, tail]


func _chest(node: int) -> void:
	var map := Expedition.map_of(exp.seed)
	var next: Variant = CrawlFlow.take_chest(node)
	if next == null:
		Sound.play("cancel")
		return
	exp = next
	Sound.play("confirm")
	var item := Expedition.chest_item(map[node])
	var said := Texts.t("No baú: %d de ouro", "In the chest: %d gold") % Expedition.node_gold(map[node])
	if item != "":
		said += Texts.t(" e %s", " and %s") % Texts.item_name(item)
	_build(said + ".")

class_name MapFacts
## What the expedition map says about a place (port of the text half of game/expedition-map.ts, pure): its name, its
## enemies, what the party may do with it, its mark on the chart and the facts in the picked place's box.


static func group_of(n: Dictionary) -> Dictionary:
	return CrawlGen.room_group(n.seed, {"depth": n.floor, "boss": n.boss}).group


static func kind_of(n: Dictionary) -> String:
	return "chest" if n.chest else "boss" if n.boss else "room"


static func name_of(n: Dictionary) -> String:
	if n.chest:
		return Texts.t("Baú", "Chest")
	var name: Array = group_of(n).name
	return (Texts.t("Chefe: ", "Boss: ") if n.boss else "") + Texts.t(name[0], name[1])


## "Minion ×2 · Skeleton archer": two rooms of a row often share a group, so the box counts them out
static func foes_of(n: Dictionary) -> String:
	var all: Array = group_of(n).enemies
	var out: Array = []
	for e in all:
		var said := Texts.unit_name(e) + (" ×%d" % all.count(e) if all.count(e) > 1 else "")
		if not out.has(said):
			out.append(said)
	return " · ".join(out)


## what the party may do with a place, in words: in the box, on the help band and under Travel
static func word(n: Dictionary, state: String) -> String:
	match state:
		"cleared":
			return Texts.t("já aberto", "already opened") if n.chest else Texts.t("vencida", "cleared")
		"open":
			return Texts.t("ao alcance", "in reach") if n.chest else Texts.t("aberta", "open")
		"ahead":
			return Texts.t("abre depois da anterior", "opens after the one before")
	return Texts.t("caminho não tomado", "path not taken")


## the glyph on a place's seal: its state once closed, else its enemy count; "" where the kind has its own drawing
static func mark(n: Dictionary, state: String) -> String:
	if state == "cleared":
		return "✓"
	if state == "skipped":
		return "✕"
	return "" if n.chest or n.boss else str(group_of(n).enemies.size())


static func floor_text(floor: int) -> String:
	var all: int = Expedition.run().floors
	return Texts.t("andar %d de %d" % [floor, all], "floor %d of %d" % [floor, all])


## {name, floor, facts: [[label, value]]} of the place `node` in `state`; `here`: the last place cleared, or -1
static func facts_of(map: Array, node: int, state: String, here: int) -> Dictionary:
	var n: Dictionary = map[node]
	var gold := MapChart.gold_range(n)
	var lo := int(gold[0])
	var hi := int(gold[1])
	var foes: int = group_of(n).enemies.size()
	var way: Array = [word(n, state)]
	if node == here:
		way.append(Texts.t("o grupo está aqui", "the party is here"))
	if not n.chest and n.next.any(func(k: int) -> bool: return map[k].chest):
		way.append(Texts.t("leva ao baú", "leads to the chest"))
	if n.next.any(func(k: int) -> bool: return map[k].floor > n.floor):
		var heal := int(Expedition.run().floorHeal)
		way.append(Texts.t("vencê-la desce um andar: +%d%% de vida" % heal, "clearing it leads down a floor: +%d%% life" % heal))
	if n.boss:
		way.append(Texts.t("vencê-lo encerra a expedição", "beating it ends the expedition"))
	var reward: String
	if state == "cleared":
		var got := Expedition.node_gold(n)
		reward = Texts.t("%d de ouro, já achado" % got, "%d gold, already found" % got)
	elif hi == 0:
		reward = Texts.t("nenhum ouro", "no gold")
	elif lo == hi:
		reward = Texts.t("%d de ouro" % hi, "%d gold" % hi)
	else:
		reward = Texts.t("%d a %d de ouro" % [lo, hi], "%d to %d gold" % [lo, hi])
	return {
		"name": name_of(n),
		"floor": floor_text(n.floor),
		"facts": [
			[Texts.t("Batalha", "Battle") if n.chest else Texts.t("Inimigos (%d)" % foes, "Enemies (%d)" % foes), Texts.t("nenhuma: o grupo anda até o baú", "none: the party walks to the chest") if n.chest else foes_of(n)],
			[Texts.t("Recompensa", "Reward"), reward],
			[Texts.t("Caminho", "Way"), " · ".join(way)],
		],
	}

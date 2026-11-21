class_name HudBits
## The battle HUD's small pieces, like the web game's: thin gauges for life, mana, stamina and CT, a turn-list entry, the
## acting unit's card and the tile line under the cursor (port of tile-info.ts).

const HP := Color(0.45, 0.75, 0.3)
const MP := Color(0.85, 0.45, 0.35)
const ST := Color(0.9, 0.5, 0.4)
const CT := Color(0.85, 0.65, 0.2)
const MANA := Color(0.3, 0.55, 0.95)

const LOOK_NAME := {
	"grass": ["grama", "grass"], "stone": ["pedra", "stone"], "water": ["água", "water"], "bridge": ["ponte", "bridge"],
	"tree": ["árvore", "tree"], "rock": ["rocha", "rock"], "summit": ["topo de rocha", "rock top"], "sand": ["areia", "sand"],
	"gold": ["veio de ouro", "gold vein"], "brick": ["muro de tijolo", "brick wall"], "snow": ["neve", "snow"],
	"snow_rock": ["rocha com neve", "snowy rock"], "tree2": ["árvore", "tree"], "tree3": ["árvore", "tree"],
	"tree4": ["árvore", "tree"], "bare1": ["árvore seca", "bare tree"], "bare2": ["árvore seca", "bare tree"],
	"crypt": ["piso de pedra", "stone floor"], "altar": ["altar", "altar"], "pillar": ["coluna", "pillar"],
	"crates": ["caixotes", "crates"], "barrel": ["barril", "barrel"], "chest": ["baú", "chest"], "rubble": ["entulho", "rubble"],
	"spikes": ["armadilha de espinhos", "spike trap"], "boulder": ["rochedo", "boulder"], "corpse": ["corpo", "body"],
}
const TERRAIN_NAME := {"floor": ["chão", "ground"], "forest": ["árvore", "tree"], "rubble": ["entulho (cobertura)", "rubble (cover)"], "wall": ["muro", "wall"]}


static func bar(value: int, most: int, col: Color, width: float = 110.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = maxi(1, most)
	b.value = clampi(value, 0, maxi(1, most))
	b.custom_minimum_size = Vector2(width, 5)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	return b


## "HP 120/120 · MP 30/30" over its two gauges, then "ST 30/30 · CT 63/100" over theirs
static func _gauges(u: Dictionary, size: int, width: float) -> VBoxContainer:
	var def: Dictionary = Content.units[u.def]
	var mp_max: int = def.get("vars", {}).get("mana", 0)
	var st_max: int = def.get("vars", {}).get("stamina", 0)
	var rows := [
		[["HP", u.hp, def.hp, HP], ["MP", Combat.pool_of(u, "mana"), mp_max, MANA]],
		[["ST", Combat.pool_of(u, "stamina"), st_max, ST], ["CT", mini(u.ct, TurnQueue.THRESHOLD), TurnQueue.THRESHOLD, CT]],
	]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	for row in rows:
		var parts: Array = []
		var bars := HBoxContainer.new()
		for g in row:
			if g[2] <= 0:
				continue
			parts.append("%s %d/%d" % [g[0], g[1], g[2]])
			bars.add_child(bar(g[1], g[2], g[3], width))
		if parts.is_empty():
			continue
		v.add_child(Kit.label(" · ".join(parts), size))
		v.add_child(bars)
	return v


static func turn_entry(u: Dictionary, ability: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var col: Color = Kit.HERO if u.team == "hero" else Kit.FOE
	if ability != "":
		v.add_child(Kit.label("⏳ %s: %s" % [Texts.unit_name(u.def), Texts.ability_name(ability)], 14, col))
		return v
	v.add_child(Kit.label(Texts.unit_name(u.def), 15, col))
	v.add_child(_gauges(u, 12, 104.0))
	return v


static func card(parent: Control, u: Dictionary, turn: Dictionary) -> void:
	for c in parent.get_children():
		c.queue_free()
	var head := Texts.unit_name(u.def)
	var cls := Roster.class_of(u.def)
	parent.add_child(Kit.label(head, 20, Kit.HERO if u.team == "hero" else Kit.FOE))
	if cls != "" and Texts.unit_name(cls) != head:
		parent.add_child(Kit.label(Texts.unit_name(cls), 14, Kit.MUTED))
	parent.add_child(_gauges(u, 15, 140.0))
	var acts := Texts.t("principal ", "main ") + ("✗" if turn.main else "✓") + " · " + Texts.t("secundária ", "bonus ") + ("✗" if turn.bonus else "✓")
	parent.add_child(Kit.label(acts, 14, Kit.MUTED))


## the height the tile line shows: in shallow water the one a unit stands at (port of tileHeight)
static func tile_height(grid: Grid, p: Vector2i) -> int:
	var t := grid.tile(p)
	return Grid.stand_h(t) if t.get("depth", 0) == 1 else t.h


## "X 6 · Y 18 · Z 0 · topo de rocha" and what the tile does (port of tileInfo, without the charge warning)
static func tile_info(grid: Grid, p: Vector2i) -> String:
	var t := grid.tile(p)
	var look: String = t.get("look", "")
	var nm: Array = LOOK_NAME.get(look, [look, look]) if look != "" else TERRAIN_NAME[t.terrain]
	var extra := ""
	if not Grid.TERRAIN[t.terrain].walkable:
		extra += Texts.t(" · não dá para pisar", " · not walkable")
	var depth: int = t.get("depth", 0)
	if depth >= 2:
		extra += Texts.t(" · funda: não se age nela", " · deep: no actions inside")
	elif depth == 1:
		extra += Texts.t(" · rasa", " · shallow")
	if t.get("spikes", false):
		extra += Texts.t(" · espinhos: −%d ao terminar a vez ou ser empurrado aqui", " · spikes: −%d when ending a turn or pushed here") % Combat.SPIKE_DAMAGE
	var ramp: String = Texts.t(" (rampa)", " (ramp)") if t.get("ramp") else ""
	return "X %d · Y %d · Z %d%s · %s%s" % [p.x, p.y, tile_height(grid, p), ramp, Texts.t(nm[0], nm[1]), extra]

class_name HudBits
## The tile line under the cursor (port of tile-info.ts): the tile's height and what it is, for the Height corner.

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

class_name Looks
## What each tile look (Tile.look) draws (port of the parts of board-looks.ts and terrain.ts the port uses): the ground
## paint of the smooth terrain, which looks carry an object on top, and which walls the terrain draws as a stone hill.

## paint of each look: grass, leaves, dirt, snow, stone (stone also shows by itself on slopes)
const PAINT := {
	"grass": [1, 0, 0, 0, 0], "tree": [0.5, 0.5, 0, 0, 0], "tree2": [0.6, 0.4, 0, 0, 0], "tree3": [0.6, 0.4, 0, 0, 0],
	"tree4": [0.6, 0.4, 0, 0, 0], "sand": [0.15, 0, 0.85, 0, 0], "water": [0, 0, 1, 0, 0], "crates": [0, 0, 1, 0, 0],
	"barrel": [0, 0, 1, 0, 0], "corpse": [0.2, 0, 0.8, 0, 0], "snow": [0, 0, 0.3, 0.7, 0], "snow_rock": [0, 0, 0, 0.8, 0.2],
	"bare1": [0, 0, 0.3, 0.7, 0], "bare2": [0, 0, 0.3, 0.7, 0], "rock": [0, 0, 0, 0, 1], "summit": [0, 0, 0, 0, 1],
	"gold": [0, 0, 0.3, 0, 0.7], "stone": [0, 0, 0.4, 0, 0.6],
	# crawl caves: the dungeon pieces on the stone floor
	"rubble": [0, 0, 0.4, 0, 0.6], "spikes": [0, 0, 0.4, 0, 0.6], "boulder": [0, 0, 0.4, 0, 0.6],
	# the walkable town: trodden earth under the houses and their lots
	"lot": [0.2, 0, 0.8, 0, 0], "guild": [0.2, 0, 0.8, 0, 0], "shop": [0.2, 0, 0.8, 0, 0], "tavern": [0.2, 0, 0.8, 0, 0],
	"smithy": [0.2, 0, 0.8, 0, 0], "enchanter": [0.2, 0, 0.8, 0, 0], "gate": [0.2, 0, 0.8, 0, 0], "home": [0.2, 0, 0.8, 0, 0],
	"well": [0, 0, 0.4, 0, 0.6],
}
## looks with an object on the tile (a tree, a crate, a house): the object blocks, the tile stays at ground level
const PROP := ["tree", "tree2", "tree3", "tree4", "bare1", "bare2", "pillar", "crates", "barrel", "chest", "rubble",
	"spikes", "boulder", "guild", "shop", "tavern", "smithy", "enchanter", "gate", "home", "well"]
## walls without an object that the smooth terrain draws as a stone hill (brick stays a block: it is construction)
const MOUND := ["rock", "snow_rock", "summit", "snow"]
## the crypt floors: those maps keep the blocks (the web loads no terrain textures for them)
const CRYPT := ["crypt", "altar"]


## the smooth terrain draws this tile (a paintable look, or a wall that is a hill, a body or a lot)
static func ground(t: Dictionary) -> bool:
	var look: String = t.get("look", "")
	if look == "" or not PAINT.has(look):
		return false
	return t.terrain != "wall" or PROP.has(look) or MOUND.has(look) or look == "corpse" or look == "lot"


## a wall the terrain raises as a stone hill two levels above the tile
static func rock(t: Dictionary) -> bool:
	var look: String = t.get("look", "")
	return t.terrain == "wall" and not PROP.has(look) and MOUND.has(look)


## the map gets the smooth painted terrain: it has per-tile looks and is not a crypt (load.ts)
static func smooth(g: Grid) -> bool:
	var any := false
	for t in g.tiles:
		var look: String = t.get("look", "")
		if CRYPT.has(look):
			return false
		any = any or look != ""
	return any

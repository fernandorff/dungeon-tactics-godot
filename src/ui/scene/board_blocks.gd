class_name BoardBlocks
## The plain block board for the maps the painted terrain does not cover (the 8x8 skirmish without looks): one box per
## cell at its height, coloured by look, with a checker so the cells read apart. Boxes of one size and colour share their
## mesh and material.

const LOOK_COLORS := {
	"grass": Color(0.36, 0.55, 0.28), "snow": Color(0.88, 0.9, 0.95), "snow_rock": Color(0.7, 0.72, 0.78),
	"rock": Color(0.42, 0.4, 0.38), "summit": Color(0.55, 0.52, 0.47), "sand": Color(0.8, 0.72, 0.5),
	"gold": Color(0.85, 0.7, 0.25), "altar": Color(0.7, 0.65, 0.8), "crypt": Color(0.35, 0.34, 0.4),
	"stone": Color(0.47, 0.47, 0.5), "spikes": Color(0.55, 0.2, 0.2), "water": Color(0.2, 0.4, 0.7),
	"bridge": Color(0.55, 0.4, 0.25), "corpse": Color(0.45, 0.35, 0.3), "brick": Color(0.5, 0.3, 0.25),
	"chest": Color(0.6, 0.45, 0.2), "pillar": Color(0.6, 0.6, 0.62), "crates": Color(0.6, 0.45, 0.28),
	"barrel": Color(0.5, 0.33, 0.2), "boulder": Color(0.38, 0.37, 0.36), "rubble": Color(0.5, 0.45, 0.38),
}

static var _mats := {}
static var _meshes := {}


static func build(space: TileSpace, into: Node3D) -> void:
	var g := space.grid
	for y in g.height:
		for x in g.width:
			_tile(space, Vector2i(x, y), into)


static func _tile(space: TileSpace, p: Vector2i, into: Node3D) -> void:
	var t := space.grid.tile(p)
	var h: float = (t.h + 1) * space.step
	var col: Color = LOOK_COLORS.get(t.get("look", ""), Color(0.45, 0.45, 0.45))
	if t.terrain == "floor" and not t.has("look"):
		col = Color(0.45, 0.5, 0.42)
	# a checker so the cells read apart; a whole tile (2x2 cells) keeps one shade
	var sub := maxi(1, space.grid.sub)
	if ((p.x / sub) + (p.y / sub)) % 2 == 0:
		col = col.darkened(0.08)
	_box(into, Vector3(p.x + 0.5, h / 2.0, p.y + 0.5), Vector3(0.98, h, 0.98), col)
	if t.get("depth", 0):
		var w: float = t.depth * space.step * 0.5
		_box(into, Vector3(p.x + 0.5, h + w / 2.0, p.y + 0.5), Vector3(1.0, w, 1.0), Color(0.2, 0.45, 0.85, 0.55))
	var blocks := Grid.blocks_of(t)
	if t.terrain == "wall" or t.terrain == "forest" or t.terrain == "rubble":
		var tall: float = blocks * space.step * 0.5
		var c2: Color = col.darkened(0.25) if t.terrain != "forest" else Color(0.2, 0.42, 0.2)
		var w2 := 0.9 if t.terrain == "wall" else 0.7
		_box(into, Vector3(p.x + 0.5, h + tall / 2.0, p.y + 0.5), Vector3(w2, tall, w2), c2)


static func _box(into: Node3D, at: Vector3, size: Vector3, col: Color) -> void:
	if not _meshes.has(size):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[size] = bm
	var k := col.to_html()
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		if col.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[k] = m
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[size]
	mi.material_override = _mats[k]
	mi.position = at
	into.add_child(mi)

class_name BoardTrees
## Places painted tree meshes using the grouping and position draws in scene/tree-crowns.ts.

const MODELS := {
	"tree": "forest/Tree_1_A_Color1", "tree2": "forest/Tree_2_A_Color1",
	"tree3": "forest/Tree_3_A_Color1", "tree4": "forest/Tree_4_A_Color1",
	"bare1": "forest/Tree_Bare_1_A_Color1", "bare2": "forest/Tree_Bare_2_A_Color1",
}
const SIZE := {1: Vector2(2.4, 1.9), 2: Vector2(2.8, 2.3), 4: Vector2(3.4, 2.9)}


static func _draw(p: Vector2i, salt: int) -> float:
	var v := sin(p.x * 127.1 + p.y * 311.7 + salt * 74.7) * 43758.5453
	return v - floorf(v)


static func _free(g: Grid, p: Vector2i, h: int, taken: Dictionary) -> bool:
	if not g.in_bounds(p) or taken.has(p):
		return false
	var t := g.tile(p)
	return t.terrain == "forest" and t.h == h


static func _group(g: Grid, p: Vector2i, h: int, taken: Dictionary) -> Array[Vector2i]:
	var right := _free(g, p + Vector2i.RIGHT, h, taken)
	var down := _free(g, p + Vector2i.DOWN, h, taken)
	if right and down and _free(g, p + Vector2i.ONE, h, taken):
		return [p, p + Vector2i.RIGHT, p + Vector2i.DOWN, p + Vector2i.ONE]
	if right:
		return [p, p + Vector2i.RIGHT]
	if down:
		return [p, p + Vector2i.DOWN]
	return [p]


static func build(space: TileSpace, parent: Node3D) -> ShaderMaterial:
	var g := space.grid
	var crowns: ShaderMaterial
	var taken: Dictionary = {}
	var models: Dictionary = {}
	for i in g.tiles.size():
		var p := Vector2i(i % g.width, i / g.width)
		if taken.has(p):
			continue
		var t := g.tile(p)
		var model: String = MODELS.get(t.get("look", ""), "")
		var span: int = t.get("span", 1)
		var tree: int = t.get("tree", 0)
		var pos := space.world(p)
		var scale_factor: float
		var piece: Dictionary
		var yaw := 0.0
		if tree > 0 and model != "":
			for cell: Vector2i in Pathing.cells_of(p, tree):
				taken[cell] = true
			piece = _model(models, model)[0]
			scale_factor = minf(tree * (1.0 + 0.5 * _draw(p, 4)), tree * 0.95 / piece.box.size.x)
			pos += Vector3(1, 0, 1) * ((tree - 1) * 0.5)
			yaw = _draw(p, 2) * TAU
		elif t.terrain == "forest":
			var cells := _group(g, p, t.h, taken)
			var widest := -1.0
			pos = Vector3.ZERO
			for cell in cells:
				pos += space.world(cell)
				taken[cell] = true
				var name: String = MODELS.get(g.tile(cell).get("look", ""), "")
				if name != "":
					var width: float = _model(models, name)[0].box.size.x
					if width > widest:
						widest = width
						model = name
			if model.is_empty():
				continue
			var choices := _model(models, model)
			piece = choices[floori(_draw(p, 16) * choices.size())]
			var limits: Vector2 = SIZE[cells.size()]
			scale_factor = minf(limits.x * piece.get("tall", 1.0), limits.y / piece.box.size.x)
			scale_factor = minf(scale_factor * (0.75 + 0.6 * _draw(p, 1)), 0.4 * sqrt(cells.size()) / maxf(0.01, piece.foot))
			pos /= cells.size()
			yaw = _draw(p, 2) * TAU
		elif model != "" and span > 0:
			var choices := _model(models, model)
			piece = choices[floori(_draw(p, 6) * choices.size())]
			scale_factor = span * 1.1
			pos += Vector3(1, 0, 1) * ((span - 1) * 0.5)
			if t.terrain == "wall" and t.get("look") == "tree":
				var low := INF
				for cell in g.neighbors(p):
					low = minf(low, g.tile(cell).h)
				if is_finite(low):
					pos.y = (low + 1) * space.step
		else:
			continue
		var instance := MeshInstance3D.new()
		instance.mesh = piece.mesh
		if tree > 0 or t.terrain == "forest":
			if crowns == null:
				crowns = ShaderMaterial.new()
				crowns.shader = preload("res://src/ui/scene/tree_cuts.gdshader")
				crowns.set_shader_parameter("paint", Painted.material().albedo_texture)
			instance.material_override = crowns
		instance.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_factor), pos)
		parent.add_child(instance)
	return crowns


static func _model(models: Dictionary, name: String) -> Array:
	if not models.has(name):
		models[name] = Trees.variations(name)
	return models[name]

class_name BattleView
extends Node3D
## The battle in simple 3D: each cell a box at its height, each unit a capsule with its facing and a life label, the
## marks as thin plates on the tiles, an orbit camera that turns in steps of 90° (like FFT) and picks the cell under the
## mouse. Only draws: the battle screen says what to show.

const MARK_COLORS := {
	"actor": Color(1.0, 0.85, 0.2, 0.75), "move": Color(0.25, 0.55, 1.0, 0.55), "range": Color(0.95, 0.55, 0.15, 0.45),
	"threat": Color(0.9, 0.2, 0.2, 0.4), "area": Color(1.0, 0.35, 0.2, 0.6), "target": Color(1.0, 0.2, 0.2, 0.8),
	"nogo": Color(0.4, 0.4, 0.4, 0.7), "counter": Color(0.85, 0.1, 0.5, 0.6), "charge": Color(0.6, 0.25, 0.9, 0.5),
	"path": Color(1, 1, 1, 0.7), "cursor": Color(1, 1, 1, 0.9),
}
const LOOK_COLORS := {
	"grass": Color(0.36, 0.55, 0.28), "snow": Color(0.88, 0.9, 0.95), "snow_rock": Color(0.7, 0.72, 0.78),
	"rock": Color(0.42, 0.4, 0.38), "summit": Color(0.55, 0.52, 0.47), "sand": Color(0.8, 0.72, 0.5),
	"gold": Color(0.85, 0.7, 0.25), "altar": Color(0.7, 0.65, 0.8), "crypt": Color(0.35, 0.34, 0.4),
	"stone": Color(0.47, 0.47, 0.5), "spikes": Color(0.55, 0.2, 0.2), "water": Color(0.2, 0.4, 0.7),
	"bridge": Color(0.55, 0.4, 0.25), "corpse": Color(0.45, 0.35, 0.3), "brick": Color(0.5, 0.3, 0.25),
	"chest": Color(0.6, 0.45, 0.2), "pillar": Color(0.6, 0.6, 0.62), "crates": Color(0.6, 0.45, 0.28),
	"barrel": Color(0.5, 0.33, 0.2), "boulder": Color(0.38, 0.37, 0.36), "rubble": Color(0.5, 0.45, 0.38),
}

var grid: Grid
var camera: Camera3D
var heading := 0 # 0..3: quarter turns of the camera
var zoom := 1.0
var _focus := Vector3.ZERO
var _yaw := 45.0
var _tiles: Node3D
var _marks: Node3D
var _rings: Node3D
var _units := {} # unit id → Node3D
var _mats := {}
var _plates := {} # plate width → its mesh
var _float: Node3D
var names := {} # unit id → a label in place of name and life (the town's people)


func build(g: Grid, state: Dictionary) -> void:
	grid = g
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.08, 0.09, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.65)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 35
	add_child(camera)
	_tiles = Node3D.new()
	add_child(_tiles)
	_marks = Node3D.new()
	add_child(_marks)
	_rings = Node3D.new()
	add_child(_rings)
	_float = Node3D.new()
	add_child(_float)
	for y in g.height:
		for x in g.width:
			_tile_box(Vector2i(x, y))
	sync_units(state)
	_focus = Vector3(g.width / 2.0, 0, g.height / 2.0)
	_place_camera()


func _mat(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		if c.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats[k] = m
	return _mats[k]


func level() -> float:
	return grid.level_height if grid.level_height > 0 else 0.5


## the top of a cell where a unit stands
func top_of(p: Vector2i) -> float:
	var t := grid.tile(p)
	return maxf(0.0, t.h * level()) + 0.1


func cell_center(p: Vector2i, size: int = 1) -> Vector3:
	return Vector3(p.x + size / 2.0, top_of(p), p.y + size / 2.0)


func _tile_box(p: Vector2i) -> void:
	var t := grid.tile(p)
	var h := maxf(0.0, t.h * level()) + 0.1
	var col: Color = LOOK_COLORS.get(t.get("look", ""), Color(0.45, 0.45, 0.45))
	if t.terrain == "floor" and not t.has("look"):
		col = Color(0.45, 0.5, 0.42)
	# a checker so the cells read apart; a whole tile (2x2 cells) keeps one shade
	var sub := maxi(1, grid.sub)
	if ((p.x / sub) + (p.y / sub)) % 2 == 0:
		col = col.darkened(0.08)
	_box(Vector3(p.x + 0.5, h / 2.0, p.y + 0.5), Vector3(0.98, h, 0.98), col)
	if t.get("depth", 0):
		var w: float = t.depth * level() * 0.5
		_box(Vector3(p.x + 0.5, h + w / 2.0, p.y + 0.5), Vector3(1.0, w, 1.0), Color(0.2, 0.45, 0.85, 0.55))
	var blocks := Grid.blocks_of(t)
	if t.terrain == "wall" or t.terrain == "forest" or t.terrain == "rubble":
		var tall: float = blocks * level() * 0.5
		var c2: Color = col.darkened(0.25) if t.terrain != "forest" else Color(0.2, 0.42, 0.2)
		var w2 := 0.9 if t.terrain == "wall" else 0.7
		_box(Vector3(p.x + 0.5, h + tall / 2.0, p.y + 0.5), Vector3(w2, tall, w2), c2)
	if t.get("spikes", false):
		_box(Vector3(p.x + 0.5, h + 0.12, p.y + 0.5), Vector3(0.5, 0.25, 0.5), Color(0.75, 0.75, 0.8))


func _box(at: Vector3, size: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col)
	mi.position = at
	_tiles.add_child(mi)


func _team_color(u: Dictionary) -> Color:
	if Content.is_objective(u.def):
		return Color(1.0, 0.85, 0.3)
	return Color(0.25, 0.5, 0.95) if u.team == "hero" else Color(0.85, 0.25, 0.22)


func _unit_node(u: Dictionary) -> Node3D:
	var n := Node3D.new()
	var size: int = Content.units[u.def].get("size", 1)
	var r := 0.3 * size
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = r
	cap.height = maxf(2.0 * r + 0.2, 0.9 * size)
	body.mesh = cap
	body.material_override = _mat(_team_color(u))
	body.position.y = cap.height / 2.0
	n.add_child(body)
	# the facing: a small nose on the front
	var nose := MeshInstance3D.new()
	var nb := BoxMesh.new()
	nb.size = Vector3(0.18 * size, 0.18 * size, 0.25 * size)
	nose.mesh = nb
	nose.material_override = _mat(Color(0.95, 0.95, 0.9))
	nose.position = Vector3(0, cap.height * 0.7, r)
	nose.name = "Nose"
	n.add_child(nose)
	var label := Label3D.new()
	label.name = "Label"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 36
	label.pixel_size = 0.006
	label.outline_size = 8
	label.position.y = cap.height + 0.35
	n.add_child(label)
	n.set_meta("size", size)
	n.set_meta("height", cap.height)
	n.set_meta("def", u.def)
	return n


## the units as the state has them: new ones appear, the fallen leave, the rest move to their tiles
func sync_units(state: Dictionary) -> void:
	var alive := {}
	for u in state.units:
		alive[u.id] = true
		if not _units.has(u.id):
			_units[u.id] = _unit_node(u)
			add_child(_units[u.id])
		var n: Node3D = _units[u.id]
		n.position = cell_center(u.pos, n.get_meta("size"))
		n.rotation.y = _facing_yaw(u.get("facing", 0))
		var def: Dictionary = Content.units[u.def]
		var lbl: Label3D = n.get_node("Label")
		lbl.text = names[u.id] if names.has(u.id) else "%s %d/%d" % [Texts.unit_name(u.def), u.hp, def.hp]
		lbl.modulate = _team_color(u).lightened(0.4)
	for id in _units.keys():
		if not alive.has(id):
			_units[id].queue_free()
			_units.erase(id)


func _facing_yaw(f: int) -> float:
	# FACING: +y, +x, -y, -x; the nose points down +z at yaw 0
	return [0.0, PI / 2, PI, -PI / 2][f]


## a walk along cells, tweened
func walk(unit: String, path: Array, speed: float = 0.09) -> void:
	if not _units.has(unit) or path.is_empty():
		return
	var n: Node3D = _units[unit]
	var size: int = n.get_meta("size")
	var tw := create_tween()
	for i in path.size():
		var p: Vector2i = path[i]
		if i > 0:
			var d: Vector2i = p - path[i - 1]
			var f := Grid.FACING.find(Vector2i(signi(d.x), signi(d.y)))
			if f >= 0:
				tw.tween_callback(func() -> void: n.rotation.y = _facing_yaw(f))
		tw.tween_property(n, "position", cell_center(p, size), speed)
	await tw.finished


## a floating number or word over a unit's chest (port of float-numbers.ts): `px` is its height in screen px at 1080p,
## whatever the zoom, as the web's are; a strong strike gets the gold edge. It pops, holds to be read and fades in 1.5 s
func float_text(unit: String, text: String, col: Color, px: int = 26, strong: bool = false) -> void:
	if not _units.has(unit):
		return
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	# fixed size: as seen from 1 m, where the 35° view is 0.63 m tall; px * 2 * 0.0003 gives px at 1080p on any window
	l.fixed_size = true
	l.font_size = px * 2
	l.pixel_size = 0.0003
	l.outline_size = 16 if strong else 10
	l.outline_modulate = Color("#ffc531") if strong else Color.BLACK
	l.modulate = col
	var n: Node3D = _units[unit]
	l.position = n.position + Vector3(0, 0.7 * n.get_meta("height") + 0.3, 0)
	_float.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y + 0.5, 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.4).set_delay(1.1)
	tw.tween_callback(l.queue_free)


## the sheet a unit on the board uses ("" for none), read while its node is still there (a fallen one until the sync)
func def_of(unit: String) -> String:
	return _units[unit].get_meta("def") if _units.has(unit) else ""


## the events in order: walks tweened, numbers and words floating (battle_events.gd)
func play_events(events: Array) -> void:
	await BattleEvents.play(self, events)


## the marks: [{pos, kind}] plus an optional path and the cursor cell
func show_marks(tiles: Array, path: Variant = null, cursor: Variant = null, size: int = 1) -> void:
	for c in _marks.get_children():
		c.queue_free()
	var seen := {}
	for m in tiles:
		seen[m.pos] = m.kind # later marks win, as the web game's map
	for p in seen:
		_plate(p, MARK_COLORS.get(seen[p], Color(1, 1, 1, 0.4)), 0.92, 0.04)
	if path != null:
		for p in path:
			_plate(p, MARK_COLORS.path, 0.35, 0.07)
	if cursor != null:
		for c in Pathing.cells_of(cursor, size):
			if grid.in_bounds(c):
				_plate(c, MARK_COLORS.cursor, 0.5, 0.09)


## the dotted outlines: {range?: cells, walk?: cells} (Rings.of_screen); {} clears them
func show_rings(r: Dictionary) -> void:
	for c in _rings.get_children():
		c.queue_free()
	if not r.get("range", {}).is_empty():
		_rings.add_child(Rings.outline(self, r.range, Rings.RANGE))
	if not r.get("walk", {}).is_empty():
		_rings.add_child(Rings.outline(self, r.walk, Rings.WALK))


func _plate(p: Vector2i, col: Color, w: float, lift: float) -> void:
	if not grid.in_bounds(p):
		return
	# one shared plate mesh per width: the marks are rebuilt on every cursor step
	if not _plates.has(w):
		var bm := BoxMesh.new()
		bm.size = Vector3(w, 0.03, w)
		_plates[w] = bm
	var mi := MeshInstance3D.new()
	mi.mesh = _plates[w]
	mi.material_override = _mat(col)
	mi.position = Vector3(p.x + 0.5, top_of(p) + lift, p.y + 0.5)
	_marks.add_child(mi)


## a unit off the cell grid: the town's walker at a free point, facing `dir` on the ground
func place_free(unit: String, at: Vector2, dir: Vector2) -> void:
	if not _units.has(unit):
		return
	var n: Node3D = _units[unit]
	n.position = Vector3(at.x, top_of(TownMap.cell_under(at)), at.y)
	if dir != Vector2.ZERO:
		n.rotation.y = atan2(dir.x, dir.y)
	_focus = Vector3(at.x, 0, at.y)


func yaw() -> float:
	return deg_to_rad(_yaw)


func focus_on(p: Vector2i) -> void:
	_focus = Vector3(p.x + 0.5, top_of(p), p.y + 0.5)


func turn(dir: int) -> void:
	heading = (heading + dir + 4) % 4
	_yaw = 45.0 + 90.0 * heading


func zoom_by(f: float) -> void:
	zoom = clampf(zoom * f, 0.45, 2.2)


func _process(delta: float) -> void:
	_place_camera(minf(1.0, delta * 6.0))


func _place_camera(weight: float = 1.0) -> void:
	if camera == null:
		return
	var dist := 30.0 * zoom * (grid.width / 24.0 if grid.width > 0 else 1.0)
	var yaw := deg_to_rad(_yaw)
	var want := _focus + Vector3(sin(yaw), 0, cos(yaw)) * dist * 0.75 + Vector3(0, dist * 0.68, 0)
	camera.position = camera.position.lerp(want, weight)
	camera.look_at(camera.position + (_focus - want).normalized(), Vector3.UP)


## an arrow key in screen terms → a grid step, as the camera sees it
func grid_step(dir: String) -> Vector2i:
	var screen: int = {"up": 0, "right": 1, "down": 2, "left": 3}[dir]
	# heading 0 looks from +x+z towards -x-z: screen up is -y
	var steps: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	return steps[(screen + heading) % 4]


## the cell under a screen point; null off the map
func pick(screen_pos: Vector2) -> Variant:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var best := INF
	var hit: Variant = null
	for y in grid.height:
		for x in grid.width:
			var top := top_of(Vector2i(x, y))
			var t := _ray_box(from, dir, Vector3(x, 0, y), Vector3(x + 1, top, y + 1))
			if t >= 0.0 and t < best:
				best = t
				hit = Vector2i(x, y)
	return hit


func _ray_box(o: Vector3, d: Vector3, lo: Vector3, hi: Vector3) -> float:
	var tmin := -INF
	var tmax := INF
	for i in 3:
		if absf(d[i]) < 1e-8:
			if o[i] < lo[i] or o[i] > hi[i]:
				return -1.0
			continue
		var t1 := (lo[i] - o[i]) / d[i]
		var t2 := (hi[i] - o[i]) / d[i]
		tmin = maxf(tmin, minf(t1, t2))
		tmax = minf(tmax, maxf(t1, t2))
	return tmin if tmax >= maxf(tmin, 0.0) else -1.0


## where a cell is on screen, for the arrows that walk what is seen
func screen_at(p: Vector2i) -> Vector2:
	return camera.unproject_position(Vector3(p.x + 0.5, top_of(p), p.y + 0.5))

class_name Painted
## Painted pieces built in code (port of painted.ts; Fernando, Nov 13: Ash Wood "FFT-like"): trees and objects share one
## material, the colour painted vertex by vertex in tone masses (light on top, dark below) and a neutral blotch texture
## that breaks the flat colour up close. A part is a list of triangles (Godot's winding: clockwise in front) with its
## normals, colours (linear) and UVs; `piece` joins the parts into one mesh, so a model is one draw call.


class Part:
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()

	func turned(yaw: float) -> Part:
		var b := Basis(Vector3.UP, yaw)
		for i in pos.size():
			pos[i] = b * pos[i]
			nor[i] = b * nor[i]
		return self


## the shared painted material (painted.tres): vertex colour times the blotch texture, which darkens by 25% on average,
## so its colour starts at 1.35
static func material() -> StandardMaterial3D:
	return load("res://src/ui/scene/painted.tres")


## the seeded draw of painted.ts (Park–Miller): the same seed builds the same tree as the web
static func rng(seed: float) -> Callable:
	var s := [(absi(floori(seed)) * 9301 + 49297) % 2147483647]
	if s[0] == 0:
		s[0] = 1
	return func() -> float:
		s[0] = (s[0] * 16807) % 2147483647
		return s[0] / 2147483647.0


## cheap noise from -1 to 1, fixed by the seed
static func noise3(x: float, y: float, z: float, s: float) -> float:
	return 0.65 * sin(x * 2.1 + s) * sin(y * 2.7 + s * 1.3) * sin(z * 2.3 + s * 0.7) \
		+ 0.35 * sin(x * 4.7 + s * 2) * sin(y * 5.3 + s) * sin(z * 4.1 + s * 3)


## tones from hex, in linear light as Three keeps them
static func tones(hex: Array) -> Array:
	return hex.map(func(h: String) -> Color: return Color(h).srgb_to_linear())


## a colour on the tone scale, t from 0 to 1: a short step between tones (paint masses, not a gradient)
static func ramp(stops: Array, t: float) -> Color:
	var k := clampf(t, 0.0, 1.0) * (stops.size() - 1)
	var i := mini(stops.size() - 2, floori(k))
	return (stops[i] as Color).lerp(stops[i + 1], smoothstep(0.3, 0.7, k - i))


## UV by box projection per face (the texture never stretches); flat normals when `facet`
static func box_uv(p: Part, scale: float = 0.8, facet: bool = true) -> Part:
	p.uv.resize(p.pos.size())
	for i in range(0, p.pos.size(), 3):
		var n := (p.pos[i + 2] - p.pos[i]).cross(p.pos[i + 1] - p.pos[i]) # Godot's winding: this points out
		var a := n.abs()
		for k in 3:
			var v := p.pos[i + k]
			if a.y >= a.x and a.y >= a.z:
				p.uv[i + k] = Vector2(v.x, v.z) * scale
			elif a.x >= a.z:
				p.uv[i + k] = Vector2(v.z, v.y) * scale
			else:
				p.uv[i + k] = Vector2(v.x, v.y) * scale
			if facet:
				p.nor[i + k] = n.normalized()
	return p


## a part from an indexed grid in Three's winding (counter-clockwise): smooth normals, then one vertex per corner
static func _from_indexed(pos: PackedVector3Array, col: PackedColorArray, uv: PackedVector2Array, idx: PackedInt32Array) -> Part:
	var nor := PackedVector3Array()
	nor.resize(pos.size())
	for t in range(0, idx.size(), 3):
		var n := (pos[idx[t + 1]] - pos[idx[t]]).cross(pos[idx[t + 2]] - pos[idx[t]])
		for k in 3:
			nor[idx[t + k]] += n
	var p := Part.new()
	for t in range(0, idx.size(), 3):
		for k in [0, 2, 1]: # flipped to Godot's winding
			var i: int = idx[t + k]
			p.pos.append(pos[i])
			p.nor.append(nor[i].normalized())
			p.col.append(col[i])
			p.uv.append(uv[i])
	return p


## a tube of rings [{p, r}] along a path; `tint(p, i, a)` paints each vertex. o: flat (lying rings, an upright trunk),
## shape(a, i) a radius factor, lift(a, i) a height offset, v the texture repeats per metre along it
static func tube(rings: Array, sides: int, tint: Callable, o: Dictionary = {}) -> Part:
	var pos := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var length := 0.0
	var q := Quaternion.IDENTITY
	for i in rings.size():
		var ring: Dictionary = rings[i]
		if i:
			length += (ring.p as Vector3).distance_to(rings[i - 1].p)
		if not o.get("flat", false):
			var tan: Vector3 = (rings[mini(rings.size() - 1, i + 1)].p - rings[maxi(0, i - 1)].p).normalized()
			q = Quaternion(Vector3.UP, tan)
		for j in sides + 1:
			var a := float(j % sides) / sides * TAU
			var r: float = ring.r * (o.shape.call(a, i) if o.has("shape") else 1.0)
			var lift: float = o.lift.call(a, i) if o.has("lift") else 0.0
			var v: Vector3 = q * Vector3(cos(a) * r, lift, sin(a) * r) + ring.p
			pos.append(v)
			col.append(tint.call(v, i, a))
			uv.append(Vector2(float(j) / sides, length * o.get("v", 1.0)))
		if i:
			for j in sides:
				var a0 := (i - 1) * (sides + 1) + j
				var c0 := a0 + sides + 1
				idx.append_array([a0, c0, a0 + 1, a0 + 1, c0, c0 + 1])
	return _from_indexed(pos, col, uv, idx)


const ICO_T := 1.618033988749895
const ICO_V := [-1, ICO_T, 0, 1, ICO_T, 0, -1, -ICO_T, 0, 1, -ICO_T, 0, 0, -1, ICO_T, 0, 1, ICO_T, 0, -1, -ICO_T, 0, 1, -ICO_T,
	ICO_T, 0, -1, ICO_T, 0, 1, -ICO_T, 0, -1, -ICO_T, 0, 1]
const ICO_F := [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8, 3, 9, 4,
	3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]


## the unit icosphere of Three's IcosahedronGeometry(1, detail): its triangles' corners, in Three's winding
static func icosphere(detail: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var cols := detail + 1
	for f in range(0, ICO_F.size(), 3):
		var c := []
		for k in 3:
			var i: int = ICO_F[f + k] * 3
			c.append(Vector3(ICO_V[i], ICO_V[i + 1], ICO_V[i + 2]))
		var v := []
		for i in cols + 1:
			var aj: Vector3 = c[0].lerp(c[2], float(i) / cols)
			var bj: Vector3 = c[1].lerp(c[2], float(i) / cols)
			var rows := cols - i
			var row := []
			for j in rows + 1:
				row.append(aj if j == 0 and rows == 0 else aj.lerp(bj, float(j) / rows))
			v.append(row)
		for i in cols:
			for j in 2 * (cols - i) - 1:
				var k := j / 2
				if j % 2 == 0:
					out.append_array([v[i][k + 1], v[i + 1][k], v[i][k]])
				else:
					out.append_array([v[i][k + 1], v[i + 1][k + 1], v[i + 1][k]])
	for i in out.size():
		out[i] = out[i].normalized()
	return out


## a mass crumpled by noise (crown tuft, rock, sack): a few-face ball, flatter below; `tint(p, d)` paints it.
## o: rough, under, detail, uv, facet
static func lump(at: Vector3, rx: float, ry: float, rz: float, seed: float, tint: Callable, o: Dictionary = {}) -> Part:
	var ball := icosphere(o.get("detail", 1))
	var p := Part.new()
	var rough: float = o.get("rough", 0.28)
	var under: float = o.get("under", 0.55)
	for t in range(0, ball.size(), 3):
		for k in [0, 2, 1]: # flipped to Godot's winding
			var d := ball[t + k]
			var s := 1.0 + rough * noise3(d.x, d.y, d.z, seed)
			var v := Vector3(d.x * rx * s, d.y * ry * s * (under if d.y < 0 else 1.0), d.z * rz * s) + at
			p.pos.append(v)
			p.col.append(tint.call(v, d))
			# the stretched ball's smooth normal: the mass takes light as one volume and the painted tone rules
			p.nor.append(Vector3(d.x / rx, d.y / ry, d.z / rz).normalized())
	return box_uv(p, o.get("uv", 0.8), o.get("facet", false))


## a painted box, one colour per face (top, sides, bottom), tilted, turned and put in place
static func slab(w: float, h: float, d: float, at: Vector3, top: Color, side: Color, turn: float = 0.0, tilt: float = 0.0) -> Part:
	var b := BoxMesh.new()
	b.size = Vector3(w, h, d)
	var arr := b.get_mesh_arrays()
	var src: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var sn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var basis := Basis(Vector3.UP, turn) * Basis(Vector3.BACK, tilt)
	var p := Part.new()
	for i in idx:
		var n := sn[i]
		var c := top if n.y > 0.5 else side
		p.col.append(c * (0.45 if n.y < -0.5 else (1.0 if n.y > 0.5 else 0.72 + 0.28 * absf(n.x))))
		p.pos.append(basis * src[i] + at)
		p.nor.append(basis * n)
	return box_uv(p)


## the parts joined into one mesh, with the box above ground (width w, height h) whoever measures and scales it reads
static func piece(parts: Array, w: float, h: float, extra: Dictionary = {}) -> Dictionary:
	var all := Part.new()
	for p in parts:
		all.pos.append_array(p.pos)
		all.nor.append_array(p.nor)
		all.col.append_array(p.col)
		all.uv.append_array(p.uv)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = all.pos
	arr[Mesh.ARRAY_NORMAL] = all.nor
	arr[Mesh.ARRAY_COLOR] = all.col
	arr[Mesh.ARRAY_TEX_UV] = all.uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, material())
	var out := {"mesh": mesh, "box": AABB(Vector3(-w / 2, 0, -w / 2), Vector3(w, h, w))}
	out.merge(extra)
	return out

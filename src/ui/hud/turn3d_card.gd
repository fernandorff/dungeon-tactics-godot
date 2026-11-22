class_name Turn3dCard
extends RefCounted
## One card of the 3D turn list (port of the card part of the web game's turn3d/turn3d.ts): a quad drawn by
## card3d.gdshader that springs to its row's box, its face cropped from the unit's painted sheet, and the lines beside
## it as labels split at " · ", each part over its bar.

const SHADER: Shader = preload("res://src/ui/ui3d/card3d.gdshader")
const DIGITS: Texture2D = preload("res://assets/ui/turn-digits.png")
const PAINT: Texture2D = preload("res://assets/ui/turn-paint.png")
const INK := Color("#f1ebd2") # the light ink of the 3D bar's numbers, on the same dark ground
const INNER := 40.2 / 43.0 # the picture's width over its height inside the frame: how a face is cropped
const LEFT := 46.0 # room around a row's box inside its quad, design px: the number and the gold plate on the left,
const RIGHT := 176.0 # the target band on the right,
const PAD := 14.0 # the glow and the shadow above and below
const SIDES := ["x", "y", "w", "h"]

var d: Dictionary # QueueView.cards' entry
var mesh := MeshInstance3D.new()
var mat := ShaderMaterial.new()
var box := {"x": Spring3d.new(), "y": Spring3d.new(), "w": Spring3d.new(), "h": Spring3d.new()} # in scroll space, px
var row := -1 # the row it follows; -1 once it is leaving
var alpha := 0.0
var fade := 1.0 # 1 showing, 0 leaving
var texts_key := ""
var lines: Array = [] # each line's parts: Array of Array of Label3D
var _face := {}
var _frames := 1


func _init(card: Dictionary, root: Node3D) -> void:
	d = card
	mat.shader = SHADER
	mesh.mesh = QuadMesh.new()
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)
	# each card takes its own patch of the paint, the same on every load (a screenshot repeats)
	var key: String = d.id.unit + "/" + d.id.charge
	var sum := 0
	for ch in key:
		sum += ch.unicode_at(0)
	mat.set_shader_parameter("seed", fmod(sum * 0.137, 1.0))
	mat.set_shader_parameter("digits", DIGITS)
	mat.set_shader_parameter("paint", PAINT)
	for k in ["now", "target", "pending", "hover"]:
		mat.set_shader_parameter(k, 0.0)
	_set_face(d.unit)


## the face of a unit on its card: its painted sheet's frame, cut to the picture's shape, in its glow colour if it has one
func _set_face(u: Dictionary) -> void:
	var tint: String = Content.units[u.def].get("tint", "")
	if tint != "":
		var c := Color(tint)
		mat.set_shader_parameter("tint", Vector4(c.r, c.g, c.b, 0.55))
	var id := Portraits.sheet_of(u.def)
	_face = Content.data.faces[id] if id != "" else {}
	if _face.is_empty():
		return
	var tex: Texture2D = load("res://assets/faces/%s.webp" % id)
	_frames = maxi(1, roundi(float(tex.get_width()) / tex.get_height()))
	mat.set_shader_parameter("face", tex)
	mat.set_shader_parameter("has_face", 1.0)
	crop()


## moves the face to its unit's expression now
func crop() -> void:
	if _face.is_empty():
		return
	var frame := Portraits.frame_of(_face, Portraits.expression_of(d.unit))
	mat.set_shader_parameter("face_uv", Vector4((frame + (1 - INNER) / 2) / _frames, 0, INNER / _frames, 1))


## what the row shows now: life, side, number and a charge's medal
func show(card: Dictionary) -> void:
	d = card
	mat.set_shader_parameter("hp", d.hp)
	mat.set_shader_parameter("team", 1.0 if d.enemy else 0.0)
	mat.set_shader_parameter("gold", 1.0 if d.id.charge != "" else 0.0)
	mat.set_shader_parameter("num", float(d.num))
	var on := 0.0
	if d.id.charge != "":
		var cell := Icons.cell(d.id.charge)
		on = 2.0 if cell.x >= 0 else 1.0
		if cell.x >= 0:
			var atlas: Texture2D = Icons.texture(d.id.charge).atlas
			mat.set_shader_parameter("icon", atlas)
			mat.set_shader_parameter("icon_grid", Vector2(atlas.get_width(), atlas.get_height()) / Icons.CELL)
			mat.set_shader_parameter("icon_cell", Vector2(cell))
	mat.set_shader_parameter("icon_on", on)


## the card's lines of text; unchanged lines keep their labels (the CT of every row changes each turn, not each draw)
func set_texts(layer: Layer3d, root: Node3D, size: float) -> void:
	var st: Variant = d.stats
	var key := str([st.lines, size, layer.dpr]) if st != null else ""
	if key == texts_key:
		return
	drop_texts()
	texts_key = key
	if st == null:
		return
	for l: String in st.lines:
		var parts: Array = []
		for part in l.split(" · "):
			var m := Text3d.label(layer, part, size, INK)
			Text3d.order(m, 5) # over every card (3 at most): a hovered neighbour grows a little
			Text3d.alpha(m, 0.0)
			root.add_child(m)
			parts.append(m)
		lines.append(parts)


func drop_texts() -> void:
	for l: Array in lines:
		for m: Label3D in l:
			m.queue_free()
	lines = []
	texts_key = ""


# GLSL's smoothstep, for the texts to fade at the list's ends as the cards do
static func _ramp(a: float, b: float, v: float) -> float:
	var t := clampf((v - a) / (b - a), 0.0, 1.0)
	return t * t * (3 - 2 * t)


## one frame: springs, fades and marks, then the quad and its lines on the page. `g`: Turn3d.geo; `e`: the eases' dt
func step(layer: Layer3d, g: Dictionary, dt: float, e: float, t: float, tipped: bool, clip: Vector2) -> void:
	var still := layer.still
	var s: float = g.s
	var lay: Dictionary = g.lay
	for k: String in SIDES:
		if still:
			box[k].land()
		else:
			box[k].step(dt, Turn3d.K, Turn3d.C)
	alpha = Spring3d.ease(alpha, fade, e, 14 if fade else 9)
	var on := func(flag: bool) -> float: return 1.0 if flag and fade > 0 else 0.0
	var ease_to := func(name: String, to: float, rate: float) -> float:
		var v := Spring3d.ease(mat.get_shader_parameter(name), to, e, rate)
		mat.set_shader_parameter(name, v)
		return v
	ease_to.call("now", on.call(d.now), 7)
	var target: float = ease_to.call("target", on.call(d.target), 12)
	ease_to.call("pending", on.call(d.pending), 12)
	var hover: float = ease_to.call("hover", on.call(tipped), 16)
	var shift := 8 * s * target
	var lift := 4 * s * hover
	mat.set_shader_parameter("shift", shift)
	mat.set_shader_parameter("lift", lift)
	mat.set_shader_parameter("alpha", alpha)
	mat.set_shader_parameter("time", t)
	mat.set_shader_parameter("s", s)
	mat.set_shader_parameter("clip_y", clip)
	crop()
	# hovered cards grow a little around their middle
	var grow := 1 + 0.06 * hover
	var w := maxf(1.0, box.w.x * grow)
	var h := maxf(1.0, box.h.x * grow)
	var ox: float = lay.left + box.x.x - (w - box.w.x) / 2
	var oy: float = lay.top + box.y.x - g.scroll - (h - box.h.x) / 2
	# the lines right of the card, the bars under them; the quad's room on the right grows to hold them
	var sl := QueueLayout.stats_layout(h, s, maxi(1, lines.size()))
	var bar_w: float = g.stat_w - 2 * Turn3d.TEXT_PAD if not lines.is_empty() else 0.0
	var bar_x: float = w + sl.x
	mat.set_shader_parameter("stat", Vector4(bar_x, bar_w, sl.hpBar, sl.stBar))
	var bars: Array = d.stats.get("bars", [-1.0, -1.0, 0.0]) if d.stats != null else [-1.0, -1.0, 0.0]
	mat.set_shader_parameter("pools", Vector3(bars[0], bars[1], bars[2]))
	mat.set_shader_parameter("bar_h", sl.bar)
	var qw := w + LEFT * s + maxf(RIGHT * s, bar_x + bar_w + 24 * s)
	var qh := h + 2 * PAD * s
	mat.set_shader_parameter("card", Vector2(w, h))
	mat.set_shader_parameter("origin", Vector2(LEFT * s, PAD * s))
	mat.set_shader_parameter("size", Vector2(qw, qh))
	mesh.scale = Vector3(qw, qh, 1)
	mesh.position = Vector3(ox - LEFT * s + qw / 2, -(oy - PAD * s + qh / 2), 0)
	mat.render_priority = 3 if tipped else (2 if d.now else int(fade))
	# the same step aside, rise and fade at the list's ends as the card's own drawing
	var tx := ox + bar_x - Turn3d.TEXT_PAD + shift
	var ty := oy - lift
	for i in lines.size():
		for j in lines[i].size():
			var m: Label3D = lines[i][j]
			var y: float = ty + sl.lines[i]
			var x: float = tx + j * (bar_w / 2 + 2 * s) # the second bar's left: half the width past its 4 px gap
			Text3d.put(m, x + Text3d.w(m) / 2, y, layer.dpr)
			Text3d.alpha(m, alpha * _ramp(clip.x, clip.x + 16 * s, y) * (1 - _ramp(clip.y - 16 * s, clip.y, y)))


func dispose() -> void:
	drop_texts()
	mesh.queue_free()

class_name UnitModels
## The units' KayKit bodies (port of the model parts of markers.ts and unit-view.ts): which model each sheet wears, how
## tall it stands, and the body itself, fitted to that height with its clips and the shared gesture pack.

## KayKit model of each sheet (assets/models/<id>.glb); the Brute is the barbarian, the Archer the ranger
const MODEL := {
	"warrior": "knight", "archer": "ranger", "mage": "mage", "rogue": "rogue_hooded", "soldier": "skeleton_warrior",
	"skeleton_archer": "skeleton_rogue", "dark_mage": "skeleton_mage", "brute": "barbarian", "minion": "skeleton_minion",
	"mini_skeleton": "skeleton_minion", "colossus": "skeleton_warrior", "lancer": "lancer", "acolyte": "mage",
	"veil_knight": "knight", "snake": "snake", "rat": "rat", "spider": "spider", "bat": "bat",
}
const HEIGHT := {"default": 0.85, "brute": 1.05, "colossus": 2.0} # the Brute is bigger: it reads from afar that it hits hard
const RIG := "Rig/Skeleton3D" # where every KayKit model keeps its bones, the pack's tracks are moved there
## near-black swarm models lit from within so they read on dark stone (Nov 20, "rato e aranha mais visíveis")
const LIFT := {"rat": [Color("#c9a37a"), 0.35], "spider": [Color("#a98ee0"), 0.35]}
const TINT_GLOW := 0.45 # a sheet's own glow (tint): visible on the dark unit without erasing the texture


static func model_of(def: String) -> String:
	return MODEL.get(Content.base_def(def), Content.units.get(def, {}).get("model", ""))


## a unit's height in metres: a split map's ½ sheet is as many times its whole sheet's as its square is
static func height_of(def: String) -> float:
	var d: Dictionary = Content.units.get(def, {})
	if def.ends_with(Content.HALF):
		var base := Content.base_def(def)
		var k: float = float(d.size) / Content.units[base].get("size", 1) if d.has("size") else 2.0
		return k * height_of(base)
	if d.get("size", 1) > 1:
		return HEIGHT.colossus
	return HEIGHT.brute if model_of(def) == "barbarian" else HEIGHT.default


## the gesture pack (abilities, walk, jump) with its tracks moved from the pack's bone nodes onto a model's skeleton
static func pack() -> AnimationLibrary:
	var src: Node = (load("res://assets/models/animations.glb") as PackedScene).instantiate()
	var ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false)
	# node names lost the bones' dots ("lowerarm.l" became "lowerarm_l"): the real names come from a KayKit skeleton
	var ref: Node = (load("res://assets/models/knight.glb") as PackedScene).instantiate()
	var sk: Skeleton3D = ref.get_node(RIG)
	var bones := {}
	for i in sk.get_bone_count():
		bones[sk.get_bone_name(i).validate_node_name()] = sk.get_bone_name(i)
	ref.free()
	var lib := AnimationLibrary.new()
	for name in ap.get_animation_list():
		var a: Animation = ap.get_animation(name).duplicate(true)
		for t in a.get_track_count():
			var node := String(a.track_get_path(t)).get_file()
			a.track_set_path(t, NodePath("%s:%s" % [RIG, bones.get(node, node)]))
		if UnitClips.LOOPING.has(name):
			a.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(name, a)
	src.free()
	return lib


## the body of sheet `def` under `holder`, fitted to its height (a lying own-rig body to its length) and standing in
## Idle; null when the sheet has no model (the Beacon)
static func body(def: String, holder: Node3D, lib: AnimationLibrary) -> Node3D:
	var m := model_of(def)
	if m == "":
		return null
	var b: Node3D = (load("res://assets/models/%s.glb" % m) as PackedScene).instantiate()
	holder.add_child(b)
	var ap: AnimationPlayer = b.find_child("AnimationPlayer", true, false)
	var own := false
	for a in ap.get_animation_list():
		own = own or a.contains("|")
		var anim := ap.get_animation(a)
		if UnitClips.LOOPING.has(a) or a.ends_with("_Idle") or a.ends_with("_Walk") or a.ends_with("_Flying"):
			anim.loop_mode = Animation.LOOP_LINEAR
	if not own and b.has_node(RIG):
		ap.add_animation_library("pack", lib)
	var box := _box(b)
	var long: float = Content.units.get(def, {}).get("halfLength", 1)
	var fit: float = long / maxf(box.size.x, box.size.z) if own else height_of(def) / box.size.y
	b.scale = Vector3.ONE * fit
	if own:
		# a lying body is centred on its cell; a long one (the snake) falls back over its tail's cells
		b.position = Vector3(-box.get_center().x * fit, 0, -box.get_center().z * fit - (long - 1) / 2.0)
	_paint(b, def)
	UnitClips.play(ap, "Idle")
	return b


## the box of the meshes as posed at rest, in the body's own space
static func _box(b: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in b.find_children("*", "MeshInstance3D", true, false):
		# the chain of local transforms up to the body: it is measured before it joins the scene
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != b:
			t = (n as Node3D).transform * t if n is Node3D else t
			n = n.get_parent()
		var box: AABB = t * (mi as MeshInstance3D).get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


## KayKit textures are palettes: sampled without blending neighbours (learned in the web POC). A tinted or lifted unit
## gets its own copies with the glow
static func _paint(b: Node3D, def: String) -> void:
	var tint: Variant = Content.units.get(def, {}).get("tint")
	var lift: Array = LIFT.get(Content.base_def(def), [])
	for mi in b.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as BaseMaterial3D
			if mat == null:
				continue
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			if tint == null and lift.is_empty():
				continue
			var own := mat.duplicate() as BaseMaterial3D
			own.emission_enabled = true
			own.emission = Color(tint) if tint != null else lift[0]
			own.emission_energy_multiplier = TINT_GLOW if tint != null else lift[1]
			(mi as MeshInstance3D).set_surface_override_material(s, own)

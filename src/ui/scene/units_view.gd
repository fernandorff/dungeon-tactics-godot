class_name UnitsView
extends RefCounted
## The units' drawings for the battle view (port of makeView in unit-view.ts and the frame update of units.ts): a holder
## per unit with its KayKit body (or the Beacon's crystal), team ring, front arrow and health bar; the clips they play;
## the bars turned to the camera each frame. The town's people carry a name label instead of the marks.

const CRYSTAL := Color("#7ff3ff")

var marks := UnitMarks.new()
var pack: AnimationLibrary # the shared gestures, moved onto the KayKit skeleton once per battle
var _crystal: Mesh
var _crystal_mat: StandardMaterial3D
var _walking := {} # holder → msec of its last free step (the town's walker)


func _init() -> void:
	pack = UnitModels.pack()


## a unit's holder: its position is the unit's cell, its yaw its facing; `label` "" for a battle unit with marks
func make(u: Dictionary, label: String) -> Node3D:
	var n := Node3D.new()
	var size: int = Content.units[u.def].get("size", 1)
	var h := UnitModels.height_of(u.def)
	var body := UnitModels.body(u.def, n, pack)
	if body == null:
		n.add_child(_beacon())
	n.set_meta("size", size)
	n.set_meta("height", h)
	n.set_meta("def", u.def)
	if label == "":
		marks.add(n, u.team, size, u.has("facing"), h)
		UnitMarks.set_life(n, float(u.hp) / Content.units[u.def].hp)
		return n
	var l := Label3D.new()
	l.name = "Label"
	l.text = label
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 36
	l.pixel_size = 0.006
	l.outline_size = 8
	l.position.y = h + 0.35
	n.add_child(l)
	return n


## the Beacon has no model: a glowing crystal, to read from afar which is the target to protect
func _beacon() -> Node3D:
	if _crystal == null:
		var s := SphereMesh.new()
		s.radius = 0.32
		s.height = 0.64
		s.radial_segments = 4
		s.rings = 2 # an octahedron, as the web's
		_crystal = s
		_crystal_mat = StandardMaterial3D.new()
		_crystal_mat.albedo_color = CRYSTAL
		_crystal_mat.emission_enabled = true
		_crystal_mat.emission = Color("#2bb8d6")
		_crystal_mat.emission_energy_multiplier = 1.2
	var mi := MeshInstance3D.new()
	mi.mesh = _crystal
	mi.material_override = _crystal_mat
	mi.position.y = 0.55
	var glow := OmniLight3D.new()
	glow.light_color = CRYSTAL
	glow.light_energy = 2.0 / PI
	glow.omni_range = 3.0
	mi.add_child(glow)
	return mi


static func player(n: Node3D) -> AnimationPlayer:
	return n.find_child("AnimationPlayer", true, false) as AnimationPlayer


## plays a clip on the unit's body (none on the Beacon); the name of what plays, "" when nothing does
static func play(n: Node3D, clip: String, rate: float = 1.0) -> String:
	var ap := player(n)
	return UnitClips.play(ap, clip, rate) if ap else ""


## a once-only gesture, then back to Idle (the gesture stuck on its last frame until the unit acted again, Nov 13)
static func gesture(n: Node3D, clip: String) -> void:
	var ap := player(n)
	if ap and UnitClips.play(ap, clip) != "":
		ap.queue(UnitClips.find(ap, "Idle"))


## Walking_A has 2 strides in 1.07 s: 1.25x gives ~1.4 strides per 0.6 s tile, the foot barely slides
static func walk(n: Node3D) -> void:
	var ap := player(n)
	if ap and not ap.current_animation.ends_with("Walking_A"):
		UnitClips.play(ap, "Walking_A", 1.25)


static func idle(n: Node3D) -> void:
	var ap := player(n)
	if ap and ap.current_animation != UnitClips.find(ap, "Idle"):
		UnitClips.play(ap, "Idle")


## the town's walker took a step: it walks until it stops for a moment (step_done)
func stepped(n: Node3D) -> void:
	walk(n)
	_walking[n] = Time.get_ticks_msec()


## per frame: bars turned to the camera, and a walker that stopped goes back to Idle
func update(units: Dictionary, camera: Camera3D) -> void:
	var cam := camera.global_basis
	for n in units.values():
		var bar := (n as Node3D).get_node_or_null("Bar") as Node3D
		if bar and bar.visible:
			bar.global_basis = cam
	var now := Time.get_ticks_msec()
	for n in _walking.keys():
		if not is_instance_valid(n):
			_walking.erase(n)
		elif now - _walking[n] > 120:
			idle(n)
			_walking.erase(n)

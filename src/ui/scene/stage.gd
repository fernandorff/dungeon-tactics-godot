class_name Stage
## The battle's light (port of the lights in scene.ts and the mood light of ambience.ts): a hemisphere sky, warm above
## and violet below, and a white sun from the upper left that casts the shadows, both changed by the map's mood. Three
## divides every light by π (Lambert); Godot does not, so each intensity is the web's over π.

const BACKGROUND := Color.BLACK # the fade to black around the map (FADE, on since Nov 13): the fog's top colour is black
const SKY := Color("#fff1d6")
const GROUND := Color("#3a3050")
const SKY_POWER := 1.15
const SUN := Color("#ffffff")
const SUN_POWER := 1.6
const SUN_FROM := Vector3(-6, 12, 4) # the web's sun position, looking at the map's middle

static func light(into: Node3D, centre: Vector3, kind: String) -> Dictionary:
	var mood: Dictionary = Moods.LIGHT.get(kind, {"sky": 1.0, "sun": 1.0, "at": SUN_FROM})
	var sky_k: float = SKY_POWER * mood.sky / PI
	var s := SKY.srgb_to_linear()
	var g := GROUND.srgb_to_linear()
	# the hemisphere light, mix(ground, sky, 0.5 + 0.5 * n.y): an even half of both everywhere plus a shadowless light
	# from straight above with the other half of the difference; only faces turned down get it a little too bright.
	# (Godot's sky ambient ignores its energy in the Compatibility renderer, measured on Nov 21.)
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = BACKGROUND
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = ((s + g) * 0.5).linear_to_srgb()
	e.ambient_light_energy = sky_k
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var env := WorldEnvironment.new()
	env.environment = e
	into.add_child(env)
	var fill := DirectionalLight3D.new()
	fill.light_color = ((s - g) * 0.5).linear_to_srgb()
	fill.light_energy = sky_k
	fill.rotation_degrees = Vector3(-90, 0, 0)
	into.add_child(fill)
	var sun := DirectionalLight3D.new()
	sun.light_color = SUN
	sun.light_energy = SUN_POWER * mood.sun / PI
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 80.0
	into.add_child(sun)
	sun.look_at_from_position(centre + mood.at, centre, Vector3.UP)
	return {"env": e, "sun": sun, "fill": fill}

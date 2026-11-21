class_name FpsCounter
extends Label
## The battle's performance counter (port of fps.ts): frames per second, draw calls and memory in the corner, shown in
## a battle when Options › Display › FPS counter is on; F3 switches it there, as on the web.

var _wait := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_TOP_RIGHT, PRESET_MODE_MINSIZE)
	grow_horizontal = GROW_DIRECTION_BEGIN
	position += Vector2(-12, 72) # the web's place: right edge, 72 px down
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_theme_font_size_override("font_size", 14)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "monospace"])
	add_theme_font_override("font", mono)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_content_margin_all(6)
	add_theme_stylebox_override("normal", bg)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 4)
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 100


func _in_battle() -> bool:
	return get_parent().get("_screen") is BattleScreen


## twice a second, as the web's counter: a number that changes every frame cannot be read
func _process(dt: float) -> void:
	visible = Settings.fps() and _in_battle()
	_wait -= dt / maxf(Engine.time_scale, 0.001) # real time, also in the fast battle
	if not visible or _wait > 0.0:
		return
	_wait = 0.5
	var mb := func(m: Performance.Monitor) -> float: return Performance.get_monitor(m) / 1048576.0
	text = "\n".join([
		"%d fps · %.1f ms" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0],
		Texts.t("%d desenhos · %.1f mil triângulos", "%d draw calls · %.1fk triangles") % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0],
		Texts.t("%d objetos · %.0f MB de texturas", "%d objects · %.0f MB of textures") % [Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), mb.call(Performance.RENDER_TEXTURE_MEM_USED)],
		"Mem %.0f MB" % mb.call(Performance.MEMORY_STATIC),
	])


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F3 and _in_battle():
		Settings.set_fps(not Settings.fps())
		get_viewport().set_input_as_handled()

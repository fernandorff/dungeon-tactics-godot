class_name Layer3d
extends Control
## The shared 3D layer of the battle interface (port of the web game's ui3d/layer.ts): one orthographic camera in page
## px over the whole screen, its own world, drawn at the window's real pixels and shown over the map. Screens add two
## roots: `flat` (panels and text, in the order their render priority gives, no depth) and `deep` (the low-poly models,
## depth-tested among themselves and always over every panel: the web renders the flat scene, clears depth, then the
## deep one). Page px map to world (x, -y); the camera looks down -z.
##   Page px are the window's real px over the system's display scale, as a browser's CSS px: the web's layout and its
##   16 px text floor read the same page size as the web on that screen, not the port's 1280x720 canvas. `hits` holds
##   the screens' buttons in page px, scaled back onto the canvas.

const DEEP := 100 # the models' render priority: after every panel and text, as the web's second pass

var stage := {} # StageLayout.stage of the page
var small := {} # the stage of the pieces a phone shrinks (turn list, combat bar)
var s := 1.0
var dpr := 1.0 # real pixels per page px
var page := Vector2.ONE # the page's size in page px
var hits := Control.new() # the screens' transparent buttons, laid out in page px
var still := false # reduced motion, read once a frame: everything lands at once, nothing sways
var finger := false # the last input was a finger: the glove hides
var phone := false
var inset_top := 12.0 # the page's top margin (the web's inset.top; no notch on a desktop window)
var t := 0.0
var flat := Node3D.new()
var deep := Node3D.new()

static var paint: Texture2D = preload("res://assets/ui/menu-paint.png")

var _view := SubViewport.new()
var _picture := TextureRect.new()
var _camera := Camera3D.new()
var _screens: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_view.own_world_3d = true
	_view.transparent_bg = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	_view.add_child(_camera)
	_view.add_child(flat)
	_view.add_child(deep)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.near = 1
	_camera.far = 2000
	_picture.texture = _view.get_texture()
	# blending onto the transparent target leaves the colour premultiplied: drawn plain, fades and shadows lost alpha twice
	var premult := CanvasItemMaterial.new()
	premult.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_picture.material = premult
	_picture.mouse_filter = MOUSE_FILTER_IGNORE
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_picture)
	hits.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(hits)
	resized.connect(fit)
	get_viewport().size_changed.connect(fit)
	fit()


## `screen`: an object with frame(dt, time) -> bool and resize()
func add(screen: Object) -> void:
	_screens.append(screen)
	screen.resize()


func remove(screen: Object) -> void:
	_screens.erase(screen)


## the size changed: the stage, the scale, the real pixels and the camera
func fit() -> void:
	var real := get_viewport().get_final_transform().get_scale().y * get_global_transform_with_canvas().get_scale().y
	dpr = clampf(DisplayServer.screen_get_scale(), 1.0, 2.0) # the web caps devicePixelRatio at 2 as well
	page = Vector2(maxf(1.0, size.x), maxf(1.0, size.y)) * real / dpr
	var w := page.x
	var h := page.y
	hits.size = page
	hits.scale = Vector2.ONE * (size.y / h)
	stage = StageLayout.stage(w, h, "edges")
	s = stage.s
	var coarse := OS.has_feature("mobile")
	StageLayout.set_page_floor(w, h, coarse)
	phone = coarse and minf(w, h) < StageLayout.TABLET_SIDE
	small = stage.duplicate()
	small.s = s * (0.65 if phone else 1.0)
	_view.size = Vector2i(ceili(w * dpr), ceili(h * dpr))
	_camera.size = h
	_camera.position = Vector3(w / 2, -h / 2, 1000)
	for screen in _screens:
		screen.resize()


func px(size_ref: float) -> float:
	return StageLayout.text_px(size_ref, s)


func _process(dt: float) -> void:
	dt = clampf(dt, 0.0, 0.1)
	still = Settings.reduced_motion()
	if not still:
		t += dt
	var moving:= false
	for screen in _screens:
		if screen.frame(dt, t):
			moving = true
	# a settled layer draws nothing new (the web's draw-only-while-moving): the frame after the last move is drawn once
	if moving or _dirty:
		_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	elif _drawing:
		_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_drawing = moving or _dirty
	_dirty = false


var _dirty := true
var _drawing := true


## a screen's data changed: draw again
func wake() -> void:
	_dirty = true

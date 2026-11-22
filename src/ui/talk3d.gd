class_name Talk3d
extends RefCounted
## The speech box drawn in 3D (port of the web game's talk.ts, window3d/talk3d.ts and talk-face.ts), a screen of the
## shared 3D layer: a parchment box at the page's foot with the speaker's name on a dark plaque over its top left
## corner, the painted face in its corner moving its mouth while the words type, the words in the paper's ink, the ▼ when
## the sentence is out, the key hint and Skip under it. Enter, Space, the pad's A or a click complete the sentence and,
## once complete, go to the next; Esc or Skip end the conversation. TalkLayout says where each part goes.
## shortcut: no `dark` narration and no place strip (the port has no story opening); add them with the opening

signal started
signal finished

const OVER := 40 # over the HUD's own pieces, which share the layer
const CHAR_MS := {"normal": 28.0, "fast": 10.0, "instant": 0.0} # Normal ~35 letters a second, Fast ~3 times that
const MOUTH_MS := 180.0 # slower than 8 Hz: the mouth reads as speech, not chatter
const HOP_MS := 220.0 # a new speaker's hop (style.css face-pop)
const FACE: Shader = preload("res://src/ui/ui3d/face3d.gdshader")

var _layer: Layer3d
var _root := Node3D.new()
var _fixed := Part3d.new() # the box, the name's plaque, the face's frame, the hint, Skip, the ▼
var _hit := Control.new()
var _skip := Button.new()
var _paper: MeshInstance3D
var _words: Label3D
var _face := MeshInstance3D.new()
var _face_mat := ShaderMaterial.new()
var _lines: Array = []
var _i := 0
var _shown := 0
var _clock := 0.0 # ms since the line began
var _born := 0.0 # ms since the speaker came, for the hop
var _frames := 1
var _at := Rect2()
var _drawn := ""


func _init(layer: Layer3d) -> void:
	_layer = layer
	_fixed.lift = OVER
	_fixed.want = 1.0
	_root.add_child(_fixed.group)
	_face_mat.shader = FACE
	_face.mesh = QuadMesh.new()
	_face.material_override = _face_mat
	_face_mat.render_priority = 32 + OVER
	_face.visible = false
	_root.add_child(_face)
	_root.visible = false
	layer.flat.add_child(_root)
	_hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit.focus_mode = Control.FOCUS_ALL
	_hit.gui_input.connect(_input)
	layer.hits.add_child(_hit)
	_skip.flat = true
	_skip.text = ""
	_skip.tooltip_text = Texts.t("Pular conversa", "Skip conversation") # its name says what it skips
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_skip.pressed.connect(_end)
	_skip.visible = false
	layer.hits.add_child(_skip)
	layer.add(self)


func talking() -> bool:
	return not _lines.is_empty()


## lines: [{who: {name, en?, def, pitch}, pt, en}]; `finished` when the last one is read or skipped
func say(lines: Array) -> void:
	_lines = lines
	_i = 0
	_root.visible = true
	_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_hit.grab_focus()
	_skip.visible = true
	_born = 0.0
	started.emit()
	_show()


## the mouth's frame `ms` into a line: talk1, talk2, talk1, neutral for [1, 2], open from the first instant; neutral once
## the sentence is out or for a still face (talk.ts mouthFrame)
static func mouth_frame(mouth: Array, ms: float, typing: bool = true) -> int:
	if not typing or mouth.is_empty():
		return 0
	var cycle := mouth.duplicate()
	var back := mouth.slice(0, -1)
	back.reverse()
	cycle.append_array(back)
	cycle.append(0)
	return cycle[int(ms / MOUTH_MS) % cycle.size()]


static func _char_ms() -> float:
	return 0.0 if Settings.reduced_motion() else CHAR_MS.get(Settings.text_speed(), 28.0)


func _full() -> String:
	return Texts.t(_lines[_i].pt, _lines[_i].en)


func _typing() -> bool:
	return _shown < _full().length()


func _show() -> void:
	if _i > 0 and _lines[_i - 1].who != _lines[_i].who:
		_born = 0.0 # a new speaker hops
	_shown = 0
	_clock = 0.0
	_drawn = ""
	if _char_ms() == 0.0:
		# instant: the whole sentence at once, with a single beep to mark who speaks
		_shown = _full().length()
		Sound.blip(_lines[_i].who.pitch)
	_draw()


func _input(ev: InputEvent) -> void:
	if not talking():
		return
	if ev is InputEventKey and ev.echo:
		_hit.accept_event() # a held Enter (the way to speed the enemy up) would skip the lines unread
	elif ev.is_action_pressed("ui_cancel"):
		_hit.accept_event()
		_end()
	elif ev.is_action_pressed("ui_accept") or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		_hit.accept_event()
		_next()


func _next() -> void:
	if _typing():
		_shown = _full().length()
		_draw()
	elif _i + 1 < _lines.size():
		_i += 1
		_show()
	else:
		_end()


func _end() -> void:
	_lines = []
	_root.visible = false
	_hit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit.release_focus()
	_skip.visible = false
	_fixed.clear()
	_layer.wake()
	finished.emit()


func resize() -> void:
	_fixed.key = ""
	if talking():
		_draw()


func _draw() -> void:
	var who: Dictionary = _lines[_i].who
	var name: String = who.get("en", who.name) if Texts.current() == "en" and who.has("en") else who.name
	var words := _full().substr(0, _shown)
	var done := not _typing()
	var size := 24.0
	var page := _layer.page
	var L := TalkLayout.layout({
		"pageW": page.x, "pageH": page.y, "safe": {"top": 0, "right": 0, "bottom": 0, "left": 0}, "dark": false,
		"face": name != "", "name": _width(name, 24), "title": 0, "skip": _width(Texts.t("Pular", "Skip"), 16),
		"lines": func(w: float, px: float) -> int: return _line_count(words, w, px),
	})
	var b: Rect2 = L.box
	var s := _layer.s
	_skip.position = L.skip.position
	_skip.size = L.skip.size
	var key := str([b, name, who.def, done, _layer.dpr, s])
	if key != _fixed.key:
		_fixed.clear()
		_fixed.key = key
		var pad := 44 * s
		_paper = Panel3d.quad(Panel3d.paper(b.size.x, b.size.y, pad, s, 7), b.position.x - pad, b.position.y - pad, b.size.x + 2 * pad, b.size.y + 2 * pad, 30 + OVER - 1)
		_fixed.group.add_child(_paper)
		var c := Result3d.C
		if L.faceAt != null:
			var at: Rect2 = L.faceAt
			_fixed.box(at.position.x, at.position.y, at.size.x, at.size.y, 0, c.plate, c.line)
			_set_face(who.def, at)
		if L.name != null:
			_plate(L.name, name, 30, c.title)
		_plate(L.skip, Texts.t("Pular", "Skip"), 24, c.text)
		var hint := Texts.t("Enter: seguir · Esc: pular", "Enter: next · Esc: skip")
		var k: Vector2 = L.keys
		var m := _label(hint, 20, HudSkin.INK_SOFT)
		_fixed.text(m, k.x - Text3d.w(m) / 2, k.y)
		if done:
			_fixed.text(_label("▼", 22, HudSkin.INK_SOFT), b.end.x - 26 * s, b.end.y - 22 * s)
		_face.visible = L.faceAt != null and _face_mat.get_shader_parameter("map") != null
	# the words, as far as the box has typed them; the box holds them whatever their length
	if words != _drawn:
		_drawn = words
		if _words:
			_words.queue_free()
			_words = null
		if words != "":
			var tx: Dictionary = L.text
			_words = Text3d.label(_layer, words, L.size, HudSkin.INK, tx.w, L.line)
			var k := minf(1.0, (b.end.y - tx.y - 8 * s) / Text3d.h(_words))
			_words.scale = Vector3.ONE * k
			Text3d.order(_words, 32 + OVER)
			_words.position = Vector3(tx.x + Text3d.w(_words) / 2, -(tx.y + Text3d.h(_words) / 2), 0)
			_root.add_child(_words)
	_layer.wake()


## a dark plaque with its words in the middle, shrunk to fit
func _plate(r: Rect2, words: String, size: float, color: Color) -> void:
	var s := _layer.s
	var c := Result3d.C
	_fixed.box(r.position.x, r.position.y, r.size.x, r.size.y, 8 * s, Color(c.plate, 0.96), Color(c.line, 0.9))
	var m := _label(words, size, color)
	m.scale = Vector3.ONE * minf(1.0, (r.size.x - 12 * s) / Text3d.w(m))
	_fixed.text(m, r.position.x + r.size.x / 2, r.position.y + r.size.y / 2)


func _label(words: String, size: float, color: Color) -> Label3D:
	return Text3d.label(_layer, words, _layer.px(size), color)


func _width(words: String, size: float) -> float:
	if words == "":
		return 0.0
	return Text3d.font().get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(size * _layer.dpr)).x / _layer.dpr


func _line_count(words: String, width: float, size: float) -> int:
	if words == "":
		return 0
	var para := TextParagraph.new()
	para.add_string(words, Text3d.font(), roundi(size * _layer.dpr))
	para.width = width * _layer.dpr
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	return para.get_line_count()


## the speaker's painted face in the box's corner, inside its frame's 2 px border; none without a sheet
func _set_face(def: String, box: Rect2) -> void:
	var id := Portraits.sheet_of(def)
	_face_mat.set_shader_parameter("map", null)
	if id == "":
		return
	var tex: Texture2D = load("res://assets/faces/%s.webp" % id)
	_frames = maxi(1, roundi(float(tex.get_width()) / tex.get_height()))
	_face_mat.set_shader_parameter("map", tex)
	var k := box.size.x / 132
	_at = box.grow(-2 * k)


func frame(dt: float, _t: float) -> bool:
	if not talking():
		return false
	var still := _layer.still
	var ms := _char_ms()
	_clock += dt * 1000
	_born += dt * 1000
	if ms > 0 and _typing():
		var to := mini(_full().length(), int(_clock / ms) + 1)
		var speed := Settings.text_speed()
		while _shown < to:
			_shown += 1
			# every other letter (on fast, 1 in 4): beep without machine-gunning
			var ch := _full()[_shown - 1]
			if _shown % (4 if speed == "fast" else 2) == 1 and ch.to_upper() != ch.to_lower():
				Sound.blip(_lines[_i].who.pitch)
		_draw()
	# the mouth while it types, the hop of a new speaker
	var f: Dictionary = Content.data.faces.get(Portraits.sheet_of(_lines[_i].who.def), {})
	var n := mouth_frame([] if still else f.get("mouthFrames", []), _clock, _typing())
	_face_mat.set_shader_parameter("uv", Vector4(float(n % _frames) / _frames, 0, 1.0 / _frames, 1))
	var k := 1.0 if still else clampf(_born / HOP_MS, 0.0, 1.0)
	var left := (1 - k) * (1 - k)
	var sc := 1 - 0.08 * left
	_face.scale = Vector3(_at.size.x * sc, _at.size.y * sc, 1)
	_face.position = Vector3(_at.position.x + _at.size.x / 2, -(_at.position.y + _at.size.y / 2 + 6 * left), 0)
	_face_mat.set_shader_parameter("alpha", 1 - 0.6 * left)
	_fixed.fade(10.0 if still else dt * 3)
	return true

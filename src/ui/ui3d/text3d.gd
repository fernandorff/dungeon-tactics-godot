class_name Text3d
## Text of the 3D UI kit (port of the web game's ui3d/text.ts): a label as a quad in page px, in the theme's serif at
## weight 500 with a hair of stroke in the same ink (the system serif has no weight between regular and bold), drawn at
## the real pixels. Its box is the web canvas's: the text plus 3 px on every side, so places computed from a label's
## width (`w`) land where the web's do. `scale` on the node shrinks it, as the web multiplies the mesh's scale.

const PAD := 3.0

static var _ink: FontVariation


## the theme's serif with the web's weight: its hair of stroke in the same ink and its soft halo (text.ts) read as a
## heavier letter than the bare serif; 0.9 matched the web's turn list side by side at 1920x1080 (embolden 0.48, the
## stroke's width alone, still read thin)
static func font() -> FontVariation:
	if _ink == null:
		_ink = FontVariation.new()
		_ink.base_font = HudSkin.font()
		_ink.variation_embolden = 0.9
	return _ink


## `size`: page px (the caller's textPx); `width`: wraps at this many px; `line`: line height in px; `shadow`: a hard
## dark outline for a text with no plate over the map (the Height corner)
static func label(layer: Layer3d, text: String, size: float, color: Color, width: float = -1.0, line: float = -1.0, shadow: bool = false) -> Label3D:
	var l := Label3D.new()
	var font := font()
	var dpr := layer.dpr
	l.text = text
	l.font = font
	l.font_size = roundi(size * dpr)
	l.pixel_size = 1.0 / dpr
	l.modulate = color
	# the web's soft dark halo of ink soaked into the paper (shadow rgba(60, 50, 30, 0.55), blur 2 px): one soft-edged
	# outline is the nearest a Label3D draws
	l.outline_modulate = Color(60 / 255.0, 50 / 255.0, 30 / 255.0, 0.55)
	l.outline_size = maxi(1, roundi(2 * dpr))
	var pad := PAD
	if shadow:
		# text.ts' shadow: a near-black stroke max(2, 0.16 size) wide holds the letters' edge on a light floor (Fernando,
		# Nov 18: the Height lost its plate); its room widens the box as the web's canvas pad does
		var stroke := maxf(2.0, size * 0.16)
		l.outline_modulate = Color(10 / 255.0, 8 / 255.0, 6 / 255.0, 0.92)
		l.outline_size = roundi(stroke * dpr)
		pad = 3 + stroke
	l.set_meta("halo", l.outline_modulate.a)
	l.no_depth_test = true
	l.shaded = false
	l.double_sided = true
	l.fixed_size = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lh:= line if line > 0 else size * 1.3
	var w:= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(size * dpr)).x / dpr
	var lines := 1
	if width > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = width * dpr
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var para := TextParagraph.new()
		para.add_string(text, font, roundi(size * dpr))
		para.width = width * dpr
		para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
		lines = para.get_line_count()
		w = 0.0
		for i in lines:
			w = maxf(w, para.get_line_width(i) / dpr)
		# a left-aligned Label3D starts its lines at its origin: shift them so the node stands at the box's middle, as the
		# web's text quad does
		l.offset = Vector2(-w / 2 * dpr, 0)
	l.line_spacing = (lh - font.get_height(roundi(size * dpr)) / dpr) * dpr
	l.set_meta("w", w + 2 * pad)
	l.set_meta("h", lines * lh + 2 * pad)
	return l


## the label's drawn width and height in page px, its scale included
static func w(l: Label3D) -> float:
	return l.get_meta("w") * l.scale.x


static func h(l: Label3D) -> float:
	return l.get_meta("h") * l.scale.y


## puts the label's middle at x, y (page px, y down) with its first glyph and its line on whole real pixels: a label
## straddling a pixel came out blurred and heavier than its neighbours (the web draws each text on its own canvas grid)
static func put(l: Label3D, x: float, y: float, dpr: float) -> void:
	var half := w(l) / 2
	l.position = Vector3(roundf((x - half) * dpr) / dpr + half, -roundf(y * dpr) / dpr, l.position.z)


## draws the label in priority `p` (the web's renderOrder) and its halo just under it: at the same priority Godot sorts
## the two at random and a halo drawn last greys the letters over it
static func order(l: Label3D, p: int) -> void:
	l.render_priority = p
	l.outline_render_priority = p - 1


static func alpha(l: Label3D, a: float) -> void:
	l.modulate.a = a
	l.outline_modulate.a = l.get_meta("halo", 0.55) * a

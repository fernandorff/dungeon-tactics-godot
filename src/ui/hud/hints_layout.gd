class_name HintsLayout
## Where the 3D banner, Height corner and key hints sit (port of the pure side of the web game's
## hints3d/hints-view.ts): the Height corner's box under the corner buttons, the places of a hint row's caps and texts,
## and the phone's smaller banner. Tested against the web's own numbers (tests/hints_tests.gd).

## sizes of a hint row in px of the 1920x1080 reference (layout-fft-ic.json dicas.direita): a 28 px cap so a key's
## letters reach 16 px, 22 px text, 4 px between caps, 12 px to the text and 40 px to the next hint
const ROW := {"cap": 28.0, "text": 22.0, "capGap": 4.0, "gap": 12.0, "between": 40.0}
const PHONE_MESSAGE := 0.7 # a phone's banner at 70% (Fernando, Nov 18: smaller messages on the phone)
const TAP := 44.0 # the corner buttons' least size (window3d/tools-layout.ts)
const GAP := 8.0


## the corner buttons' foot: what the Height corner keeps under (on a phone it sat under the menu button and Undo)
static func tools_foot(s: float, top: float) -> float:
	return top + maxf(TAP, QueueLayout.lu(56 * s)) + GAP


static func height_box(st: Dictionary, top: float) -> Rect2:
	var r := StageLayout.place("height", st)
	r.position.y = maxf(r.position.y, tools_foot(st.s, top))
	return r


static func message_scale(w: float, h: float) -> float:
	return PHONE_MESSAGE if minf(w, h) < StageLayout.TABLET_SIDE else 1.0


## each hint's caps' x and its text's x, from their widths ([{caps: [w...], text: w}]) in a box from `left`,
## `width_px` wide (floats: a Rect2 rounds to 32 bits). The right row ends on its
## box's right edge, the left one starts on its left edge; a row wider than its box closes the room between its hints
## down to the room between a cap and its text, so it still ends inside
static func lay_row(sizes: Array, left: float, width_px: float, align: String, s: float) -> Array:
	var width := func(h: Dictionary) -> float:
		var w := 0.0
		for c: float in h.caps:
			w += c + ROW.capGap * s
		return w - ROW.capGap * s + ROW.gap * s + h.text
	var content := 0.0
	for h: Dictionary in sizes:
		content += width.call(h)
	var spaces := maxi(1, sizes.size() - 1)
	var between := maxf(ROW.gap * s, minf(ROW.between * s, (width_px - content) / spaces))
	var total := content + between * (sizes.size() - 1)
	var x := left + width_px - total if align == "right" else left
	var out: Array = []
	for h: Dictionary in sizes:
		var caps: Array = []
		for c: float in h.caps:
			caps.append(x)
			x += c + ROW.capGap * s
		var text := x - ROW.capGap * s + ROW.gap * s
		x = text + h.text + between
		out.append({"caps": caps, "text": text})
	return out

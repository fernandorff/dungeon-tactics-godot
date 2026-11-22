class_name TalkLayout
## Where the 3D speech box puts its parts (port of the web game's window3d/talk-layout.ts): the box at the page's foot
## with Skip under it, the speaker's name on a plaque over its top left corner and the place's strip above; the opening
## narration (`dark`) has no box, its words stand in the page's middle. The box grows with the lines typed so far. Pure;
## tested against the web's own numbers (tests/talk_tests.gd).

const TAP := 44.0 # a finger's target (design system, section 8)
const EDGE := 16.0 # the page's margin


static func _keys_h() -> float:
	return QueueLayout.lu(17.6) # the hint's line


## spec: {pageW, pageH, safe: {top, right, bottom, left}, dark, face, name, title, skip (the words' widths, 0 without),
## lines: Callable(width, size) -> int (how many lines the words typed so far take)}
static func layout(q: Dictionary) -> Dictionary:
	var safe: Dictionary = q.safe
	var left := maxf(EDGE, safe.left)
	var right: float = q.pageW - maxf(EDGE, safe.right)
	var top := maxf(EDGE, safe.top)
	var foot: float = q.pageH - 24 - safe.bottom
	var w := minf(1100.0, right - left)
	var x := left + (right - left - w) / 2
	var skip_w := maxf(TAP, q.skip + 16)
	if q.dark:
		var size := 28.0
		var line := size * 1.5
		var tw := minf(34 * size, w - 48)
		var h := maxf(QueueLayout.lu(3.6 * size), q.lines.call(tw, size) * line)
		var y := top + (foot - top - h) / 2
		return {
			"box": Rect2(x, y, w, h), "text": {"x": x + (w - tw) / 2, "y": y, "w": tw}, "size": size, "line": line,
			"face": 0.0, "faceAt": null, "name": null, "title": null,
			"skip": Rect2(q.pageW - 24 - skip_w, foot - TAP, skip_w, TAP), # on the page's corner
			"keys": Vector2(x + w / 2, y + h + 28 - _keys_h() / 2), # the hint's middle, under the words
		}
	var size := 24.0
	var line := QueueLayout.lu(size * 1.35)
	var small: bool = q.pageW <= 560 # a phone: the face at half size and a line of its own for the hint
	var face := (66.0 if small else 132.0) if q.face else 0.0
	var tx := x + 16 + (face + 16 if face else 0.0)
	var tw := x + w - 42 - tx
	var h := maxf(132.0, 22 + (36 if small else 14) + maxf(maxf(face, QueueLayout.lu(3.6 * size)), q.lines.call(tw, size) * line))
	var y := foot - TAP - 12 - h
	return {
		"box": Rect2(x, y, w, h), "text": {"x": tx, "y": y + 20, "w": tw}, "size": size, "line": line, "face": face,
		"faceAt": Rect2(x + 16, y + 20, face, face) if face else null, # the face's frame, in the box's corner
		"name": Rect2(x + 12, y - 36, q.name + 40, 40) if q.face else null,
		"title": Rect2((left + right - q.title - 60) / 2, y - 96, q.title + 60, TAP) if q.title else null,
		"skip": Rect2(right - skip_w, foot - TAP, skip_w, TAP),
		"keys": Vector2(x + w - 42, y + h - 10 - _keys_h() / 2), # the hint's right end and middle
	}

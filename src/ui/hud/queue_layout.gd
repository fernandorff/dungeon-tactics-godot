class_name QueueLayout
## Where the 3D turn list and its cards sit (port of the web game's turn3d/queue-layout.ts and the sizes of
## queue-view.ts): the list's box on the page, each row's box in the list's scroll space, how far the list scrolls, and
## where the lines beside a card go. Pure; replayed against the web's numbers in tests/turn_tests.gd.

const TAP_MIN := 28.0 # the least a finger's target is tall
const HEAD := 22.0 # the pinned title: one 16 px line and its 6 px of padding
const TAP := 44.0 # a small card and the gap around it still give a finger 44 px (Fernando, Nov 20)
const SMALL := 0.6 # a repeat's card next to a first one (Fernando, Nov 20: "rosto menor")
const LIST_MIN := 0.9 # the list's scale at StageLayout.MIN_SCALE (1.5 of it: Turn3d)


## the web's layout unit: a 32-bit float cut to 1/64 px, as the browser hands a box
static func lu(v: float) -> float:
	var f: float = PackedFloat32Array([v])[0]
	return float(int(f * 64.0)) / 64.0


## JavaScript's Math.round: halves go up, also below zero (a row scrolled above the list's top)
static func round_js(v: float) -> float:
	return floorf(v + 0.5)


static func tap_grow(h: float) -> float:
	return maxf(0.0, ceilf((TAP_MIN - h) / 2))


## under LIST_MIN (a narrow page) the text and bar floors shrink with the list; a tablet's 14 px lifts them
static func list_floor(s: float, page: float = -1.0) -> float:
	var p := StageLayout.least if page < 0 else page
	return maxf(minf(1.0, s / LIST_MIN), p / 16.0)


static func _line_sizes(s: float) -> Dictionary:
	var f := list_floor(s)
	var size := maxf(16 * f, roundf(12 * s))
	return {"size": size, "line": size * 1.1, "bar": maxf(4 * f, roundf(4 * s)), "gap": maxf(2 * f, roundf(3 * s))}


## what `n` lines take, with a row of bars under each but the first when `bar`
static func lines_height(n: int, s: float, bar: bool) -> float:
	var z := _line_sizes(s)
	return n * z.line + (n - 1) * z.gap + ((n - 1) * z.bar if bar else 0.0)


## Where the lines sit beside a card `h` px tall, in px from the card's top: each line's middle and, with `bar`, the rows
## of bars: life and mana under the second line, stamina and CT under the third (Fernando, Nov 20)
static func stats_layout(h: float, s: float, n: int = 3, bar: Variant = null) -> Dictionary:
	var with_bar: bool = n > 1 if bar == null else bar
	var z := _line_sizes(s)
	var top := (h - lines_height(n, s, with_bar)) / 2
	var at := func(i: int) -> float: return top + i * (z.line + z.gap) + (maxi(0, i - 1) * z.bar if with_bar else 0.0)
	var lines: Array = []
	for i in n:
		lines.append(at.call(i) + z.line / 2)
	return {
		"size": z.size, "bar": z.bar, "x": maxf(6, 8 * s), "fits": top >= 0, "lines": lines,
		"hpBar": at.call(1) + z.line if with_bar else -1.0,
		"stBar": at.call(2) + z.line if with_bar and n > 2 else -1.0,
	}


## The width of the lines beside the cards, from each line's parts' widths (each with `pad` a side): a pair's second
## part starts on its second bar, so the bars take two columns as wide as the widest part, 4 px apart
static func stat_width(lines: Array, s: float, pad: float) -> float:
	var one := 0.0
	var col := 0.0
	for l: Array in lines:
		for w: float in l:
			if l.size() > 1:
				col = maxf(col, w)
			else:
				one = maxf(one, w)
	return maxf(one, 2 * col - 2 * pad + 4 * s if col else 0.0)


## `q`: {rows, now, s, at (Rect2, the turn region on the page), pageH, sheet, stats, small (Array of bool), margin,
## folded}. The column stacks from the bottom, 1 above the acting panel and counting up; a list longer than its box drops
## its top to the row that fits whole under the title (Fernando, Nov 18)
static func layout(q: Dictionary) -> Dictionary:
	var s: float = q.s
	var f := list_floor(s)
	var px := func(v: float) -> float: return lu(v * s)
	var gap: float = px.call(8)
	var small: Array = q.get("small", [])
	var folded: bool = q.get("folded", false)
	var size := func(now: bool, sm: bool) -> Vector2:
		var w := maxf((54.0 if now else 44.0) * s, (50.0 if now else 41.0) * f)
		var h := maxf(maxf((64.0 if now else 52.0) * s, (59.0 if now else 48.0) * f), 0.0 if folded else lines_height(3, s, true))
		var k := minf(1.0, maxf(SMALL, (TAP - gap) / h)) if sm else 1.0
		return Vector2(lu(w * k), lu(h * k))
	var pad := {"top": px.call(8), "right": px.call(10), "bottom": px.call(10), "left": px.call(56)}
	var at: Rect2 = q.at
	var page_h: float = q.pageH
	var left := lu(at.position.x)
	# it ends above the acting panel where that one is taller than the reference's
	var bottom := page_h - lu(maxf(page_h - at.position.y - at.size.y, q.sheet + 2))
	var sizes: Array = []
	for i: int in q.rows:
		sizes.append(size.call(q.now and i == 0, small[i] if i < small.size() else false))
	var head: float = pad.top + HEAD
	var width := lu(120 * s + q.stats)
	var top := lu(maxf(at.position.y, q.get("margin", at.position.y)))
	var room: float = bottom - top - head - pad.bottom
	var total := -gap
	for z: Vector2 in sizes:
		total += z.y + gap
	if total > room:
		var stack := 0.0
		for z: Vector2 in sizes:
			if stack + z.y + gap > room:
				break
			stack += z.y + gap
		top += floorf(room - stack)
	var height := bottom - top
	var y: float = height - pad.bottom
	var content: float = pad.top + HEAD + pad.bottom
	var rows: Array = []
	for z: Vector2 in sizes:
		y -= z.y
		rows.append(Rect2(round_js(pad.left), round_js(y), round_js(z.x), round_js(z.y)))
		y -= gap
		content += z.y + gap
	return {
		"rows": rows, "left": left, "top": top, "height": roundf(height), "head": head,
		"title": Vector2(left + pad.left + (width - pad.left - pad.right - q.stats) / 2, top + maxf(pad.top, y - HEAD) + 10),
		"more": maxf(0.0, roundf(content) - roundf(height)),
		"box": Rect2(left, top, width, height),
		"seat": {"width": width, "height": height, "gap": gap, "pad": pad, "sizes": sizes},
	}

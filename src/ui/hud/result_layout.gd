class_name ResultLayout
## Where the 3D battle result sits (port of the web game's result3d/result-layout.ts): the places measured on FFT: The
## Ivalice Chronicles' victory screen, around the `result` region. One layout for what is drawn and for the buttons over
## it. Pure; tested against the web's own numbers (tests/result_tests.gd).

## px on the 1920x1080 reference
const REF := {
	"title": 76.0, "note": 40.0, "head": 26.0, "row": 26.0, "name": 40.0, "button": 28.0, # text sizes
	"titleY": 218.0, # the title's middle
	"rule": {"x": 320.0, "y": 271.0, "w": 1280.0, "h": 2.0}, # the hairline under the title
	"noteY": 296.0, # the note's top; it wraps at the rule's width
	"noteLine": 50.0,
	"plate": 36.0, # a plate's height; both start 40 px under the band's top
	"plateY": 40.0,
	"left": 974.0, # the left plate's width; the right one takes the rest after the gap
	"gap": 68.0,
	"rowY": 116.0, # the first row's middle, from the band's top
	"rowH": 44.0,
	"inset": 27.0, # rows start this far inside their plate
	"heroes": 560.0, # the heroes' column's width when the spoils sit beside it
	"face": 38.0, # a hero's row (ours, the reference has none): the face, then name, class and life, the two columns
	"who": 48.0, # the name starts this far in, after the face
	"did": 22.0, # the columns' names, on the row above the first hero
	"dmg": 150.0, # the damage column's right end, from the row's right end
	"mvpY": 170.0, # the highlight's name and line, from the band's top
	"mvpLineY": 222.0,
	"mvpRuleY": 298.0,
	"buttonW": 280.0,
	"buttonH": 48.0,
	"buttonGap": 70.0, # room for the glove between two buttons
	"hand": 62.0, # the pointing glove
}


## `st`: the stage (StageLayout.stage); `page`: the page's width, which the band crosses whole. The band grows down past
## five rows. The buttons hold on to the bottom right corner, where the reference has its "Next", never under 44 px
static func layout(st: Dictionary, page: float, heroes: int, spoils: int, actions: int) -> Dictionary:
	var s: float = st.s
	var r: Dictionary = StageLayout.REGIONS.result
	var at := func(x: float, y: float, w: float = 0.0, h: float = 0.0) -> Rect2:
		return StageLayout.place_box({"at": r.at, "x": x, "y": y, "w": w, "h": h}, st)
	var rows := maxi(maxi(heroes + 1 if heroes else 0, spoils), 1) # the heroes' rows start under their columns' names
	var top: Rect2 = at.call(r.x, r.y)
	var h := maxf(r.h, REF.rowY + (rows - 1) * REF.rowH + REF.rowH) * s
	var left: Rect2 = at.call(r.x, r.y + REF.plateY, REF.left, REF.plate)
	var right: Rect2 = at.call(r.x + REF.left + REF.gap, r.y + REF.plateY, r.w - REF.left - REF.gap, REF.plate)
	var inner: float = REF.left - 2 * REF.inset
	var column := func(n: int, x: float, w: float, from: int = 0) -> Array:
		var out: Array = []
		for i in n:
			out.append(at.call(r.x + REF.inset + x, r.y + REF.rowY + (i + from - 0.5) * REF.rowH, w, REF.rowH))
		return out
	var hero_w: float = REF.heroes if spoils else inner
	var rows_of: Array = column.call(heroes, 0.0, hero_w, 1)
	var end: Rect2 = at.call(r.x + REF.inset + hero_w, r.y + REF.rowY)
	var hints := StageLayout.place("hints", st)
	var bw := maxf(160.0, REF.buttonW * s)
	var bh := maxf(44.0, REF.buttonH * s)
	var gap: float = REF.buttonGap * s
	var mid := right.position.x + right.size.x / 2
	var faces: Array = rows_of.map(func(b: Rect2) -> Rect2:
		return Rect2(b.position.x, b.position.y + b.size.y / 2 - REF.face * s / 2, REF.face * s, REF.face * s))
	var buttons: Array = []
	for i in actions:
		# on a short page the 44 px tap is taller than the hints row: kept on the page, 4 px over its bottom edge
		buttons.append(Rect2(hints.end.x - (actions - i) * bw - (actions - 1 - i) * gap, minf(hints.position.y + hints.size.y / 2 - bh / 2, st.y + st.h - bh - 4), bw, bh))
	return {
		"s": s,
		"band": Rect2(0, top.position.y, page, h),
		"title": Vector2(at.call(960.0, 0.0).position.x, at.call(0.0, REF.titleY).position.y),
		"rule": at.call(REF.rule.x, REF.rule.y, REF.rule.w, REF.rule.h),
		"note": {"x": at.call(960.0, 0.0).position.x, "y": at.call(0.0, REF.noteY).position.y, "w": REF.rule.w * s},
		"left": left,
		"right": right,
		"heroes": rows_of,
		"faces": faces,
		"who": REF.who * s,
		"did": {"y": end.position.y, "dmg": end.position.x - REF.dmg * s, "kills": end.position.x},
		"spoils": column.call(spoils, REF.heroes + 2 * REF.inset, inner - REF.heroes - 2 * REF.inset),
		"mvp": {"x": mid, "name": top.position.y + REF.mvpY * s, "line": top.position.y + REF.mvpLineY * s,
			"rule": Rect2(right.position.x + 18 * s, top.position.y + REF.mvpRuleY * s, right.size.x - 36 * s, 2 * s)},
		"buttons": buttons,
	}

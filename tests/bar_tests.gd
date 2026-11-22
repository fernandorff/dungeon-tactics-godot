class_name BarTests
## The 3D combat bar's pure parts against the web game's own numbers (tests/golden/bar.json, written by
## tools/export-bar.mjs from bar3d/bar-layout.ts): both sheets' boxes and spots, the plate and every hang.

var _golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/bar.json"))


static func _same(mine: Variant, web: Variant) -> bool:
	if mine is Rect2:
		var r: Rect2 = mine
		return MenuTests._box(r, web)
	if mine is Dictionary:
		for k: String in web:
			if not _same(mine.get(k, 0.0 if k == "max" else null), web[k]):
				return false
		return true
	if mine is float or mine is int:
		return MenuTests._near(mine, web)
	return mine == web


func test_sheet_layout_matches_web() -> String:
	for g: Dictionary in _golden.sheets:
		var mine := BarLayout.sheet(g.mirror)
		for k: String in g:
			if not _same(mine.get(k), g[k]):
				return "%s mirror=%s: %s, web %s" % [k, g.mirror, mine.get(k), g[k]]
	return "" if _same(BarLayout.PLATE, _golden.plate) else "PLATE differs from bar-layout.ts"


func test_hang_matches_web() -> String:
	for g: Dictionary in _golden.hangs:
		var sp: Dictionary = g.sp.duplicate()
		sp.max = sp.get("max", 0.0)
		var at := BarLayout.hang(sp, g.w, g.s, g.pad)
		if not MenuTests._near(at.x, g.out.x) or not MenuTests._near(at.k, g.out.k):
			return "hang %s, web %s for %s" % [at, g.out, g]
	return ""

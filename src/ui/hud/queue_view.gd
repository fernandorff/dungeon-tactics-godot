class_name QueueView
## Pure side of the 3D turn list (port of the web game's turn3d/queue-view.ts): what each card shows, from TurnRows'
## queue and the aimed strike, and which card each row of a redrawn list keeps. Tested in tests/turn_tests.gd.


static func _same(a: Dictionary, b: Dictionary) -> bool:
	return a.unit == b.unit and a.get("charge", "") == b.get("charge", "")


## For each row of the redrawn list, the index of the old row whose card it keeps, or -1 for a new card. A unit shows
## more than once (two rounds), so rows pair up in order. When the turn `passed`, the old head played and leaves
static func match_rows(prev: Array, next: Array, passed: bool) -> Array:
	var free: Array = range(prev.size()).slice(1 if passed else 0)
	var out: Array = []
	for row: Dictionary in next:
		var at := -1
		for j in free.size():
			if _same(prev[free[j]], row):
				at = j
				break
		out.append(-1 if at < 0 else free.pop_at(at))
	return out


## the list's head is the unit the 3D bar's sheet shows: its portrait is card 1, so the list starts at 2 (Nov 16)
static func head_on_sheet(q: Dictionary, sheet: String) -> bool:
	var rows: Array = q.get("rows", [])
	return sheet != "" and rows.size() > 0 and not rows[0].has("charge") and rows[0].unit == sheet


## which rows repeat a unit already listed (a charge's row is never one); the head counts
static func repeats(rows: Array) -> Array:
	var seen := {}
	var out: Array = []
	for r: Dictionary in rows:
		if r.has("charge"):
			out.append(false)
			continue
		out.append(seen.has(r.unit))
		seen[r.unit] = true
	return out


## The cards of a drawn list. The first row of each struck unit after the acting one takes the target mark; `fs`: the
## aimed strike on each target (BarView.forecast); `sheet`: the unit the bar's sheet shows
static func cards(b: Battle, q: Dictionary, fs: Array, sheet: String = "", folded: bool = false) -> Array:
	var rows: Array = q.get("rows", [])
	var again := repeats(rows)
	var struck := {}
	for f: Dictionary in fs:
		struck[f.unit.id] = f
	var marked := {}
	var ids := struck.keys()
	ids.append_array(q.get("targets", {}).keys())
	for id in ids:
		for i in range(1, rows.size()):
			if rows[i].unit == id and not rows[i].has("charge"):
				marked[i] = true
				break
	var out: Array = []
	for i in rows.size():
		var r: Dictionary = rows[i]
		var u := Combat.find_unit(b.state, r.unit)
		var most: float = Content.units[u.def].hp
		var f: Dictionary = struck.get(u.id, {})
		# a strike's worst case, a heal's best: the bar blinks between the life now and the life after
		var after: float = u.hp if f.is_empty() else (f.after[1] if not f.heal.is_empty() else f.after[0])
		var charge: String = r.get("charge", "")
		var stats: Variant = null
		if charge == "" and not folded:
			stats = {"lines": [Texts.unit_name(u.def)]} if again[i] else {"lines": TurnRows.card_lines(u), "bars": TurnRows.card_bars(u).slice(1)}
		var tip := ""
		if charge != "":
			tip = "%s · %s · %s" % [Texts.ability_name(charge), Texts.unit_name(u.def), Texts.t("resolve em %d", "resolves in %d") % r.get("ticks", 0)]
		else:
			tip = Texts.unit_name(u.def) + " · " + TurnRows.stats_text(u) + (Texts.t(" · alvo", " · target") if marked.has(i) else "")
		out.append({
			"id": {"unit": r.unit, "charge": charge}, "unit": u, "enemy": u.team == "enemy",
			"hp": Vector2(minf(u.hp, after) / most, maxf(u.hp, after) / most),
			"num": r.get("ticks", 0) if charge != "" else i + 1, "now": i == 0, "target": marked.has(i),
			"pending": i == q.get("at", -1), "small": again[i], "stats": stats, "tip": tip,
		})
	return out.slice(1) if head_on_sheet(q, sheet) else out

class_name ResultView
## What the end of a battle shows (port of the web game's result3d/result-view.ts), from the board the battle's end hands
## over: {won, title, cards: [[hero, [line, tone]]], cols: [[label, value]], note} (hero: Tally.end_heroes' row). Read
## the way FFT: The Ivalice Chronicles lays its victory out: the title, a line under it, what the battle gave and who did
## the most; the heroes' rows share the spoils' block. Pure.

const WOUNDED := 0.3 # under 30% of life a face is wounded (Portraits.expression_of)


## the face on the end row: the fallen hurt (greyed by the row), under 30% wounded, the rest smile on a victory and stay
## neutral on a defeat (battle-face.ts endExpression: here the victory smile does not beat wounded)
static func end_expression(hp: int, max_hp: int, won: bool) -> String:
	if hp <= 0:
		return "hurt"
	if hp < max_hp * WOUNDED:
		return "wounded"
	return "smile" if won else "neutral"


static func of(b: Dictionary, actions: Array) -> Dictionary:
	var best: Array = []
	var heroes: Array = []
	for card: Array in b.cards:
		var h: Dictionary = card[0]
		var line: Array = card[1]
		if h.mvp and best.is_empty():
			best = card
		var base := Roster.class_of(h.def)
		var name := Texts.unit_name(h.def)
		heroes.append({
			"def": h.def, "face": end_expression(h.hp, h.max, b.won), "name": name,
			"cls": Texts.unit_name(base) if base != "" and Texts.unit_name(base) != name else "", # only for a named hero
			"life": "%d/%d" % [h.hp, h.max],
			"line": line[0] if line[1] != "" else "", # the plain line is the damage and takedowns the columns say
			"tone": line[1], "dmg": str(h.dmg), "kills": str(h.kills),
		})
	return {
		"won": b.won,
		"title": String(b.title).to_upper(),
		"note": b.note,
		"heads": [Texts.t("Resultado", "Result").to_upper(), Texts.t("Destaque", "MVP").to_upper()],
		"did": [Texts.t("Dano", "Damage"), Texts.t("Derrubados", "Takedowns")],
		"heroes": heroes,
		"spoils": b.cols,
		"mvp": {"name": Texts.unit_name(best[0].def), "line": best[1][0]} if not best.is_empty() else null,
		"actions": actions,
	}

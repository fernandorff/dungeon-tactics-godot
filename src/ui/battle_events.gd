class_name BattleEvents
## Plays a battle's events on the view in order (port of unit-events.ts and the numbers of hit-weight.ts): walks tweened,
## and the floating numbers and words over the units. The rule is already applied; this only reads what happened.

const PHYS := Color("#ffffff")
const MAGIC := Color("#d7a6ff")
const HEAL := Color("#6fdc8c")
const MISS := Color("#bdbdbd")
const BIG := 0.25 # a strike of 25% of life or more is strong: bigger number, gold edge
const WORD_PX := 26 # a word (Miss, an effect) at the web float's default size
const STEP_S := 0.09 # view.walk's time per tile: keep the two equal or the steps drift off the feet


## the number's size in px, by the share of life it takes (numberPx): 18 to 56, x1.4 when strong
static func number_px(amount: int, most: int, strong: bool) -> int:
	return roundi(minf(56.0, 18.0 + 80.0 * amount / maxf(1.0, most)) * (1.4 if strong else 1.0))


## only an attack's hit can be strong: a fall, a bump or spikes are not one, or a 2-level fall always would be
static func is_big(e: Dictionary, most: int) -> bool:
	return e.k == "hit" and e.dmg >= most * BIG


static func _max_hp(view: BattleView, unit: String) -> int:
	var def: String = view.def_of(unit)
	return Content.units[def].hp if def != "" else 1


## a footstep at the start of each tile walked after the first, in time with view.walk's tween
static func _steps(view: BattleView, tiles: int) -> void:
	var tw := view.create_tween()
	for i in range(1, tiles):
		tw.tween_interval(STEP_S)
		tw.tween_callback(Sound.play.bind("step"))


static func play(view: BattleView, events: Array) -> void:
	var magic := false # a hit names no ability: the last attack says if it was magic (violet, with a ✦)
	for e in events:
		Sound.for_event(e)
		match e.k:
			"move":
				_steps(view, e.path.size())
				await view.walk(e.unit, e.path)
			"attack":
				Sound.play(Sound.attack_kind(e.ability))
				magic = Content.abilities[e.ability].get("magic", false)
			"hit", "bump", "fall", "spike":
				var most := _max_hp(view, e.unit)
				var big := is_big(e, most)
				var star: bool = e.k == "hit" and magic
				view.float_text(e.unit, "-%d%s" % [e.dmg, " ✦" if star else ""], MAGIC if star else PHYS, number_px(e.dmg, most, big), big)
				await view.get_tree().create_timer(0.25).timeout
			"miss":
				view.float_text(e.unit, Texts.t("Errou", "Miss"), MISS, WORD_PX)
				await view.get_tree().create_timer(0.2).timeout
			"effect":
				# an ability's effect says its word, as a miss says Miss (Nov 21: stunned, blinded, focused); items stay quiet
				if Content.abilities.has(e.item):
					view.float_text(e.unit, Texts.effect_word(e.item), MISS, WORD_PX)
					await view.get_tree().create_timer(0.25).timeout
			"heal", "regen":
				view.float_text(e.unit, "+%d" % e.amount, HEAL, number_px(e.amount, _max_hp(view, e.unit), false))
			"die":
				await view.get_tree().create_timer(0.2).timeout

class_name Slots
## The turn's two action slots (port of action-slots.ts): a main action and a secondary (bonus) one.


## the ability's own field, else no damage means bonus and the rest main
static func kind_of(a: Dictionary) -> String:
	if a.has("action"):
		return a.action
	return "bonus" if a.damage[1] == 0 else "main"


## the slot an action of this kind would fill now, or "" when none is free
static func free_slot(turn: Dictionary, kind: String) -> String:
	if kind == "main":
		return "" if turn.main != null else "main"
	if turn.bonus == null:
		return "bonus"
	return "main" if turn.main == null else ""


## the slot `a` fills now; `as_slot` the one the player picked ("" for none)
static func slot_for(turn: Dictionary, a: Dictionary, as_slot: String = "") -> String:
	var kind := kind_of(a)
	if not a.has("bonusShare"):
		return "" if as_slot == "bonus" and kind == "main" else free_slot(turn, kind)
	if as_slot != "":
		return "" if turn[as_slot] != null else as_slot
	if turn.main == null:
		return "main"
	return "bonus" if turn.bonus == null else ""


static func slot_scale(a: Dictionary, slot: String) -> float:
	return a.bonusShare / 100.0 if slot == "bonus" and a.has("bonusShare") else 1.0

class_name HintRows
## Pure side of the key hints and the Height corner (port of the web game's hints3d/hints-view.ts): what Confirm and
## Cancel do on each turn screen, the camera and the menu, with the port's keys (main.gd's input map). A hint is
## [[caps], text].

const CONFIRM := ["Enter"]
const CANCEL := ["Esc"]
const CAMERA := ["Q", "E"]
const INFO := ["I"]
const MENU := ["P"]


static func _confirm_text(s: Dictionary) -> String:
	if s.k == "menu":
		return Texts.t("Escolher", "Select")
	if s.k == "map" and s.get("command", "") == "move":
		return Texts.t("Mover", "Move")
	if s.k == "facing":
		return Texts.t("Passar a vez", "End Turn")
	return Texts.t("Confirmar", "Confirm")


## the foot's hints: on the right what Confirm and Cancel do now and the camera (the pages on the action list), on the
## left the menu. `open`: a hero's turn with nothing playing; while the battle plays, holding Confirm speeds it up
static func hints_for(b: Battle, s: Dictionary, open: bool) -> Dictionary:
	if b.over():
		return {"left": [], "right": []}
	var left := [[MENU, Texts.t("Opções", "Options")]]
	var camera := [CAMERA, Texts.t("Câmera", "Camera")]
	if not open:
		return {"left": left, "right": [[CONFIRM, Texts.t("Segure: acelerar", "Hold: Speed Up")], camera]}
	var right := [[CONFIRM, _confirm_text(s)]]
	var back: Variant = Command.cancel_step(b, s)
	if typeof(back) == TYPE_STRING:
		right.append([CANCEL, Texts.t("Desfazer", "Undo")])
	elif not back.is_empty():
		right.append([CANCEL, Texts.t("Cancelar", "Cancel")])
	elif s.k == "menu":
		right.append([CANCEL, Texts.t("Opções", "Options")])
	right.append([INFO, Texts.t("Detalhes", "Details")] if s.k == "actions" else camera)
	return {"left": left, "right": right}


## the Height corner's number: the tile under the cursor; -1 hides it (the battle is over, or the action list's sheet
## takes that corner)
static func height_shown(b: Battle, s: Dictionary, cursor: Vector2i) -> int:
	if b.over() or s.k == "actions" or not b.grid.in_bounds(cursor):
		return -1
	return HudBits.tile_height(b.grid, cursor)

class_name EndScreen
extends Control
## The board after a room (port of game/end-board.ts): what the room was worth, the expedition so far, and the way on —
## the map while the expedition lives, the town when it ended.

var main: Main
var settled: Dictionary


func _init(m: Main, s: Dictionary) -> void:
	main = m
	settled = s


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var next: Variant = settled.next
	var n: Dictionary = settled.node
	var title: String
	if next == null:
		title = Texts.t("Expedição perdida", "Expedition lost")
	elif settled.done:
		title = Texts.t("Expedição concluída!", "Expedition complete!")
	elif settled.down:
		title = Texts.t("Andar %d vencido!", "Floor %d cleared!") % n.floor
	else:
		title = Texts.t("Sala vencida!", "Room cleared!")
	var v := Kit.page(self, title)
	var g: Dictionary = settled.gold
	var rows := [
		[Texts.t("Andar", "Floor"), str(n.floor)],
		[Texts.t("Salas vencidas", "Rooms cleared"), str(next.path.size() if next != null else 0)],
		[Texts.t("Ouro da sala", "Room gold"), str(g.room)],
		[Texts.t("Ouro achado", "Gold found"), str(g.found)],
	]
	if next == null or settled.done:
		rows.append([Texts.t("Ouro para a cidade", "Gold to town"), str(g.banked)])
	for r in rows:
		var h := HBoxContainer.new()
		var a := Kit.label(r[0], 17, Kit.MUTED)
		a.size_flags_horizontal = SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(Kit.label(r[1], 17, Kit.ACCENT))
		v.add_child(h)
	var go_on: bool = next != null and not settled.done
	var b := Kit.button(Texts.t("Seguir no mapa", "On to the map") if go_on else Texts.t("Voltar à cidade", "Back to town"), main.expedition_map if go_on else main.town)
	v.add_child(b)
	b.call_deferred("grab_focus")

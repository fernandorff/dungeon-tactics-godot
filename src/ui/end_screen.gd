class_name EndScreen
extends Control
## The board after a room (port of game/room-end.ts finishRoom): what the room was worth, the expedition so far, what
## the party recovers, and the way on — the map while the expedition lives, the town when it ended.

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
	var r := Expedition.run()
	var floors: int = r.floors
	var rows := [[Texts.t("Andar", "Floor"), Texts.t("%d de %d" % [n.floor, floors], "%d of %d" % [n.floor, floors])]]
	if next != null:
		var map: Array = settled.map
		rows.append([Texts.t("Salas vencidas", "Rooms cleared"), str(next.path.filter(func(i: int) -> bool: return not map[i].chest).size())])
		rows.append([Texts.t("Ouro da sala", "Room gold"), "+%d" % g.room])
	rows.append([Texts.t("Ouro achado", "Gold found"), str(g.found)])
	if next == null or settled.done:
		rows.append([Texts.t("Ouro para a cidade", "Gold to town"), str(g.banked)])
	for row in rows:
		var h := HBoxContainer.new()
		var a := Kit.label(row[0], 17, Kit.MUTED)
		a.size_flags_horizontal = SIZE_EXPAND_FILL
		h.add_child(a)
		var value := Kit.label(row[1], 17, Kit.ACCENT)
		value.autowrap_mode = TextServer.AUTOWRAP_OFF # "1 de 3" broke a letter a line beside the label
		h.add_child(value)
		v.add_child(h)
	var stood := int(r.roomHeal)
	var fallen := int(r.fallen)
	var note: String
	if next == null:
		note = Texts.t("O grupo caiu no andar %d. Os feridos voltam à cidade com metade do ouro achado." % n.floor, "The party fell on floor %d. The wounded return to town with half the gold found." % n.floor)
	elif settled.done:
		note = Texts.t("O chefe da masmorra caiu. O grupo volta à cidade com todo o ouro achado.", "The dungeon’s boss fell. The party returns to town with all the gold found.")
	elif settled.down:
		var heal := int(r.floorHeal)
		note = Texts.t("Quem ficou de pé recupera %d%% da vida e quem caiu volta com %d%%; ao descer ao andar %d, todos recuperam mais %d%%." % [stood, fallen, n.floor + 1, heal],
			"Whoever stood recovers %d%% of their life and the fallen come back at %d%%; going down to floor %d, everyone recovers %d%% more." % [stood, fallen, n.floor + 1, heal])
	else:
		note = Texts.t("Quem ficou de pé recupera %d%% da vida; quem caiu volta com %d%%." % [stood, fallen], "Whoever stood recovers %d%% of their life; the fallen come back at %d%%." % [stood, fallen])
	v.add_child(Kit.label(note, 16))
	var go_on: bool = next != null and not settled.done
	var b := Kit.button(Texts.t("Seguir no mapa", "On to the map") if go_on else Texts.t("Voltar à cidade", "Back to town"), _onward)
	v.add_child(b)
	b.call_deferred("grab_focus")


## on to the map while the expedition goes on, else the town
func _onward() -> void:
	if settled.next != null and not settled.done:
		main.expedition_map()
	else:
		main.town()


func _unhandled_input(ev: InputEvent) -> void:
	# Esc goes the same way: closing only left the finished room on screen
	if ev.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_onward()

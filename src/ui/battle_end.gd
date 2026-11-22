class_name BattleEnd
## The boards the end of a battle hands to Result3d (port of the web game's game/end-screens.ts battleEndScreen and
## game/room-end.ts finishRoom): a standalone battle's or Until Dawn's, and an expedition room's, which the save has
## already settled (CrawlFlow.settle_room). `heroes`: Tally.end_heroes' rows. Actions: [[label, Callable]], the primary
## first, where the focus starts.


## a standalone battle or Until Dawn (`survival`: [lasted, best], else []): the same battle again, or `away`
static func battle(won: bool, survival: Array, heroes: Array, again: Callable, away: Array) -> Dictionary:
	var note: String
	if not survival.is_empty():
		note = Texts.t("O sol nasceu e os heróis ainda estavam de pé.", "The sun rose and the heroes were still standing.") if won else Texts.t("Os heróis tombaram antes do amanhecer.", "The heroes fell before dawn.")
	else:
		note = Texts.t("Todos os inimigos caíram e o Farol resistiu.", "Every enemy fell and the Beacon held.") if won else Texts.t("O Farol caiu ou os heróis tombaram.", "The Beacon fell or the heroes were defeated.")
	var cols: Array = []
	if not survival.is_empty():
		var lasted: int = survival[0]
		var best: int = survival[1]
		cols = [
			[Texts.t("Turnos", "Turns"), Texts.t("%d de %d" % [lasted, Survival.SURVIVE_TURNS], "%d of %d" % [lasted, Survival.SURVIVE_TURNS])],
			[Texts.t("Recorde", "Record"), Texts.t("%d, novo!" % lasted, "%d, new!" % lasted) if lasted > best else str(best)],
		]
	return {
		"won": won,
		"title": Texts.t("Vitória!", "Victory!") if won else Texts.t("Derrota", "Defeat"),
		"cards": heroes.map(func(h: Dictionary) -> Array: return [h, Tally.tally_line(h)]),
		"cols": cols,
		"note": note,
		# a defeat offers the same battle again, like FFT's retry
		"actions": [[Texts.t("Jogar de novo", "Play again") if won else Texts.t("Tentar de novo", "Try again"), again], away],
	}


## an expedition room: on to the map while the expedition lives, else the town. Each hero's line says the life it takes
## into the next room (the recovery already applied). `room`: CrawlFlow's {node, heroes}; `onward`: where the button goes
static func room(settled: Dictionary, heroes: Array, room: Dictionary, onward: Callable) -> Dictionary:
	var next: Variant = settled.next
	var done: bool = settled.done
	var n: Dictionary = settled.node
	var g: Dictionary = settled.gold
	var r := Expedition.run()
	var floors: int = r.floors
	var title: String
	if next == null:
		title = Texts.t("Expedição perdida", "Expedition lost")
	elif done:
		title = Texts.t("Expedição concluída!", "Expedition complete!")
	elif settled.down:
		title = Texts.t("Andar %d vencido!", "Floor %d cleared!") % n.floor
	else:
		title = Texts.t("Sala vencida!", "Room cleared!")
	var cols := [[Texts.t("Andar", "Floor"), Texts.t("%d de %d" % [n.floor, floors], "%d of %d" % [n.floor, floors])]]
	if next != null:
		var map: Array = settled.map
		cols.append([Texts.t("Salas vencidas", "Rooms cleared"), str(next.path.filter(func(i: int) -> bool: return not map[i].chest).size())])
		cols.append([Texts.t("Ouro da sala", "Room gold"), "+%d" % g.room])
	cols.append([Texts.t("Ouro achado", "Gold found"), str(g.found)])
	if next == null or done:
		cols.append([Texts.t("Ouro para a cidade", "Gold to town"), str(g.banked)])
	var stood := int(r.roomHeal)
	var fallen := int(r.fallen)
	var note: String
	if next == null:
		note = Texts.t("O grupo caiu no andar %d. Os feridos voltam à cidade com metade do ouro achado." % n.floor, "The party fell on floor %d. The wounded return to town with half the gold found." % n.floor)
	elif done:
		note = Texts.t("O chefe da masmorra caiu. O grupo volta à cidade com todo o ouro achado.", "The dungeon’s boss fell. The party returns to town with all the gold found.")
	elif settled.down:
		var heal := int(r.floorHeal)
		note = Texts.t("Quem ficou de pé recupera %d%% da vida e quem caiu volta com %d%%; ao descer ao andar %d, todos recuperam mais %d%%." % [stood, fallen, n.floor + 1, heal],
			"Whoever stood recovers %d%% of their life and the fallen come back at %d%%; going down to floor %d, everyone recovers %d%% more." % [stood, fallen, n.floor + 1, heal])
	else:
		note = Texts.t("Quem ficou de pé recupera %d%% da vida; quem caiu volta com %d%%." % [stood, fallen], "Whoever stood recovers %d%% of their life; the fallen come back at %d%%." % [stood, fallen])
	var go_on: bool = next != null and not done
	var cards: Array = []
	for h: Dictionary in heroes:
		var carried: Variant = null
		if go_on and room.heroes.has(h.id):
			for p: Dictionary in next.party:
				if p.id == room.heroes[h.id].id:
					carried = p
		cards.append([h, Tally.room_line(h, carried)])
	return {
		"won": next != null, # a cleared room and a won expedition get the victory's look
		"title": title, "cards": cards, "cols": cols, "note": note,
		"actions": [[Texts.t("Seguir no mapa", "On to the map") if go_on else Texts.t("Voltar à cidade", "Back to town"), onward]],
		"back": onward, # Esc goes the same way: closing only left the finished room on screen
	}

class_name Notices
## The notice windows of the town and the expedition (port of game/notices.ts): the map's Information and opened chest,
## the expedition lost and a room that would not open. Each opens a Notice over `parent`.


## Information (FFT's map command): what the chart's marks mean and what the descent's rules give and take
static func info(parent: Control, back: Callable) -> Notice:
	var r := Expedition.run()
	var legend := [
		[{"glyph": "3", "look": "open"}, Texts.t("Sala aberta: o número é quantos inimigos ela tem", "Open room: the number is how many enemies it holds")],
		[{"glyph": "3", "look": "ahead"}, Texts.t("Sala mais adiante: abre depois da anterior", "Room further on: opens after the one before")],
		[{"glyph": "", "look": "open", "kind": "chest"}, Texts.t("Baú: ouro sem batalha", "Chest: gold with no battle")],
		[{"glyph": "", "look": "ahead", "kind": "boss"}, Texts.t("Chefe: a última sala", "Boss: the last room")],
		[{"glyph": "✓", "look": "cleared"}, Texts.t("Sala vencida ou baú aberto", "Room cleared or chest opened")],
		[{"glyph": "✕", "look": "skipped"}, Texts.t("Caminho não tomado: não abre mais", "Path not taken: it will not open")],
		[{"glyph": "", "look": "flag"}, Texts.t("Onde o grupo está", "Where the party is")],
	]
	var room := int(r.roomHeal)
	var fallen := int(r.fallen)
	var down := int(r.floorHeal)
	var text := [
		Texts.t("Vencer uma sala: quem ficou de pé recupera %d%% da vida e da mana, quem caiu volta com %d%%. Descer um andar: +%d%% para todos." % [room, fallen, down],
			"Clearing a room: whoever stood recovers %d%% of their life and mana, the fallen come back at %d%%. Going down a floor: +%d%% to everyone." % [room, fallen, down]),
		Texts.t("Voltar à cidade pelo mapa leva todo o ouro achado. Cair ou deixar uma sala no meio da luta encerra a expedição com metade dele.",
			"Going back to town from the map takes all the gold found. Falling or leaving a room mid-fight ends the expedition with half of it."),
	]
	return Notice.open(parent, {"title": Texts.t("Informações", "Information"), "legend": legend, "text": text, "buttons": [[Texts.t("Voltar ao mapa", "Back to the map"), back]], "on_back": back})


## the chest just opened (already saved): its gold over the map
static func chest(parent: Control, gold: int) -> Notice:
	return Notice.open(parent, {"title": Texts.t("Baú aberto", "Chest opened"), "figure": [Texts.t("Ouro", "Gold"), str(gold)], "buttons": [[Texts.t("Seguir no mapa", "On to the map"), Callable()]]})


## the expedition ended by leaving a room mid-fight: half the gold to town
static func lost(parent: Control, kept: int, then: Callable) -> Notice:
	var says := Texts.t("O grupo deixou a sala no meio da luta. A expedição acabou, e metade do ouro achado vai à cidade.",
		"The party left the room mid-fight. The expedition is over, and half the gold found goes to town.")
	return Notice.open(parent, {"title": Texts.t("Expedição perdida", "Expedition lost"), "text": [says], "figure": [Texts.t("Ouro para a cidade", "Gold to town"), str(kept)], "buttons": [[Texts.t("Voltar à cidade", "Back to town"), then]], "on_back": then})


## the room asked for could not be built: said in town, where the game went
static func no_room(parent: Control, then: Callable) -> Notice:
	var says := Texts.t("Não deu para abrir esta sala. Você voltou para a cidade.", "This room wouldn’t open. You are back in town.")
	return Notice.open(parent, {"title": Texts.t("A sala não abriu", "The room did not open"), "text": [says], "buttons": [[Texts.t("Voltar à cidade", "Back to town"), then]], "on_back": then})

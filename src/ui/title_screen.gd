class_name TitleScreen
extends Control
## The title (port of game/title.ts): Continue (the save slots), New game, Quick battle (the maps with a Beacon and Until
## Dawn), How to play, Options, Credits.

const QUICK_MAPS := ["beacon_hill", "skirmish", "flooded_crypt", "crypt_heart"]

var main: Main


func _init(m: Main) -> void:
	main = m


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_menu()


func _clear() -> VBoxContainer:
	for c in get_children():
		c.queue_free()
	return Kit.page(self, "Dungeon Tactics")


func _menu() -> void:
	var v := _clear()
	v.add_child(Kit.label(Texts.t("Táticas por turnos: cidade, descida, acampamento e volta.", "Turn-based tactics: town, descent, camp and return."), 16, Kit.MUTED))
	var slots: Array = Saves.read_saves().slots
	var first: Button
	if slots.size():
		first = Kit.button(Texts.t("Continuar (%d jogos salvos)", "Continue (%d saved games)") % slots.size(), _continue)
		v.add_child(first)
	var ng := Kit.button(Texts.t("Novo jogo", "New game"), func() -> void:
		Saves.new_game(int(Time.get_unix_time_from_system() * 1000))
		main.home())
	v.add_child(ng)
	v.add_child(Kit.button(Texts.t("Batalha avulsa", "Quick battle"), _quick))
	v.add_child(Kit.button(Texts.t("Como jogar", "How to play"), _how))
	v.add_child(Kit.button(Texts.t("Opções", "Options"), func() -> void: OptionsWindow.open(self, _menu)))
	v.add_child(Kit.button(Texts.t("Créditos", "Credits"), _credits))
	v.add_child(Kit.button(Texts.t("Sair", "Quit"), func() -> void: get_tree().quit()))
	(first if first else ng).call_deferred("grab_focus")


func _continue() -> void:
	var v := _clear()
	v.add_child(Kit.label(Texts.t("Continuar", "Continue"), 22))
	var rows: Array = Saves.read_saves().slots.map(func(s: Dictionary) -> Dictionary: return Saves.summary(s))
	rows = Util.stable_sort(rows, Saves.by_played)
	var first: Button
	for s in rows:
		var where: String = Texts.t("na cidade", "in town") if s.floor == null else Texts.t("andar %d", "floor %d") % s.floor
		if s.room:
			where += Texts.t(", numa sala", ", in a room")
		var when := ""
		if s.played != null:
			when = " · " + Time.get_datetime_string_from_unix_time(int(s.played / 1000), true).left(16)
		var id: int = s.id
		var h := HBoxContainer.new()
		var load := Kit.button("%s · %d %s · %s%s" % [", ".join(s.names), s.gold, Texts.t("de ouro", "gold"), where, when], func() -> void:
			Saves.load_slot(id)
			_resume())
		load.size_flags_horizontal = SIZE_EXPAND_FILL
		h.add_child(load)
		h.add_child(Kit.button(Texts.t("Apagar", "Delete"), func() -> void: _delete(id)))
		v.add_child(h)
		if first == null:
			first = load
	var back := Kit.button(Texts.t("Voltar", "Back"), _menu)
	v.add_child(back)
	(first if first else back).call_deferred("grab_focus")


## a loaded game with a room battle saved reopens that room; else the town
func _resume() -> void:
	var exp: Variant = CrawlFlow.saved_expedition()
	var held: Variant = Store.json(Saves.ROOM_KEY)
	if exp != null and typeof(held) == TYPE_DICTIONARY:
		var map := Expedition.map_of(exp.seed)
		for n in Expedition.open_nodes(map, exp.path):
			var id := CrawlGen.room_id(map[n].seed, {"depth": map[n].floor, "boss": map[n].boss}) + Content.HALF
			if held.get("state", {}).get("scenario") == id:
				main.room(n)
				return
	main.home()


func _delete(id: int) -> void:
	Kit.dialog(self, Texts.t("Apagar este jogo?", "Delete this game?"), Texts.t("Não dá para desfazer.", "This cannot be undone."), [
		[Texts.t("Apagar", "Delete"), func() -> void:
			Saves.delete_slot(id)
			_continue()],
		[Texts.t("Cancelar", "Cancel"), _continue],
	])


func _quick() -> void:
	var v := _clear()
	v.add_child(Kit.label(Texts.t("Batalha avulsa", "Quick battle"), 22))
	var first: Button
	for id in QUICK_MAPS:
		var sc: Dictionary = Content.scenarios[id]
		var map_id: String = id
		var b := Kit.button(Texts.t(sc.name, sc.en), func() -> void: main.skirmish(map_id))
		v.add_child(b)
		if first == null:
			first = b
	var best := Survival.best()
	v.add_child(Kit.button(Texts.t("Até o amanhecer: resistir no Bosque", "Until Dawn: hold out in the Wood") + (Texts.t(" (recorde %d)", " (record %d)") % best if best else ""), main.survival))
	v.add_child(Kit.button(Texts.t("Voltar", "Back"), _menu))
	first.call_deferred("grab_focus")


func _how() -> void:
	var v := _clear()
	var r: Dictionary = Content.data.crawl.run
	var parts := [
		[Texts.t("Turno e fila", "Turn and queue"), Texts.t("A lista de turnos (canto de cima) mostra quem joga a seguir. Quem é mais rápido joga mais vezes. Na sua vez: Agir e Mover, em qualquer ordem; depois de agir ainda se anda com o movimento que sobrou. Nas batalhas avulsas, proteja o Farol quando houver um.", "The turn list (top corner) shows who acts next. Faster units act more often. On your turn: Act and Move, in any order; after acting you can still walk with the movement left. In quick battles, protect the Beacon when there is one.")],
		[Texts.t("Posição e altura", "Position and height"), Texts.t("Do alto se acerta mais e se alcança mais longe; entulho protege de ataques de longe e árvore não se atravessa. Golpe pelo lado acerta mais, pelas costas mais ainda (F escolhe para onde olhar).", "From high ground you hit more and reach farther; rubble covers you from ranged attacks and trees block the way. Hits from the side land more often, from behind even more (F picks where to face).")],
		[Texts.t("Empurrões, espinhos e água", "Pushes, spikes and water"), Texts.t("Empurrar contra muro ou alguém fere; empurrar do alto também. Espinhos ferem quem é jogado neles ou termina a vez em cima. Na água funda só se anda ou espera.", "Pushing into a wall or someone hurts; pushing someone off high ground too. Spikes hurt whoever is pushed onto them or ends a turn on them. In deep water you can only move or wait.")],
		[Texts.t("Cargas", "Charges"), Texts.t("Habilidade com carga sai depois: a área roxa mostra onde vai cair. Começar a carga gasta metade do movimento que sobrou. Mirando alguém, você trava no personagem ou na casa.", "Charged abilities land later: the purple area shows where. Starting a charge costs half the movement left. Aiming at someone, you lock on the character or on the tile.")],
		[Texts.t("Contra-ataque", "Counter-attacks"), Texts.t("Quem você golpeia direto contra-ataca pela metade se o ataque básico dele é de alvo único, no resto do seu turno: cada movimento que sai do alcance dele leva um golpe. As paradas que causam contra-ataque ficam em rosa.", "Whoever you strike directly strikes back at half if its basic attack is single-target, for the rest of your turn: each move that leaves its reach draws a blow. Stops that draw a counter show in pink.")],
		[Texts.t("Cidade e expedição", "Town and expedition"), Texts.t("Na cidade se anda com WASD, as setas ou o analógico; Enter ou A fala ou entra. A Guilda abre o Grupo, a Loja compra e vende, a Taverna recruta e o Portão inicia a expedição. A expedição tem %d andares de %d fileiras de salas; depois do último andar vem o chefe. Ao vencer, quem ficou de pé ganha %d%% da vida e quem caiu volta com %d%%; ao descer de andar, todos ganham %d%%. Sair da sala antes do fim perde a expedição.", "In town you walk with WASD, the arrows or the stick; Enter or A talks or goes in. The Guild opens the Party, the Shop buys and sells, the Tavern recruits and the Gate starts the expedition. The expedition has %d floors of %d rows of rooms; after the last floor comes the boss. On a win, whoever stood gains %d%% of life and the fallen come back at %d%%; going down a floor, everyone gains %d%%. Leaving a room before it ends loses the expedition.") % [r.floors, r.rows, r.roomHeal, r.fallen, r.floorHeal]],
	]
	v.add_child(Kit.label(Texts.t("Como jogar", "How to play"), 22))
	for p in parts:
		v.add_child(Kit.label(p[0], 18, Kit.ACCENT))
		v.add_child(Kit.label(p[1], 15))
	var back := Kit.button(Texts.t("Voltar", "Back"), _menu)
	v.add_child(back)
	back.call_deferred("grab_focus")


func _credits() -> void:
	var v := _clear()
	v.add_child(Kit.label(Texts.t("Créditos", "Credits"), 22))
	v.add_child(Kit.label(Texts.t("História, mapas e regras: Dungeon Tactics. Porte para Godot 4 em GDScript; visual simples (caixas e cápsulas).", "Story, maps and rules: Dungeon Tactics. Port to Godot 4 in GDScript; simple look (boxes and capsules)."), 15))
	var back := Kit.button(Texts.t("Voltar", "Back"), _menu)
	v.add_child(back)
	back.call_deferred("grab_focus")

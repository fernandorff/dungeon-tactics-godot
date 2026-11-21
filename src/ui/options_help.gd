class_name OptionsHelp
## What Options explains instead of setting (port of options-help.ts): the tile marks' legend and the controls, each on a
## parchment sheet over the window; Back or Esc closes it and puts the cursor back on its row.

const PARCHMENT := Color("#ece4cc")
const INK := Color("#3a3020")
# the marks' own colours (scene/mark-looks.ts MARK), so the legend's squares match the board
const MARKS := [
	["#6fc0ff", "Azul, moldura lisa: onde o herói pode andar", "Blue, plain frame: where the hero can move"],
	["#ff7a3c", "Laranja, listras: alcance da habilidade", "Orange, stripes: ability range"],
	["#b07ae0", "Roxo, xis: no alcance, mas sem visão", "Purple, cross: in range, but no sight"],
	["#ff2d55", "Vermelho, listras: o que a unidade tocada alcança", "Red, stripes: what the tapped unit can reach"],
	["#ff4040", "Vermelho, xis: a unidade não cabe ali", "Red, cross: the unit does not fit there"],
	["#ff3b3b", "Vermelho, moldura lisa: parar ali faz quem você golpeou neste turno contra-atacar", "Red, plain frame: stopping there draws the counter of a unit you struck this turn"],
]
# the port's own actions and what each does (keyboard.ts keyHelp's words); the keys are read from the input map, so
# the list never names a key the port does not bind
# the names the web writes for these keys
const ARROWS := {"Up": "↑", "Down": "↓", "Left": "←", "Right": "→", "Escape": "Esc"}
const ACTIONS := [
	[["ui_up", "ui_down", "ui_left", "ui_right"], "no menu, sobe e desce; no mapa, anda o cursor de casa em casa (segue a câmera)", "in the menu, up and down; on the map, move the cursor tile by tile (follows the camera)"],
	[["ui_accept"], "andar até a casa sob o cursor; nas listas de Agir, escolhe o alvo, a ação e a casa; no fim do turno, confirma a direção", "move to the tile under the cursor; on the Act lists, picks the target, the action and the tile; at turn end, confirms the facing"],
	[["ui_cancel"], "volta um passo (casa → ação → alvo → menu); no menu, desfaz o último movimento se ele não levou contra-ataque", "goes back one step (tile → action → target → menu); in the menu, undoes the last move if it drew no counter"],
	[["undo"], "desfazer", "undo"],
	[["face"], "virar a unidade da vez", "turn the active unit"],
	[["info"], "Status: ficha da unidade sob o cursor (ou de quem joga)", "Status: sheet of the unit under the cursor (or the active one)"],
	[["turn_left", "turn_right"], "girar a câmera 45°", "rotate the camera 45°"],
	[["pause"], "abre o menu", "opens the menu"],
]


static func tile_marks(row: Control) -> void:
	var v := _sheet(row, Texts.t("Marcas do mapa", "Tile marks"))
	for m in MARKS:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		var sq := ColorRect.new()
		sq.color = Color(m[0])
		sq.custom_minimum_size = Vector2(14, 14)
		sq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sq)
		var l := _text(Texts.t(m[1], m[2]))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		v.add_child(h)


static func controls(row: Control) -> void:
	var v := _sheet(row, Texts.t("Controles", "Controls"))
	v.add_child(_text(Texts.t("Mouse: passe por cima para escolher, clique para confirmar, botão direito volta; arraste para mover a câmera e use a roda para o zoom. Controle: direcional ou analógico andam, A (×) confirma, B (○) volta, X (□) abre o Status, Y (△) abre a ficha da habilidade, Back desfaz, ombros giram a câmera, gatilhos dão zoom, analógico direito rola a lista de turnos, Start abre este menu.", "Mouse: hover to pick, click to confirm, right click goes back; drag to move the camera and use the wheel to zoom. Gamepad: d-pad or stick moves, A (×) confirms, B (○) goes back, X (□) opens Status, Y (△) opens the ability sheet, Back undoes, shoulders rotate the camera, triggers zoom, right stick scrolls the turn list, Start opens this menu.")))
	v.add_child(_text(Texts.t("Toque: toque numa casa para marcar e toque de novo nela para confirmar; arraste com um dedo para mover a câmera e afaste ou aproxime dois dedos para o zoom. No alto, a engrenagem abre as Opções; ao lado dela ficam Desfazer (↶) e, quando há para onde voltar, Voltar (↩). Os botões ↺ ↻ giram a câmera, e girar dois dedos também. Opções › Imagem › Botões na tela liga ou desliga Desfazer e ↺ ↻.", "Touch: tap a tile to mark it and tap it again to confirm; drag with one finger to move the camera and pinch with two to zoom. At the top, the gear opens Options; beside it sit Undo (↶) and, when there is somewhere to go back to, Back (↩). The ↺ ↻ buttons turn the camera, and so does twisting two fingers. Options › Display › Screen buttons turns Undo and ↺ ↻ on or off.")))
	v.add_child(_text(Texts.t("Na lista de turnos e nas fichas, o \"+N\" depois da Vida é a vida que a unidade recupera a cada turno dela; o \"+N\" depois do CT é o CT que ela ganha a cada tique.", "On the turn list and the unit sheets, the \"+N\" after HP is the life the unit gets back at each of its turns; the \"+N\" after CT is the CT it gains each tick.")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	for a in ACTIONS:
		var keys := keys_of(a[0])
		if keys == "":
			continue
		var k := _text(keys)
		k.autowrap_mode = TextServer.AUTOWRAP_OFF
		k.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		grid.add_child(k)
		var l := _text(Texts.t(a[1], a[2]))
		l.custom_minimum_size = Vector2(520, 0)
		grid.add_child(l)
	v.add_child(grid)


## the keyboard keys bound to these actions, as " · " separated names
static func keys_of(actions: Array) -> String:
	var names: Array = []
	for a in actions:
		if not InputMap.has_action(a):
			continue
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey:
				var code: int = ev.keycode if ev.keycode else ev.physical_keycode
				var name: String = ARROWS.get(OS.get_keycode_string(code), OS.get_keycode_string(code))
				if name != "" and not names.has(name):
					names.append(name)
	return " · ".join(names)


static func _text(s: String) -> Label:
	var l := Kit.label(s, 16, INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## the sheet over the Options window: its title, a parchment page that scrolls, and Back; returns the page's list
static func _sheet(row: Control, title: String) -> VBoxContainer:
	var host := row
	while host and not host is OptionsWindow:
		host = host.get_parent()
	var cover := OptionsWindow.backdrop(host if host else row.get_parent(), title)
	var page := PanelContainer.new()
	var s := OptionsRow.box(PARCHMENT, Color("#b8a986"), 2)
	s.set_content_margin_all(28)
	page.add_theme_stylebox_override("panel", s)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 220
	page.offset_right = -220
	page.offset_top = 124
	page.offset_bottom = -128
	cover.add_child(page)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 14)
	scroll.add_child(v)
	var close := func() -> void:
		cover.queue_free()
		Sound.play("cancel")
		row.grab_focus()
	var foot := CenterContainer.new()
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = -100
	foot.offset_bottom = -56
	cover.add_child(foot)
	var back := Kit.button(Texts.t("Voltar", "Back"), close)
	back.custom_minimum_size = Vector2(280, 44)
	foot.add_child(back)
	cover.set_meta("close", close)
	back.call_deferred("grab_focus")
	return v

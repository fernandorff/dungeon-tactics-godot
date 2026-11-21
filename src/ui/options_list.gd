class_name OptionsList
## The settings of the Options window in its categories (port of options-list.ts, options-marks.ts and the Help group
## of options.ts): Game, Sound, Display and Help, each with what it holds and its rows in the web's order. A row is a
## Dictionary the window draws: a pick {label, help, values [[value, text]], read, write, switch?}, a bar {label, help,
## bar: true, read, write} or a link {label, help, run} that goes somewhere (run gets the row).
## `battle`: the BattleScreen the window was opened over, or null; its own rows show only then.


static func groups(battle: BattleScreen, to_title: Callable) -> Array:
	var room := battle != null and battle.room != null
	return [
		{"title": Texts.t("Jogo", "Game"), "help": Texts.t("O texto das conversas, o idioma, as dicas e os ícones das teclas, a batalha rápida e a grade da cidade.", "The conversations’ text, the language, the key hints and icons, the fast battle and the town grid.") if battle else Texts.t("O texto das conversas, o idioma, as dicas e os ícones das teclas e a grade da cidade.", "The conversations’ text, the language, the key hints and icons and the town grid."), "rows": _game(battle, room, to_title)},
		{"title": Texts.t("Som", "Sound"), "help": Texts.t("O volume da música, da interface, do mundo e do diálogo.", "The volume of the music, the interface, the world and the dialogue."), "rows": _sound()},
		{"title": Texts.t("Imagem", "Display"), "help": Texts.t("As marcações do mapa, a tela cheia, o movimento, a interface, os botões na tela e a câmera.", "The marks on the map, fullscreen, motion, the interface, the screen buttons and the camera."), "rows": _display(battle)},
		{"title": Texts.t("Ajuda", "Help"), "help": Texts.t("O que as marcas do mapa querem dizer e como se joga.", "What the tile marks mean and how to play."), "rows": [
			{"label": Texts.t("Marcas do mapa", "Tile marks"), "help": Texts.t("O que cada cor e desenho no chão da batalha quer dizer.", "What each colour and pattern on the battle floor means."), "run": OptionsHelp.tile_marks},
			{"label": Texts.t("Controles", "Controls"), "help": Texts.t("Mouse, teclado, controle e toque: o que cada um faz.", "Mouse, keyboard, gamepad and touch: what each one does."), "run": OptionsHelp.controls},
		]},
	]


static func pick(label: String, help: String, values: Array, get_v: Callable, set_v: Callable) -> Dictionary:
	return {"label": label, "help": help, "values": values, "read": get_v, "write": set_v}


## a yes or no drawn as a switch; `fem`: the Portuguese word agrees with the setting's name ("Batalha rápida … Ligada")
static func on_off(label: String, help: String, get_v: Callable, set_v: Callable, fem: bool = false) -> Dictionary:
	var row := pick(label, help, [[false, Texts.t("Desligada" if fem else "Desligado", "Off")], [true, Texts.t("Ligada" if fem else "Ligado", "On")]], get_v, set_v)
	row.switch = true
	return row


static func percent(label: String, help: String, key: String) -> Dictionary:
	return {"label": label, "help": help, "bar": true, "read": func() -> int: return Sound.levels[key], "write": func(v: int) -> void: Sound.set_level(key, v)}


static func _game(battle: BattleScreen, room: bool, to_title: Callable) -> Array:
	var rows: Array = [
		pick(Texts.t("Velocidade do texto", "Text speed"), Texts.t("Quão rápido as falas das conversas aparecem.", "How fast the lines of a conversation appear."), [["normal", Texts.t("Normal", "Normal")], ["fast", Texts.t("Rápida", "Fast")], ["instant", Texts.t("Instantânea", "Instant")]], Settings.text_speed, Settings.set_text_speed),
		# the web reloads the page to change language; here the window draws itself again in the new one
		pick(Texts.t("Idioma", "Language"), Texts.t("Trocar o idioma redesenha as telas; a batalha continua de onde parou.", "Changing the language redraws the screens; the battle goes on from where it was."), [["pt", "Português"], ["en", "English"]], Texts.current, Texts.set_lang),
		on_off(Texts.t("Tutorial", "Tutorial"), Texts.t("Mostra no topo da batalha o que fazer agora e por que uma casa não serve, e no topo da cidade como andar. Desligado, fica só o resumo da última ação e a cidade sem a faixa.", "Shows at the top of the battle what to do now and why a tile does not work, and at the top of the town how to walk. Off, only the last action’s summary stays and the town has no strip."), Settings.tutorial, Settings.set_tutorial),
	]
	# the town's joystick side, only where a finger plays (a PC has no pad)
	if Settings.touch_device():
		rows.append(pick(Texts.t("Joystick e botão", "Joystick and button"), Texts.t("Na cidade, o joystick anda com o grupo e o botão fala ou entra. Escolha o lado de cada um.", "In town, the joystick walks the group and the button talks or goes in. Pick which side each is on."), [["left", Texts.t("Joystick à esquerda", "Joystick left")], ["right", Texts.t("Joystick à direita", "Joystick right")]], Settings.pad_side, Settings.set_pad_side))
	rows.append(pick(Texts.t("Dicas de tecla e botão", "Key and button hints"), Texts.t("O rodapé da batalha com o que cada tecla ou botão faz. Automático: só com teclado ou controle em uso, nunca no toque.", "The battle’s footer with what each key or button does. Automatic: only while a keyboard or pad is in use, never on touch."), [["auto", Texts.t("Automático", "Automatic")], ["always", Texts.t("Sempre", "Always")], ["never", Texts.t("Nunca", "Never")]], Settings.hints, Settings.set_hints))
	rows.append(pick(Texts.t("Ícones das teclas", "Key icons"), Texts.t("O que as dicas de tecla mostram. Automático segue o que você usou por último: um botão do controle traz os ícones dele, uma tecla traz o teclado de volta; o mouse não muda nada.", "What the key hints show. Automatic follows what you used last: a pad button brings its icons, a key brings the keyboard back; the mouse changes nothing."), [["auto", Texts.t("Automático", "Automatic")], ["keyboard", Texts.t("Teclado", "Keyboard")], ["xbox", "Gamepad Xbox"], ["playstation", "Gamepad PlayStation"], ["switch", "Gamepad Switch"]], Settings.glyphs, Settings.set_glyphs))
	if battle:
		rows.append(on_off(Texts.t("Batalha rápida (3×)", "Fast battle (3×)"), Texts.t("As animações da batalha passam três vezes mais rápido. No teclado, segurar Enter faz o mesmo.", "The battle’s animations play three times faster. On a keyboard, holding Enter does the same."), Settings.fast, func(on: bool) -> void:
			Settings.set_fast(on)
			Engine.time_scale = Settings.FAST if on else 1.0, true))
	rows.append(on_off(Texts.t("Grade da cidade", "Town grid"), Texts.t("Mostra as casas do chão da cidade e o espaço que cada um ocupa: uma conferência, não ajuda a jogar.", "Shows the town’s floor cells and the room each one takes: a check, not a play aid."), Settings.town_grid, Settings.set_town_grid, true))
	# from a room the 2nd press confirms losing the expedition, as "Leave the room" does
	rows.append({"label": Texts.t("Voltar ao título", "Back to title"), "help": Texts.t("Volta à tela de título. Sair de uma sala perde a expedição.", "Goes back to the title. Leaving a room loses the expedition.") if room else Texts.t("Volta à tela de título.", "Goes back to the title."), "run": func(b: Control) -> void:
		if room and not OptionsRow.second_press(b, Texts.t("Confirmar: perde a expedição", "Confirm: the expedition is lost")):
			return
		to_title.call()})
	return rows


static func _sound() -> Array:
	return [
		percent(Texts.t("Música", "Music"), Texts.t("Volume da música, em passos de 5%.", "Music volume, in steps of 5%."), "music"),
		percent(Texts.t("Interface", "Interface"), Texts.t("Volume dos cliques dos menus, em passos de 5%.", "Volume of the menu clicks, in steps of 5%."), "ui"),
		percent(Texts.t("Mundo", "World"), Texts.t("Volume dos golpes, magias, passos e fanfarras, em passos de 5%.", "Volume of blows, spells, steps and fanfares, in steps of 5%."), "world"),
		percent(Texts.t("Diálogo", "Dialogue"), Texts.t("Volume das vozes das conversas, em passos de 5%.", "Volume of the voices in conversations, in steps of 5%."), "voice"),
	]


static func _display(battle: BattleScreen) -> Array:
	var rows: Array = [pick(Texts.t("Marcações", "Marks"), Texts.t("Como as casas, o cursor, os aros dos personagens e as linhas aparecem no mapa. Simples: o desenho chapado, o mais leve. Luz: luz gravada no chão. Pedra: peças de pedra e metal. Neon: tubos de luz.", "How the tiles, the cursor, the rings round the characters and the lines show on the map. Simple: the flat drawing, the lightest. Light: light etched in the ground. Stone: stone and metal pieces. Neon: tubes of light."), [["simples", Texts.t("Simples", "Simple")], ["luz", Texts.t("Luz", "Light")], ["pedra", Texts.t("Pedra", "Stone")], ["neon", "Neon"]], Settings.marks, Settings.set_marks)]
	# a phone or tablet app is always full screen: the row is a desktop's, as the web shows it only where the API exists
	if not OS.has_feature("mobile"):
		rows.append(on_off(Texts.t("Tela cheia", "Fullscreen"), Texts.t("Esconde a barra do navegador. No celular, também trava a tela deitada.", "Hides the browser bar. On a phone it also locks the screen to landscape.") if OS.has_feature("web") else Texts.t("O jogo ocupa a tela toda, sem a moldura da janela.", "The game fills the whole screen, without the window frame."), Settings.fullscreen, Settings.set_fullscreen, true))
	rows.append(pick(Texts.t("Reduzir movimento", "Reduce motion"), Texts.t("Sem tremor de câmera, câmera de ação, câmera lenta nem animações de menu. \"Do sistema\" segue o seu aparelho.", "No camera shake, action camera, slow motion or menu animations. \"System\" follows your device."), [["system", Texts.t("Do sistema", "System")], ["reduce", Texts.t("Sim", "Yes")], ["full", Texts.t("Não", "No")]], Settings.motion, Settings.set_motion))
	rows.append(pick(Texts.t("Disposição da interface", "Interface layout"), Texts.t("Onde ficam os painéis da batalha: nas bordas da tela ou numa moldura 16:9 no centro.", "Where the battle panels sit: at the screen edges or in a centred 16:9 frame."), [["edges", Texts.t("Nas bordas da tela", "At the screen edges")], ["frame", Texts.t("Moldura 16:9 no centro", "Centred 16:9 frame")]], Settings.layout, Settings.set_layout))
	rows.append(on_off(Texts.t("Botões na tela", "Screen buttons"), Texts.t("Mostra no alto da tela os botões Desfazer (↶) e Girar a câmera (↺ ↻). Ligados no celular e no tablet; no PC, as teclas fazem os dois: Z desfaz e R gira a câmera.", "Shows the Undo (↶) and Turn the camera (↺ ↻) buttons at the top of the screen. On for phones and tablets; on a PC, the keys do both: Z undoes and R turns the camera."), Settings.screen_buttons, Settings.set_screen_buttons))
	rows.append(on_off(Texts.t("Câmera lenta nas mortes", "Slow motion on deaths"), Texts.t("A queda do último inimigo ou do último herói passa devagar, com a câmera perto.", "The fall of the last enemy or the last hero plays slowly, with the camera close."), Settings.slowmo, Settings.set_slowmo, true))
	if battle:
		rows.append(on_off(Texts.t("Contador de fps", "FPS counter"), Texts.t("Mostra no canto quadros por segundo, desenhos e memória da cena. No teclado, F3.", "Shows frames per second, draw calls and the scene’s memory in the corner. On a keyboard, F3."), Settings.fps, Settings.set_fps))
	return rows

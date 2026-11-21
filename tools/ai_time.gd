extends SceneTree
## Times the AI: plays the first N turns of a halved map, AI on both sides, and prints the slowest turns.
## godot --headless --path . --script tools/ai_time.gd -- [map] [turns]

func _init() -> void:
	Content.ensure()
	var args := OS.get_cmdline_user_args()
	var map: String = args[0] if args.size() > 0 else Content.data.first_battle
	var n: int = int(args[1]) if args.size() > 1 else 12
	var b := Battle.start(Half.halve(Content.scenarios[map]), 1)
	var total := 0
	for i in n:
		if b.over():
			break
		var who: String = b.actor().def
		var t0 := Time.get_ticks_usec()
		Ai.play_turn(b)
		var dt := (Time.get_ticks_usec() - t0) / 1000
		total += dt
		print("%-22s %6d ms" % [who, dt])
	print("total %d ms" % total)
	quit()

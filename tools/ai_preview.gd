extends SceneTree
## Times one archer's attack previews piece by piece (Combat.preview, Shot.trace, area, damage).

func _init() -> void:
	Content.ensure()
	var b := Battle.start(Half.halve(Content.scenarios["beacon_hill"]), 1)
	while b.actor().def != "archer½":
		Ai.play_turn(b)
	var g := b.grid
	var st := b.state
	var me := b.actor()
	var n := 0
	var t_prev := 0
	var t_shot := 0
	var t_ends := 0
	for u in st.units:
		if u.team == me.team:
			continue
		for id in Content.units[me.def].abilities:
			var a: Dictionary = Content.abilities[id]
			for k in 20:
				var t := Time.get_ticks_usec()
				var p := Combat.preview(g, st, me.id, id, u.pos)
				t_prev += Time.get_ticks_usec() - t
				t = Time.get_ticks_usec()
				Pathing.aim_ends(g, st, me, u.pos)
				t_ends += Time.get_ticks_usec() - t
				if a.needsSight:
					t = Time.get_ticks_usec()
					Shot.trace(g, st, me, u.pos, a.get("arc", false))
					t_shot += Time.get_ticks_usec() - t
				n += 1
	print("%d previews: preview %d us each · aim_ends %d us · shot %d us" % [n, t_prev / n, t_ends / n, t_shot / n])
	quit()

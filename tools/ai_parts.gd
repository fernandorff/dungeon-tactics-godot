extends SceneTree
## The archer's decision split into its parts: reach, walk map, attack scores (count, in range) and position scores.

func _init() -> void:
	Content.ensure()
	var b := Battle.start(Half.halve(Content.scenarios["beacon_hill"]), 1)
	while b.actor().def != "archer½":
		Ai.play_turn(b)
	var g := b.grid
	var st := b.state
	var actor := b.actor()
	var t := Time.get_ticks_usec()
	var spots: Array = [actor.pos]
	for s in Pathing.reachable(g, st, actor.id).values():
		spots.append(s.pos)
	print("reach %d spots %d ms" % [spots.size(), (Time.get_ticks_usec() - t) / 1000])
	t = Time.get_ticks_usec()
	var walk := Ai.walk_map(g, st, actor)
	print("walk %d ms" % ((Time.get_ticks_usec() - t) / 1000))
	var ta := 0
	var tp := 0
	var tpv := 0
	var calls := 0
	var hits := 0
	for spot in spots:
		var moved := Ai._with_unit_at(st, actor, spot)
		var me := Combat.find_unit(moved, actor.id)
		var t1 := Time.get_ticks_usec()
		for id in Content.units[actor.def].abilities:
			for target in Ai._candidate_targets(g, moved, me, Content.abilities[id]):
				calls += 1
				var t2 := Time.get_ticks_usec()
				var p := Combat.preview(g, moved, me.id, id, target)
				tpv += Time.get_ticks_usec() - t2
				if p.ok:
					hits += 1
					Ai.attack_score(g, moved, me, id, target)
		ta += Time.get_ticks_usec() - t1
		t1 = Time.get_ticks_usec()
		Ai._position_score(g, moved, me, spot, false, walk)
		Ai._kin_near(moved, me)
		tp += Time.get_ticks_usec() - t1
	print("attacks %d ms (%d calls, %d in range; previews alone %d ms) · position %d ms" % [ta / 1000, calls, hits, tpv / 1000, tp / 1000])
	print("abilities: ", Content.units[actor.def].abilities)
	quit()

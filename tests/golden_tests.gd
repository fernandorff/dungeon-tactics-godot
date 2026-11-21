class_name GoldenTests
## The port against the web game: each test replays a reference run from tests/golden with the same seed and must give the
## same events, turn by turn. A test returns "" when it passes, else where it first differs.


func _scenario(id: String) -> Dictionary:
	if Content.scenarios.has(id) and not id.ends_with(Content.HALF):
		return Content.scenarios[id]
	var base: Dictionary = Content.scenarios[Content.base_def(id)]
	return Half.halve(base)


func _replay(run: Dictionary, sc: Dictionary, label: String) -> String:
	var b := Battle.start(sc, run.seed)
	var d := Util.diff(Util.plain(b.state), run.start, label + " start")
	if d != "":
		return d
	for i in run.turns.size():
		var want: Dictionary = run.turns[i]
		if b.over():
			return "%s turn %d: the port ended the battle early" % [label, i]
		if b.actor().id != want.actor:
			return "%s turn %d: actor %s, want %s" % [label, i, b.actor().id, want.actor]
		var events := Ai.play_turn(b)
		d = Util.diff(Util.plain(events), want.events, "%s turn %d (%s) events" % [label, i, want.actor])
		if d != "":
			return d
		if b.state.rng != want.rng:
			return "%s turn %d: rng %d, want %d" % [label, i, b.state.rng, want.rng]
	return Util.diff(Util.plain(b.state), run.final, label + " final")


func test_battles() -> String:
	var runs: Array = Util.load_json("res://tests/golden/battles.json")
	for run in runs:
		var err := _replay(run, _scenario(run.scenario), run.scenario)
		if err != "":
			return err
	return ""


func test_crawl_battles() -> String:
	var rooms: Array = Util.load_json("res://tests/golden/crawl_rooms.json")
	var runs: Array = Util.load_json("res://tests/golden/crawl_battles.json")
	for i in runs.size():
		var room := Content.scenario_from(rooms[i].room)
		Content.scenarios[room.id] = room
		var err := _replay(runs[i], Half.halve(room), runs[i].scenario)
		if err != "":
			return err
	return ""


## the procedural rooms: same seed, same layout, same number of tries and the same enemy group
func test_crawl_rooms() -> String:
	var rooms: Array = Util.load_json("res://tests/golden/crawl_rooms.json")
	for r in rooms:
		var label := "room %d" % r.seed
		var built := CrawlGen.build_room(r.seed, r.opts)
		if built.is_empty():
			return label + ": no room passed"
		if built.tries != r.tries:
			return "%s: %d tries, want %d" % [label, built.tries, r.tries]
		var room: Dictionary = built.room.duplicate()
		room.grid = room.grid.to_dict()
		var d := Util.diff(Util.plain(room), r.room, label)
		if d != "":
			return d
		d = Util.diff(CrawlGen.room_group(r.seed, r.opts).group, r.group, label + " group")
		if d != "":
			return d
	return ""


## the expedition map, each node's gold and each chest's item
func test_expeditions() -> String:
	var runs: Array = Util.load_json("res://tests/golden/expeditions.json")
	for e in runs:
		var map := Expedition.map_of(e.seed)
		var label := "expedition %d" % e.seed
		var d := Util.diff(map, e.map, label + " map")
		if d != "":
			return d
		for i in map.size():
			if Expedition.node_gold(map[i]) != e.gold[i]:
				return "%s node %d: gold %d, want %d" % [label, i, Expedition.node_gold(map[i]), e.gold[i]]
			var want: Variant = e.chest[i]
			if map[i].chest and Expedition.chest_item(map[i]) != want:
				return "%s node %d: chest %s, want %s" % [label, i, Expedition.chest_item(map[i]), want]
	return ""


## the comparison is not blind: the same run with another seed must differ
func test_replay_detects_a_change() -> String:
	var runs: Array = Util.load_json("res://tests/golden/battles.json")
	var run: Dictionary = runs[0].duplicate()
	run.seed = run.seed + 1
	var err := _replay(run, _scenario(run.scenario), run.scenario)
	return "" if err != "" else "another seed replayed the same battle"


## the turn list, the Agir options, the items and the walk at the start of some battles
func test_reads() -> String:
	var reads: Array = Util.load_json("res://tests/golden/reads.json")
	for i in reads.size():
		var r: Dictionary = reads[i]
		var sc := _scenario(r.scenario)
		var state: Dictionary = Util.vecs(r.state)
		var label := "%s read %d" % [r.scenario, i]
		var d := Util.diff(Util.plain(TurnQueue.preview_order(state, 12)), r.order, label + " order")
		if d != "":
			return d
		d = Util.diff(Util.plain(Options.action_options(sc.grid, state, state.turn.actor)), r.options, label + " options")
		if d != "":
			return d
		var with_bag := state.duplicate()
		with_bag.bag = {"life_potion": 2, "ether": 1}
		d = Util.diff(Util.plain(Bag.item_options(sc.grid, with_bag, state.turn.actor)), r.items, label + " items")
		if d != "":
			return d
		var b := Battle.new(sc.grid, state)
		d = Util.diff(Util.plain(b.reach().values()), r.reach, label + " reach")
		if d != "":
			return d
		d = _act_read(Battle.new(sc.grid, with_bag.duplicate(true)), r.act, label)
		if d != "":
			return d
	return ""


## the Agir screens on the same state: targets, list, groups, each target's actions with the spot picked first, and
## each action's own target list on both sides
func _act_read(b: Battle, want: Dictionary, label: String) -> String:
	var targets := ActFlow.act_targets(b)
	var d := Util.diff(Util.plain(targets), want.targets, label + " act targets")
	if d != "":
		return d
	d = Util.diff(Util.plain(ActFlow.act_list(b)), want.list, label + " act list")
	if d != "":
		return d
	var groups: Array = []
	for g in ActFlow.GROUPS:
		groups.append(ActFlow.act_group(b, g))
	d = Util.diff(Util.plain(groups), want.groups, label + " act groups")
	if d != "":
		return d
	for i in targets.size():
		var acts: Array = []
		for a in ActFlow.act_actions(b, targets[i]):
			var row: Dictionary = a.duplicate()
			row.best = ActFlow.best_spot(a, b)
			row.aims = ActFlow.act_aims(a)
			acts.append(row)
		d = Util.diff(Util.plain(acts), want.actions[i], "%s act actions %d" % [label, i])
		if d != "":
			return d
	for o in want.only:
		d = Util.diff(Util.plain(ActFlow.act_targets(b, o.ref)), o.own, "%s only %s" % [label, o.ref.id])
		if d != "":
			return d
		d = Util.diff(Util.plain(ActFlow.act_targets(b, o.ref, true)), o.other, "%s other %s" % [label, o.ref.id])
		if d != "":
			return d
	return ""


## the AI's plan with one ability alone (Shove, Throw sand, Focus, Shield bash): the same score and choice as the web AI
func test_ai_abilities() -> String:
	var probes: Array = Util.load_json("res://tests/golden/ai_abilities.json")
	for i in probes.size():
		var r: Dictionary = probes[i]
		var sc := _scenario(r.scenario)
		var state: Dictionary = Util.vecs(r.state)
		var def: Dictionary = Content.units[Combat.find_unit(state, state.turn.actor).def]
		var all: Array = def.abilities
		def.abilities = [r.ability]
		var plan := Ai.choose_turn(sc.grid, state, state.turn.actor)
		def.abilities = all
		var d := Util.diff(Util.plain(plan), r.plan, "%s probe %d %s" % [r.scenario, i, r.ability])
		if d != "":
			return d
	return ""

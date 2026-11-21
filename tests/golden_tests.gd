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
	return ""

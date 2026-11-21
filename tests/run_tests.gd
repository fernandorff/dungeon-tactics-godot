extends SceneTree
## Headless test runner: plays the web game's reference runs (tests/golden, written by tools/export.ts) with the port and
## stops at the first event that differs. Run: godot --headless --path . --script tests/run_tests.gd [-- filter]

var failures := 0
var passed := 0


func _initialize() -> void:
	Content.ensure()
	var filter := ""
	for a in OS.get_cmdline_user_args():
		filter = a
	var started := Time.get_ticks_msec()
	for suite in [GoldenTests, UnitTests, CrawlTests, EquipmentTests, GameTests, MapTests]:
		for m in suite.new().get_method_list():
			var name: String = m.name
			if not name.begins_with("test_") or (filter != "" and not name.contains(filter)):
				continue
			var t0 := Time.get_ticks_msec()
			var err: String = suite.new().call(name)
			if err == "":
				passed += 1
				print("ok   %s (%d ms)" % [name, Time.get_ticks_msec() - t0])
			else:
				failures += 1
				print("FAIL %s: %s" % [name, err])
	print("%d passed, %d failed in %d ms" % [passed, failures, Time.get_ticks_msec() - started])
	quit(1 if failures else 0)

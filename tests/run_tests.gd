extends SceneTree
## Headless test runner: plays the web game's reference runs (tests/golden, written by tools/export.ts) with the port and
## stops at the first event that differs. Run: godot --headless --path . --script tests/run_tests.gd [-- filter]


## counts the engine's errors: a script error inside a test only prints and returns null, which read as a pass before
class ErrorCount extends Logger:
	var count := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		count += 1


var failures := 0
var passed := 0


func _initialize() -> void:
	var errors := ErrorCount.new()
	OS.add_logger(errors)
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
			var before := errors.count
			var out: Variant = suite.new().call(name)
			var err: String = out if typeof(out) == TYPE_STRING else "returned %s, not a String" % [out]
			if errors.count > before:
				err = "%d engine error(s) while it ran%s" % [errors.count - before, "" if err == "" else "; " + err]
			if err == "":
				passed += 1
				print("ok   %s (%d ms)" % [name, Time.get_ticks_msec() - t0])
			else:
				failures += 1
				print("FAIL %s: %s" % [name, err])
	print("%d passed, %d failed in %d ms" % [passed, failures, Time.get_ticks_msec() - started])
	OS.remove_logger(errors)
	quit(1 if failures else 0)

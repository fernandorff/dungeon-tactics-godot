extends SceneTree
## Plays every sound kind once through Sound (headless, so nothing is heard) and lists each file's length, then writes
## the made sounds (fanfares, blip) as .wav files to listen to. Any engine error shows in the output.
## Run: godot --headless --path . --script tools/sound_check.gd -- <folder for the .wav files>


func _initialize() -> void:
	_run.call_deferred() # the players must be in the tree, which it is only after this returns


func _run() -> void:
	var out_dir := "user://sound-check"
	for a in OS.get_cmdline_user_args():
		out_dir = a
	DirAccess.make_dir_recursive_absolute(out_dir)
	Store.reset_memory()
	Sound.load_levels()
	var host := Node.new()
	root.add_child(host)
	Sound.attach(host)
	for k in Sound.FILE:
		Sound.play(k)
		var s: AudioStream = load("res://assets/sfx/%s.mp3" % Sound.FILE[k])
		print("%-8s %-9s %.2f s" % [k, Sound.FILE[k], s.get_length()])
	Sound.jingle(true)
	Sound.jingle(false)
	Sound.blip(300.0)
	var made := {"victory": Synth.jingle(true, Sound.gain(50) * 0.4), "defeat": Synth.jingle(false, Sound.gain(50) * 0.4), "blip": Synth.blip(300.0, Sound.gain(50) * 0.3)}
	for name in made:
		var wav := Synth.to_wav(made[name])
		var path := out_dir.path_join(name + ".wav")
		print("%-8s %.2f s -> %s (%s)" % [name, wav.get_length(), path, error_string(wav.save_to_wav(path))])
	await create_timer(2.0).timeout # let every sound play to its end: a made one frees its player then
	print("players left: %d (one per effect file)" % host.get_child_count())
	quit()

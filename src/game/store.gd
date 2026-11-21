class_name Store
## The game's saved keys (port of store.ts): the same dt:* keys and text values as the web game, kept in one JSON file
## under user://. Tests switch to memory only (`memory_only`), so they never touch a player's saves.

const FILE := "user://dt-store.json"

static var memory_only := false
static var _data: Dictionary = {}
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if memory_only or not FileAccess.file_exists(FILE):
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	# trust boundary: only text values under dt: keys come back
	if typeof(raw) == TYPE_DICTIONARY:
		for k in raw:
			if typeof(k) == TYPE_STRING and k.begins_with("dt:") and typeof(raw[k]) == TYPE_STRING:
				_data[k] = raw[k]


## a fresh memory-only store (tests)
static func reset_memory() -> void:
	memory_only = true
	_loaded = true
	_data = {}


static func get_key(k: String) -> String:
	_ensure()
	return _data.get(k, "")


static func set_key(k: String, v: String) -> void:
	_ensure()
	_data[k] = v
	# the save slot's last-played time (saves.gd), for the Continue list
	if Saves.PROGRESS_KEYS.has(k):
		_data[Saves.PLAYED_KEY] = str(int(Time.get_unix_time_from_system() * 1000))
	_flush()


## the raw set, without the played stamp (slot restore)
static func put(k: String, v: String) -> void:
	_ensure()
	_data[k] = v
	_flush()


## missing or broken text = null; each reader rebuilds what it gets
static func json(k: String) -> Variant:
	var s := get_key(k)
	var j := JSON.new() # its parse only returns the error: JSON.parse_string also logs one for every broken save
	if s == "" or j.parse(s) != OK:
		return null
	return Util.ints(j.data)


static func _flush() -> void:
	if memory_only:
		return
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_data))

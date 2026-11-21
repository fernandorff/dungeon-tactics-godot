class_name Util
## Small helpers the port needs where GDScript and JavaScript differ: JSON numbers, positions, a stable sort, deep copy and
## deep equality. The web game's rules lean on JavaScript's behaviour in a few places (stable sort, `/` always a float
## division, insertion-ordered maps); each helper here keeps that behaviour so the same seed plays the same battle.


## JSON numbers come back as floats in Godot: whole ones become ints again, so `/` and `%` follow the rules' intent
const BIG := 1099511627776


static func ints(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			return int(f) if f == floorf(f) and absf(f) < 9.0e15 else f
		TYPE_ARRAY:
			var out: Array = []
			for x in v:
				out.append(ints(x))
			return out
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k in v:
				d[k] = ints(v[k])
			return d
	return v


## {x, y} with nothing else becomes a Vector2i (positions in the state); everything else is walked into
static func vecs(v: Variant) -> Variant:
	match typeof(v):
		TYPE_ARRAY:
			var out: Array = []
			for x in v:
				out.append(vecs(x))
			return out
		TYPE_DICTIONARY:
			var d: Dictionary = v
			if d.size() == 2 and d.has("x") and d.has("y") and typeof(d.x) == TYPE_INT and typeof(d.y) == TYPE_INT:
				return Vector2i(d.x, d.y)
			var out: Dictionary = {}
			for k in d:
				out[k] = vecs(d[k])
			return out
	return v


## the other way: Vector2i back to {x, y}, for saves and for comparing with the web game's JSON
static func plain(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR2I:
			return {"x": v.x, "y": v.y}
		TYPE_ARRAY:
			var out: Array = []
			for x in v:
				out.append(plain(x))
			return out
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for k in v:
				out[k] = plain(v[k])
			return out
	return v


static func load_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	return ints(parsed)


## deep equality with a float tolerance; returns "" when equal, else where they differ
static func diff(a: Variant, b: Variant, at: String = "") -> String:
	var ta := typeof(a)
	var tb := typeof(b)
	if (ta == TYPE_INT or ta == TYPE_FLOAT) and (tb == TYPE_INT or tb == TYPE_FLOAT):
		return "" if absf(float(a) - float(b)) <= 1e-9 * maxf(1.0, absf(float(a))) else "%s: %s != %s" % [at, a, b]
	if ta != tb:
		return "%s: type %s != %s (%s vs %s)" % [at, ta, tb, str(a).left(80), str(b).left(80)]
	if ta == TYPE_ARRAY:
		if a.size() != b.size():
			return "%s: size %d != %d" % [at, a.size(), b.size()]
		for i in a.size():
			var d := diff(a[i], b[i], "%s[%d]" % [at, i])
			if d != "":
				return d
		return ""
	if ta == TYPE_DICTIONARY:
		for k in a:
			if not b.has(k):
				return "%s.%s: missing on the right (%s)" % [at, k, str(a[k]).left(80)]
		for k in b:
			if not a.has(k):
				return "%s.%s: missing on the left (%s)" % [at, k, str(b[k]).left(80)]
		for k in a:
			var d := diff(a[k], b[k], "%s.%s" % [at, k])
			if d != "":
				return d
		return ""
	return "" if a == b else "%s: %s != %s" % [at, a, b]


## JavaScript's sort is stable and the rules depend on it (ties keep the earlier one first): a merge sort with `less(a, b)`
## meaning a goes strictly before b
static func stable_sort(arr: Array, less: Callable) -> Array:
	if arr.size() <= 1:
		return arr.duplicate()
	var mid := arr.size() / 2
	var left := stable_sort(arr.slice(0, mid), less)
	var right := stable_sort(arr.slice(mid), less)
	var out: Array = []
	var i := 0
	var j := 0
	while i < left.size() and j < right.size():
		if less.call(right[j], left[i]):
			out.append(right[j])
			j += 1
		else:
			out.append(left[i])
			i += 1
	out.append_array(left.slice(i))
	out.append_array(right.slice(j))
	return out


## Math.floor(a / b) for ints, toward minus infinity as in JavaScript (GDScript's int division truncates toward zero)
static func floor_div(a: int, b: int) -> int:
	return floori(float(a) / float(b))


static func ceil_div(a: int, b: int) -> int:
	return ceili(float(a) / float(b))


## JavaScript's `x | 0`: a number wrapped into a signed 32-bit int
static func i32(v: int) -> int:
	v = v & 0xFFFFFFFF
	return v - 0x100000000 if v >= 0x80000000 else v

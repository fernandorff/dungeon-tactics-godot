class_name Rng
## Seeded RNG (mulberry32) without a closure: the state is an int that lives in the battle state, so saving, cloning and
## simulating the same battle give the same sequence. Bit for bit the web game's (32-bit ops by hand: GDScript ints are 64).


static func _ushr(x: int, n: int) -> int:
	return (x & 0xFFFFFFFF) >> n


static func _imul(a: int, b: int) -> int:
	return Util.i32(a * b)


## [value in 0..1, next state]
static func next(state: int) -> Array:
	var s := Util.i32(state + 0x6D2B79F5)
	var t := _imul(Util.i32(s ^ _ushr(s, 15)), Util.i32(1 | s))
	t = Util.i32(Util.i32(t + _imul(Util.i32(t ^ _ushr(t, 7)), Util.i32(61 | t))) ^ t)
	return [float((t ^ _ushr(t, 14)) & 0xFFFFFFFF) / 4294967296.0, s]


## [int between lo and hi, both inclusive, next state]
static func roll_int(state: int, lo: int, hi: int) -> Array:
	var r := next(state)
	return [lo + floori(float(r[0]) * (hi - lo + 1)), r[1]]

class_name UnitTests
## Edge cases of the port's own helpers (the rules themselves are checked against the web game in golden_tests.gd).


func test_rng_matches_mulberry32() -> String:
	# first values of the web game's nextRng from seed 7 (node: nextRng(7))
	var r := Rng.next(7)
	if r[1] != Util.i32(7 + 0x6D2B79F5):
		return "next state %d" % r[1]
	return ""


func test_stable_sort_keeps_ties() -> String:
	var arr := [{"k": 1, "i": 0}, {"k": 0, "i": 1}, {"k": 1, "i": 2}, {"k": 0, "i": 3}]
	var out := Util.stable_sort(arr, func(a: Dictionary, b: Dictionary) -> bool: return a.k < b.k)
	var order := out.map(func(x: Dictionary) -> int: return x.i)
	return "" if order == [1, 3, 0, 2] else "order %s" % [order]


func test_floor_div_rounds_down() -> String:
	return "" if Util.floor_div(-3, 2) == -2 and Util.ceil_div(3, 2) == 2 and Util.ceil_div(-3, 2) == -1 else "floor/ceil"

class_name Spring3d
extends RefCounted
## The damped spring every 3D screen moves on (port of the web game's ui3d/spring.ts), the ease for what must not
## overshoot, and the short way around a ring of pages.

var x := 0.0
var v := 0.0
var to := 0.0


func _init(start: float = 0.0) -> void:
	x = start
	to = start


## toward `to`; c under 2·√k overshoots and comes back. Stepped in slices of 1/120 s so a slow frame cannot blow it up;
## a frame longer than 0.1 s counts as 0.1 s
func step(dt: float, k: float = 260.0, c: float = 22.0) -> void:
	var left:= minf(dt, 0.1)
	while left > 1e-6:
		var h:= minf(left, 1.0 / 120.0)
		v += (k * (to - x) - c * v) * h
		x += v * h
		left -= 1.0 / 120.0


## reduced motion: already where it is going
func move(dt: float, still: bool, k: float = 260.0, c: float = 22.0) -> void:
	if still:
		land()
	else:
		step(dt, k, c)


func settled() -> bool:
	return absf(to - x) < 0.002 and absf(v) < 0.02


func land(at: float = NAN) -> void:
	if not is_nan(at):
		to = at
	x = to
	v = 0.0


static func ease(value: float, target: float, dt: float, rate: float) -> float:
	return target + (value - target) * exp(-rate * dt)


## shortest way from one page to another on a ring of `count`: the last page slides on to the first
static func page_step(from: int, target: int, count: int) -> int:
	var d := posmod(target - from, count)
	return d - count if d > count / 2.0 else d

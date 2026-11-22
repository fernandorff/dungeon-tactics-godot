class_name BarLayout
## Where each part of the 3D combat bar sits inside its region (port of the web game's bar3d/bar-layout.ts), in px of the
## 1920x1080 reference from the region's top left, measured on the reference capture. The shaders (sheet3d, plate3d) and
## the texts (Bar3d) read the same boxes. Pure; replayed against the web's numbers in tests/bar_tests.gd.
##   A spot is {x, y, size, align ("l", "r" or "c"), max}: where a text hangs (its left or right end, or its middle, at x),
##   the middle of its line, its size and, with max > 0, the width it shrinks to fit.

const PAD := 14.0 # room around a region inside its quad: the portrait's shadow and the soft edges (plates.ts)

# the preview plate: a dark arrow pointing at the target's sheet, its texts centred left of the tip
const PLATE := {
	"w": 340.0, "h": 218.0,
	"tip": 56.0, # how far the point reaches past the plate's straight edges
	"chance": {"x": 142.0, "y": 31.0, "size": 26.0, "align": "c", "max": 250.0},
	"amount": {"x": 142.0, "y": 96.0, "size": 80.0, "align": "c", "max": 250.0},
	"amountText": {"x": 142.0, "y": 96.0, "size": 34.0, "align": "c", "max": 250.0}, # a support: the ability's name
	"label": {"x": 142.0, "y": 163.0, "size": 24.0, "align": "c", "max": 260.0},
	"name": {"x": 142.0, "y": 195.0, "size": 18.0, "align": "c", "max": 270.0},
}


static func _spot(x: float, y: float, size: float, align: String, most: float = 0.0) -> Dictionary:
	return {"x": x, "y": y, "size": size, "align": align, "max": most}


## The acting unit's sheet has its portrait on the left; the target's is its mirror, portrait on the right, with the text
## in the same order 168 px to the left (the reference's text starts at x=280 on one and x=1152 on the other)
static func sheet(mirror: bool) -> Dictionary:
	var dx := -168.0 if mirror else 0.0
	var portrait := Rect2(520, 0, 160, 194) if mirror else Rect2(0, 0, 162, 194)
	var box := func(x: float, y: float, w: float, h: float) -> Rect2: return Rect2(x + dx, y, w, h)
	var spot := func(x: float, y: float, size: float, align: String, most: float = 0.0) -> Dictionary: return _spot(x + dx, y, size, align, most)
	return {
		"w": 680.0 if mirror else 672.0, "h": 214.0, "portrait": portrait, "mirror": mirror,
		# under the portrait's inner edge, so its round corners show no gap
		"band": Rect2(0, 0, 532, 214) if mirror else Rect2(150, 0, 522, 214),
		"hpBar": box.call(178, 84, 234, 16), "poolBar": box.call(428, 84, 234, 16),
		# up to a space before the value (Fernando, Nov 20: the CT gain left the bar, which takes its room)
		"ctBar": box.call(226, 123, 136, 10),
		"box": box.call(428, 114, 234, 34), "boxBar": box.call(480, 126, 96, 10), "strip": box.call(170, 156, 498, 38),
		"name": spot.call(180, 21, 30, "l", 480),
		"tag": _spot(portrait.position.x + portrait.size.x / 2, 179, 22, "c", portrait.size.x - 16),
		"hpLabel": spot.call(180, 65, 26, "l"), "hpRegen": spot.call(242, 67, 20, "l", 52), "hpValue": spot.call(412, 65, 30, "r"),
		"poolLabel": spot.call(432, 65, 26, "l"), "poolValue": spot.call(662, 65, 30, "r"),
		"ctLabel": spot.call(180, 128, 24, "l"), "ctValue": spot.call(412, 128, 24, "r"),
		"boxLabel": spot.call(438, 131, 20, "l"), "boxValue": spot.call(654, 131, 20, "r"),
		"line": spot.call(184, 175, 22, "l", 472),
	}


## A text's middle on the page from its drawn width: `w` is the label's width, `pad` the empty margin it carries on each
## side (Text3d.PAD), `s` the scale of one reference px. With `max`, a wider text shrinks to fit (`k`)
static func hang(sp: Dictionary, w: float, s: float, pad: float) -> Dictionary:
	var most: float = sp.get("max", 0.0)
	var k := (most * s) / (w - 2 * pad) if most > 0 and w - 2 * pad > most * s else 1.0
	var half := (w * k) / 2 - pad * k
	var off: float = half if sp.align == "l" else (-half if sp.align == "r" else 0.0)
	return {"x": sp.x * s + off, "k": k}

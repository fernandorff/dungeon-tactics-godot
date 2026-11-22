class_name RowIcon
extends Control
## A menu row's icon: a round paper medallion with the ability's 32 px cell inside (Icons), kept crisp (nearest), faded
## on an off row. The web game sets a small low-poly model there (menu3d/models.ts); the port shows the atlas instead.
## Status has no cell: a little rolled scroll is drawn.

var id := ""
var off := false


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST


func _draw() -> void:
	var r := size.x / 2
	var c := size / 2
	draw_circle(c + Vector2(0, 1), r, Color(HudSkin.EDGE, 0.35))
	draw_circle(c, r, HudSkin.SHADE.darkened(0.08))
	draw_circle(c, r - 2, HudSkin.PAPER)
	draw_arc(c, r - 0.5, 0, TAU, 32, Color(HudSkin.EDGE, 0.55), 1.2, true)
	var tint := Color(1, 1, 1, 0.45) if off else Color.WHITE
	var tex := Icons.texture(id)
	if tex:
		var s := size.x * 0.8
		draw_texture_rect(tex, Rect2(c - Vector2(s, s) / 2, Vector2(s, s)), false, tint)
		return
	# the scroll: a sheet with two rolled ends and three lines of writing
	var w := size.x * 0.46
	var h := size.y * 0.56
	var at := c - Vector2(w, h) / 2
	draw_rect(Rect2(at, Vector2(w, h)), Color("#efe3c0") * tint)
	draw_rect(Rect2(at - Vector2(2, 3), Vector2(w + 4, 4)), Color("#b98a4a") * tint)
	draw_rect(Rect2(at + Vector2(-2, h - 1), Vector2(w + 4, 4)), Color("#b98a4a") * tint)
	for i in 3:
		draw_line(at + Vector2(3, 5 + i * 4), at + Vector2(w - 3, 5 + i * 4), Color(HudSkin.INK, 0.7) * tint, 1.0)

extends SceneTree
var n := 0
var vp: SubViewport

func _initialize() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(1024, 1024)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.size = Vector2(1024, 1024)
	bg.color = Color("140c18")
	vp.add_child(bg)
	var art := Node2D.new()
	art.draw.connect(func(): _draw_icon(art))
	vp.add_child(art)

func _draw_icon(ci: Node2D) -> void:
	var c := Vector2(512, 512)
	for i in 24:
		var r := 520.0 - i * 18.0
		ci.draw_circle(c + Vector2(0, 120), r, Color(0.9, 0.35, 0.12, 0.022))
	ci.draw_arc(c, 400, 0, TAU, 128, Color("9a6a3a"), 18, true)
	ci.draw_arc(c, 355, 0, TAU, 128, Color("9a6a3a"), 6, true)
	for i in 48:
		var a := TAU * i / 48.0
		ci.draw_line(c + Vector2.from_angle(a) * 362, c + Vector2.from_angle(a) * 392, Color("9a6a3a"), 10)
	ci.draw_line(c + Vector2(-260, 260), c + Vector2(200, -200), Color("120a12"), 34, true)
	ci.draw_line(c + Vector2(-260, 260), c + Vector2(200, -200), Color("a77a4a"), 20, true)
	var tip := PackedVector2Array([c + Vector2(290, -290), c + Vector2(225, -165), c + Vector2(190, -190), c + Vector2(165, -225)])
	ci.draw_colored_polygon(tip, Color("ffd27a"))
	for side in [-1.0, 1.0]:
		for i in 9:
			var a: float = PI * 0.5 + side * (0.35 + i * 0.27)
			var p: Vector2 = c + Vector2.from_angle(a) * 300.0
			var d: Vector2 = Vector2.from_angle(a + side * 1.3) * 60.0
			var nrm: Vector2 = d.orthogonal() * 0.35
			ci.draw_colored_polygon(PackedVector2Array([p, p + d * 0.5 + nrm, p + d, p + d * 0.5 - nrm]), Color("9cbf45"))
	for layer in 2:
		var off := Vector2(10, 12) if layer == 0 else Vector2.ZERO
		var col := Color("120a12") if layer == 0 else Color("ffd84a")
		var o := c + off
		ci.draw_rect(Rect2(o + Vector2(-170, -200), Vector2(340, 56)), col)
		ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-170, -200), o + Vector2(-150, -200), o + Vector2(-170, -120)]), col)
		ci.draw_colored_polygon(PackedVector2Array([o + Vector2(170, -200), o + Vector2(150, -200), o + Vector2(170, -120)]), col)
		ci.draw_rect(Rect2(o + Vector2(-40, -150), Vector2(80, 330)), col)
		ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-40, 120), o + Vector2(40, 120), o + Vector2(95, 180), o + Vector2(-95, 180)]), col)
	ci.draw_rect(Rect2(c + Vector2(-160, -196), Vector2(320, 10)), Color(1, 1, 1, 0.35))

func _process(_d) -> bool:
	n += 1
	if n == 6:
		var img := vp.get_texture().get_image()
		img.save_png("res://icon.png")
		print("icon saved ", img.get_size())
		quit()
	return false

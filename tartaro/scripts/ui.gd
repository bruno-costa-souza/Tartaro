class_name UI

const BG := Color("120f1c")
const PANEL := Color("17131f")
const GOLD := Color("ffd84a")
const MUTED := Color("c2bad6")
const BRONZE := Color("8a6a3a")
const EMBER := Color("ff7a3d")
const GLASS_TINT := Color(0.78, 0.74, 0.95)

const TITLE_FONT := preload("res://ui/title_font.tres")

static var _title_var: FontVariation


static func title_font() -> Font:
	if _title_var == null:
		_title_var = FontVariation.new()
		_title_var.base_font = TITLE_FONT
		_title_var.spacing_glyph = 2
	return _title_var


static func style(bg: Color, border: Color, width := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(6)
	s.anti_aliasing = true
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


static func empty_box(h := 12.0, v := 6.0) -> StyleBoxEmpty:
	var s := StyleBoxEmpty.new()
	s.content_margin_left = h
	s.content_margin_right = h
	s.content_margin_top = v
	s.content_margin_bottom = v
	return s


static func button(text: String, color: Color, font_size := 12, radius := 999.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(state, empty_box(14, 6))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.38))
	b.add_theme_constant_override("outline_size", 2)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	if font_size >= 18:
		b.add_theme_font_override("font", title_font())
	b.add_child(Glass.make(color, 0.28, radius))
	return b


static func label(text: String, font_size := 10, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	if font_size >= 18:
		l.add_theme_font_override("font", title_font())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap_label(text: String, font_size := 8, color := MUTED) -> Label:
	var l := label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func panel(tint := GLASS_TINT, amount := 0.1, radius := 18.0, margin := 12.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	p.add_child(Glass.make(tint, amount, radius))
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, int(margin))
	p.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	m.add_child(v)
	p.set_meta("body", v)
	return p


static func body(p: PanelContainer) -> VBoxContainer:
	return p.get_meta("body")


static func spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func icon(kind: String, px: float, color: Color) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): draw_icon(c, kind, c.size / 2, px * 0.5, color))
	return c


static func draw_icon(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(s * 0.16, 1.2)
	match kind:
		"heart":
			ci.draw_circle(c + Vector2(-s * 0.32, -s * 0.2), s * 0.38, col)
			ci.draw_circle(c + Vector2(s * 0.32, -s * 0.2), s * 0.38, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.68, -s * 0.08), c + Vector2(s * 0.68, -s * 0.08), c + Vector2(0, s * 0.72)]), col)
			ci.draw_circle(c + Vector2(-s * 0.38, -s * 0.32), s * 0.12, Color(1, 1, 1, 0.55))
		"coin":
			ci.draw_circle(c, s * 0.8, Color("b8860b"))
			ci.draw_circle(c, s * 0.62, col)
			ci.draw_arc(c, s * 0.42, 0, TAU, 16, Color("b8860b"), w * 0.6, true)
			ci.draw_circle(c + Vector2(-s * 0.25, -s * 0.3), s * 0.13, Color(1, 1, 1, 0.8))
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.45, -s * 0.55), Vector2(s * 0.3, s * 1.1)), col)
			ci.draw_rect(Rect2(c + Vector2(s * 0.15, -s * 0.55), Vector2(s * 0.3, s * 1.1)), col)
		"play", "flame":
			if kind == "play":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.4, -s * 0.6), c + Vector2(s * 0.6, 0), c + Vector2(-s * 0.4, s * 0.6)]), col)
			else:
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.85), c + Vector2(s * 0.5, -s * 0.05), c + Vector2(s * 0.45, s * 0.45), c + Vector2(0, s * 0.75), c + Vector2(-s * 0.45, s * 0.45), c + Vector2(-s * 0.5, -s * 0.05)]), col)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.2), c + Vector2(s * 0.22, s * 0.25), c + Vector2(0, s * 0.55), c + Vector2(-s * 0.22, s * 0.25)]), Color(1, 1, 1, 0.65))
		"gear":
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(c + Vector2.from_angle(a) * s * 0.45, c + Vector2.from_angle(a) * s * 0.85, col, s * 0.3)
			ci.draw_circle(c, s * 0.6, col)
			ci.draw_circle(c, s * 0.25, Color(0, 0, 0, 0.55))
		"spear":
			ci.draw_line(c + Vector2(-s * 0.75, s * 0.75), c + Vector2(s * 0.35, -s * 0.35), Color("a77a4a"), w, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.85, -s * 0.85), c + Vector2(s * 0.48, -s * 0.12), c + Vector2(s * 0.25, -s * 0.25), c + Vector2(s * 0.12, -s * 0.48)]), col)
		"bow":
			ci.draw_arc(c + Vector2(-s * 0.35, 0), s * 0.85, -1.1, 1.1, 16, Color("a77a4a"), w * 1.2, true)
			ci.draw_line(c + Vector2(-s * 0.35, 0) + Vector2.from_angle(-1.1) * s * 0.85, c + Vector2(-s * 0.35, 0) + Vector2.from_angle(1.1) * s * 0.85, Color(1, 1, 1, 0.7), w * 0.5, true)
			ci.draw_line(c + Vector2(-s * 0.5, 0), c + Vector2(s * 0.75, 0), col, w * 0.8, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.9, 0), c + Vector2(s * 0.6, -s * 0.18), c + Vector2(s * 0.6, s * 0.18)]), col)
		"sword":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.85, -s * 0.85), c + Vector2(s * 0.62, -s * 0.38), c + Vector2(-s * 0.2, s * 0.32), c + Vector2(-s * 0.32, s * 0.2), c + Vector2(s * 0.38, -s * 0.62)]), col)
			ci.draw_line(c + Vector2(-s * 0.5, s * 0.02), c + Vector2(-s * 0.02, s * 0.5), Color("d9a63a"), w * 1.3, true)
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.3), c + Vector2(-s * 0.75, s * 0.75), Color("6b4a2a"), w * 1.3, true)
		"bolt":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.15, -s * 0.9), c + Vector2(-s * 0.5, s * 0.1), c + Vector2(-s * 0.02, s * 0.1), c + Vector2(-s * 0.2, s * 0.9), c + Vector2(s * 0.5, -s * 0.15), c + Vector2(s * 0.02, -s * 0.15)]), col)
		"laurel":
			for side in [-1.0, 1.0]:
				ci.draw_arc(c + Vector2(0, -s * 0.1), s * 0.7, PI * 0.5 + side * 0.15, PI * 0.5 + side * 2.4, 12, col, w * 0.7, true)
				for i in 4:
					var a: float = PI * 0.5 + side * (0.6 + i * 0.45)
					var p: Vector2 = c + Vector2(0, -s * 0.1) + Vector2.from_angle(a) * s * 0.7
					var leaf: Vector2 = Vector2.from_angle(a + side * 1.2) * s * 0.28
					ci.draw_line(p, p + leaf, col, w * 1.4, true)
		"fist":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.55, -s * 0.35), Vector2(s * 1.1, s * 0.75)), col)
			for i in 4:
				ci.draw_line(c + Vector2(-s * 0.55 + i * s * 0.28, -s * 0.35), c + Vector2(-s * 0.55 + i * s * 0.28, s * 0.1), Color(0, 0, 0, 0.35), 1.0)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.35, s * 0.4), Vector2(s * 0.7, s * 0.4)), col.darkened(0.15))
		"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.55, 0), c + Vector2(-s * 0.15, s * 0.45), c + Vector2(s * 0.6, -s * 0.45)]), col, w * 1.3, true)
		"lock":
			ci.draw_arc(c + Vector2(0, -s * 0.15), s * 0.38, PI, TAU, 10, col, w, true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.55, -s * 0.15), Vector2(s * 1.1, s * 0.85)), col)
		"skull":
			ci.draw_circle(c + Vector2(0, -s * 0.12), s * 0.62, col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.35, s * 0.25), Vector2(s * 0.7, s * 0.4)), col)
			ci.draw_circle(c + Vector2(-s * 0.24, -s * 0.1), s * 0.17, Color(0, 0, 0, 0.8))
			ci.draw_circle(c + Vector2(s * 0.24, -s * 0.1), s * 0.17, Color(0, 0, 0, 0.8))

		_:
			_draw_god_icon(ci, kind, c, s, col, w)

static func weapon_icon(id: String) -> String:
	return {"lanca": "spear", "arco": "bow", "espada": "sword", "cetro": "bolt"}.get(id, "spear")


static func safe_top(vp_width: float) -> float:
	if not OS.has_feature("mobile"):
		return 8.0
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x <= 0:
		return 8.0
	return maxf(8.0, safe.position.y * vp_width / win.x + 2.0)


static func safe_bottom(vp_width: float) -> float:
	if not OS.has_feature("mobile"):
		return 8.0
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var screen := DisplayServer.screen_get_size()
	if win.x <= 0:
		return 8.0
	return maxf(8.0, (screen.y - safe.end.y) * vp_width / win.x + 2.0)


static func _draw_god_icon(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color, w: float) -> void:
	match kind:
		"trident":
			ci.draw_line(c + Vector2(0, s * 0.9), c + Vector2(0, -s * 0.5), col, w * 1.2, true)
			ci.draw_arc(c + Vector2(0, -s * 0.35), s * 0.45, 0.0, PI, 12, col, w * 1.1, true)
			for x in [-0.45, 0.0, 0.45]:
				var top := c + Vector2(s * x, -s * 0.9)
				ci.draw_line(c + Vector2(s * x, -s * 0.35), top, col, w * 1.1, true)
				ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-s * 0.1, s * 0.12), top + Vector2(0, -s * 0.12), top + Vector2(s * 0.1, s * 0.12)]), col)
		"sun":
			ci.draw_circle(c, s * 0.42, col)
			for i in 12:
				var a := TAU * i / 12.0
				ci.draw_line(c + Vector2.from_angle(a) * s * 0.55, c + Vector2.from_angle(a) * s * (0.95 if i % 2 == 0 else 0.78), col, w, true)
		"wing":
			for i in 4:
				var y := -s * 0.5 + i * s * 0.28
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.7, y), c + Vector2(s * (0.8 - i * 0.18), y - s * 0.22), c + Vector2(s * (0.7 - i * 0.18), y + s * 0.08), c + Vector2(-s * 0.6, y + s * 0.18)]), col)
		"hammer":
			ci.draw_line(c + Vector2(-s * 0.6, s * 0.75), c + Vector2(s * 0.25, -s * 0.1), Color("a77a4a"), w * 1.4, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.05, -s * 0.75), c + Vector2(s * 0.85, s * 0.05), c + Vector2(s * 0.55, s * 0.35), c + Vector2(-s * 0.35, -s * 0.45)]), col)
		"shield":
			ci.draw_circle(c, s * 0.85, col)
			ci.draw_circle(c, s * 0.62, col.darkened(0.35))
			ci.draw_circle(c, s * 0.22, col)
		"grapes":
			for p in [Vector2(-0.3, -0.25), Vector2(0.3, -0.25), Vector2(0, -0.25), Vector2(-0.15, 0.1), Vector2(0.15, 0.1), Vector2(0, 0.45)]:
				ci.draw_circle(c + p * s, s * 0.22, col)
			ci.draw_line(c + Vector2(0, -s * 0.5), c + Vector2(s * 0.2, -s * 0.9), Color("6b8f3a"), w, true)
		"wheat":
			ci.draw_line(c + Vector2(0, s * 0.9), c + Vector2(0, -s * 0.8), col, w * 0.8, true)
			for i in 5:
				var y := -s * 0.7 + i * s * 0.3
				for side in [-1.0, 1.0]:
					var p := c + Vector2(0, y)
					ci.draw_colored_polygon(PackedVector2Array([p, p + Vector2(side * s * 0.35, -s * 0.1), p + Vector2(side * s * 0.15, s * 0.12)]), col)
		"snow":
			for i in 3:
				var d := Vector2.from_angle(PI * i / 3.0) * s * 0.85
				ci.draw_line(c - d, c + d, col, w, true)
			ci.draw_circle(c, s * 0.15, col)
		"moon":
			ci.draw_circle(c, s * 0.75, col)
			ci.draw_circle(c + Vector2(s * 0.35, -s * 0.2), s * 0.62, Color(0.06, 0.04, 0.1, 1.0))
		"key":
			ci.draw_arc(c + Vector2(0, -s * 0.45), s * 0.3, 0, TAU, 16, col, w * 1.2, true)
			ci.draw_line(c + Vector2(0, -s * 0.15), c + Vector2(0, s * 0.85), col, w * 1.2, true)
			ci.draw_line(c + Vector2(0, s * 0.55), c + Vector2(s * 0.3, s * 0.55), col, w * 1.2, true)
			ci.draw_line(c + Vector2(0, s * 0.8), c + Vector2(s * 0.25, s * 0.8), col, w * 1.2, true)
		"swirl":
			var pts := PackedVector2Array()
			for i in 40:
				var t := i / 39.0
				pts.append(c + Vector2.from_angle(t * TAU * 1.6) * s * (0.1 + 0.8 * t))
			ci.draw_polyline(pts, col, w * 1.2, true)
		"scales":
			ci.draw_line(c + Vector2(0, -s * 0.8), c + Vector2(0, s * 0.8), col, w, true)
			ci.draw_line(c + Vector2(-s * 0.75, -s * 0.5), c + Vector2(s * 0.75, -s * 0.5), col, w, true)
			for side in [-1.0, 1.0]:
				ci.draw_arc(c + Vector2(side * s * 0.6, -s * 0.05), s * 0.3, 0, PI, 10, col, w, true)
			ci.draw_line(c + Vector2(-s * 0.4, s * 0.8), c + Vector2(s * 0.4, s * 0.8), col, w * 1.3, true)
		"rainbow":
			var cols := [Color("ff5e57"), Color("ffb142"), Color("ffd84a"), Color("9be36d"), Color("4aa3ff"), Color("c56cff")]
			for i in cols.size():
				ci.draw_arc(c + Vector2(0, s * 0.4), s * (0.9 - i * 0.12), PI, TAU, 20, cols[i], w * 0.8, true)

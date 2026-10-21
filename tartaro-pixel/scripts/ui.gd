class_name UI

const BG := Color("120f1c")
const PANEL := Color("1c1828")
const GOLD := Color("ffd84a")
const MUTED := Color("a49cbf")


static func style(bg: Color, border: Color, width := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(4)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


static func button(text: String, color: Color, font_size := 12) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", style(color.darkened(0.6), color))
	b.add_theme_stylebox_override("hover", style(color.darkened(0.45), color.lightened(0.2)))
	b.add_theme_stylebox_override("pressed", style(color.darkened(0.2), Color.WHITE))
	b.add_theme_stylebox_override("disabled", style(Color("1a1822"), Color("34303f")))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("5f5a70"))
	b.add_theme_constant_override("outline_size", 3)
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	return b


static func label(text: String, font_size := 10, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap_label(text: String, font_size := 8, color := MUTED) -> Label:
	var l := label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var s := style(PANEL, Color("2e2842"), 1)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", s)
	return p


static func safe_top(vp_width: float) -> float:
	if not OS.has_feature("mobile"):
		return 6.0
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x <= 0:
		return 6.0
	return maxf(6.0, safe.position.y * vp_width / win.x + 2.0)

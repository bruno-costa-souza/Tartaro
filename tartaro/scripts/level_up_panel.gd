class_name LevelUpPanel
extends CanvasLayer

## Boon choice: a level-up ribbon and the god's bust with their line on top,
## and big boon cards below (Hades-style cards with rarity ribbons; owned
## boons show the level and value they go from and to).

signal chosen(offer: Dictionary)

const INPUT_DELAY := 0.95
const TYPE_SPEED := 40.0
const CARD_GAP := 10.0
const HEADER_MIN := 236.0
const PORTRAIT_CROP := Rect2(0, 0, 600, 640)
const RARITY_NAMES := ["Comum", "Rara", "Épica", "Lendária"]

var title := ""
var offers: Array = []
var picks: Dictionary = {}
var totals: Dictionary = {}
var god := "olimpo"
var voiced := true

var _root: Control
var _vp := Vector2(360, 640)
var _buttons: Array[Button] = []
var _portrait: TextureRect
var _glow: TextureRect
var _medal: Control
var _backdrop: Control
var _dialog: Label
var _t := 0.0
var _typed := 0
var _god_color := Color("ffd84a")
var _closing := false
var _portrait_rect := Rect2()
var _card_h := 120.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_god_color = BoonArt.god_color(god) if god != "olimpo" else (offers[0]["color"] if not offers.is_empty() else UI.GOLD)
	var info: Dictionary = GameData.GODS.get(god, GameData.GODS["olimpo"])

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_vp = _root.get_viewport_rect().size
	var top := UI.safe_top(_vp.x)
	var bottom := UI.safe_bottom(_vp.x)

	var frost := Glass.make(Color(0.03, 0.015, 0.06), 0.72, 0.0)
	frost.blur = 5.0
	frost.edge_light = 0.0
	frost.refraction = 0.0
	_root.add_child(frost)

	var n := maxi(offers.size(), 1)
	var avail := _vp.y - top - bottom - 24.0
	_card_h = clampf((avail - HEADER_MIN) / n - CARD_GAP, 110.0, 142.0)
	var cards_h := n * _card_h + (n - 1) * CARD_GAP
	var cards_top := _vp.y - bottom - 22.0 - cards_h
	var ph := clampf(cards_top - top + 34.0, 200.0, 330.0)
	var pw := ph * PORTRAIT_CROP.size.x / PORTRAIT_CROP.size.y
	_portrait_rect = Rect2(Vector2(-pw * 0.1, cards_top + 34.0 - ph), Vector2(pw, ph))

	_backdrop = Control.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.draw.connect(_draw_backdrop)
	_root.add_child(_backdrop)
	_root.add_child(_particles())

	var tex := BoonArt.portrait(god)
	if tex:
		_portrait = _portrait_node(_crop(tex), null)
		var glow_tex := BoonArt.portrait_glow(god)
		if glow_tex:
			_glow = _portrait_node(_crop(glow_tex), Art.additive())
		var fade := Control.new()
		fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.draw.connect(func():
			var y0 := _portrait_rect.position.y + _portrait_rect.size.y * 0.62
			var y1 := _portrait_rect.end.y + 2.0
			var dark := Color(0.02, 0.01, 0.03, 0.96)
			fade.draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(_vp.x, y0), Vector2(_vp.x, y1), Vector2(0, y1)]),
				PackedColorArray([Color(dark, 0.0), Color(dark, 0.0), dark, dark]))
			fade.draw_rect(Rect2(0, y1, _vp.x, _vp.y - y1), dark))
		_root.add_child(fade)
	else:
		_medal = Control.new()
		_medal.position = Vector2(4, top + 30)
		_medal.size = Vector2(_vp.x * 0.5, cards_top - top - 30)
		_medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_medal.draw.connect(_draw_medal.bind(info["emblem"]))
		_root.add_child(_medal)

	var head := _title_block(info, top)
	_root.add_child(head)

	var box := VBoxContainer.new()
	box.position = Vector2(12, cards_top)
	box.size = Vector2(_vp.x - 24, cards_h)
	box.add_theme_constant_override("separation", int(CARD_GAP))
	_root.add_child(box)
	for i in offers.size():
		var card := _card(offers[i], i)
		box.add_child(card)
		_buttons.append(card)

	var hint := UI.label("Toque em uma bênção", 9, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, _vp.y - bottom - 17)
	hint.size = Vector2(_vp.x, 12)
	_root.add_child(hint)

	_play_intro(head)


func _crop(tex: Texture2D) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = PORTRAIT_CROP
	return at


func _portrait_node(tex: Texture2D, mat: Material) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	r.position = _portrait_rect.position
	r.size = _portrait_rect.size
	r.pivot_offset = _portrait_rect.size * Vector2(0.5, 0.9)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = mat
	_root.add_child(r)
	return r


func _title_block(info: Dictionary, top: float) -> Control:
	var x0 := _vp.x * 0.5
	var v := VBoxContainer.new()
	v.position = Vector2(x0 - 6.0, top + 14.0)
	v.size = Vector2(_vp.x - x0 - 6.0, 0)
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if title != "":
		v.add_child(_ribbon(title))
		v.add_child(UI.spacer(2))
	var pre := UI.label("BÊNÇÃOS DE" if god != "olimpo" else "DÁDIVA DO", 10, Color(1, 0.92, 0.78, 0.75))
	pre.add_theme_font_override("font", _spaced(UI.title_font(), 3))
	v.add_child(pre)
	var god_name := String(info["name"])
	var name_label := UI.label(god_name, 34 if god_name.length() <= 7 else 28, Art.hdr(_god_color.lightened(0.3), 1.3))
	name_label.add_theme_font_override("font", _spaced(UI.title_font(), 2))
	name_label.add_theme_constant_override("outline_size", 6)
	name_label.add_theme_color_override("font_outline_color", Color(_god_color.darkened(0.8), 0.9))
	v.add_child(name_label)
	var epithet := UI.label(String(info["epithet"]), 10, Color(1, 1, 1, 0.7))
	epithet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(epithet)
	var orn := Control.new()
	orn.custom_minimum_size = Vector2(0, 12)
	orn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orn.draw.connect(func():
		var y := 6.0
		var w := orn.size.x
		orn.draw_line(Vector2(0, y), Vector2(w * 0.4, y), Color(_god_color, 0.7), 1.0, true)
		orn.draw_line(Vector2(w * 0.6, y), Vector2(w, y), Color(_god_color, 0.15), 1.0, true)
		var c := Vector2(w * 0.5, y)
		orn.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(5, 0), c + Vector2(0, 4), c + Vector2(-5, 0)]), Art.hdr(_god_color, 1.3))
		orn.draw_circle(c + Vector2(-12, 0), 1.5, Color(_god_color, 0.8))
		orn.draw_circle(c + Vector2(12, 0), 1.5, Color(_god_color, 0.5)))
	v.add_child(orn)
	_dialog = UI.wrap_label("", 12, Color(1, 0.96, 0.88))
	var n := Divine.next_line(god)
	_dialog.text = "“%s”" % Divine.line_text(god, n)
	_dialog.visible_characters = 0
	v.add_child(_dialog)
	v.set_meta("line", n)
	return v


func _ribbon(text: String) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 24)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UI.label(text.to_upper(), 11, Color(0.18, 0.09, 0.02), HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", _spaced(UI.title_font(), 2))
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.25))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(l)
	c.draw.connect(func():
		var w := c.size.x
		var h := c.size.y
		var notch := 8.0
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - notch, h * 0.5), Vector2(w, h), Vector2(0, h), Vector2(notch, h * 0.5)])
		var gold := UI.GOLD
		c.draw_polygon(pts, PackedColorArray([Art.hdr(gold, 1.15), Art.hdr(gold, 1.15), gold, gold.darkened(0.25), gold.darkened(0.25), gold]))
		var shine := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - notch * 0.5, h * 0.25), Vector2(notch * 0.5, h * 0.25)])
		c.draw_colored_polygon(shine, Color(1, 1, 1, 0.25)))
	return c


func _spaced(base: Font, spacing: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = base
	f.spacing_glyph = spacing
	return f


func _particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.material = Art.additive()
	p.position = _portrait_rect.get_center() + Vector2(_portrait_rect.size.x * 0.1, 0)
	p.amount = 34
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(_vp.x * 0.5, _portrait_rect.size.y * 0.5)
	var falling := god in ["boreas", "selene", "iris"]
	p.direction = Vector2.DOWN if falling else Vector2.UP
	p.spread = 30.0
	p.gravity = Vector2(0, 6 if falling else -10)
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 22.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 2.0
	p.color = Art.hdr(_god_color.lightened(0.3), 2.0)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	return p


func _play_intro(head: Control) -> void:
	_root.modulate.a = 0.0
	head.modulate.a = 0.0
	var line: int = head.get_meta("line")
	Divine.stinger(god)
	_sfx("boon_appear")
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(_root, "modulate:a", 1.0, 0.18)
	for node: TextureRect in [_portrait, _glow]:
		if node:
			var end: Vector2 = node.position
			node.position = end + Vector2(-70, 0)
			node.modulate.a = 0.0
			t.parallel().tween_property(node, "position", end, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(node, "modulate:a", 1.0, 0.35)
	if _medal:
		_medal.pivot_offset = _medal.size * 0.5
		_medal.scale = Vector2(0.4, 0.4)
		t.parallel().tween_property(_medal, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	head.position.x += 30
	t.parallel().tween_property(head, "modulate:a", 1.0, 0.35).set_delay(0.15)
	t.parallel().tween_property(head, "position:x", head.position.x - 30, 0.4).set_delay(0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		if voiced:
			Divine.speak(god, line))
	for i in _buttons.size():
		var card := _buttons[i]
		card.modulate.a = 0.0
		var plate: Control = card.get_child(0)
		plate.position.x = 60.0
		var ct := create_tween().set_ignore_time_scale(true)
		ct.tween_interval(0.28 + 0.11 * i)
		ct.tween_callback(func(): _sfx("card_in", 0.9 + 0.08 * i))
		ct.tween_property(card, "modulate:a", 1.0, 0.2)
		ct.parallel().tween_property(plate, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var enable := create_tween().set_ignore_time_scale(true)
	enable.tween_interval(INPUT_DELAY)
	enable.tween_callback(func():
		for b in _buttons:
			b.disabled = false)


func _process(delta: float) -> void:
	_t += delta
	_backdrop.queue_redraw()
	if _medal:
		_medal.queue_redraw()
	if _portrait and not _closing:
		var bob := sin(_t * 1.6) * 2.0
		var s := 1.0 + 0.008 * sin(_t * 1.6 + 0.6)
		if _portrait.modulate.a >= 1.0:
			_portrait.position.y = _portrait_rect.position.y + bob
			_portrait.scale = Vector2(s, s)
	if _glow and not _closing:
		_glow.position = _portrait.position
		_glow.scale = _portrait.scale
		var pulse := 0.45 + 0.25 * sin(_t * 3.1) + 0.08 * sin(_t * 7.3)
		_glow.self_modulate = Color(pulse, pulse, pulse)
	if _t > 0.7 and _dialog.visible_characters < _dialog.text.length():
		var target := int((_t - 0.7) * TYPE_SPEED)
		if target > _dialog.visible_characters:
			_dialog.visible_characters = target
			if target / 2 != _typed:
				_typed = target / 2
				_sfx("tick", randf_range(0.9, 1.15))
	for b in _buttons:
		b.get_child(0).queue_redraw()


func _draw_backdrop() -> void:
	var c := _portrait_rect.position + _portrait_rect.size * Vector2(0.55, 0.4)
	var col := _god_color
	for i in 14:
		var a := _t * 0.12 + TAU * i / 14.0
		var d := Vector2.from_angle(a)
		var n := d.orthogonal()
		var reach := _vp.x * (0.75 + 0.1 * sin(_t * 1.3 + i * 1.7))
		_backdrop.draw_colored_polygon(PackedVector2Array([c + n * 3.0, c + d * reach + n * 26.0, c + d * reach - n * 26.0, c - n * 3.0]),
			Color(col.r, col.g, col.b, 0.045))
	Art.glow(_backdrop, c, _vp.x * 0.62, col, 0.42 + 0.05 * sin(_t * 2.0))
	Art.glow(_backdrop, c + Vector2(0, -20), _vp.x * 0.3, col.lightened(0.4), 0.25)


func _draw_medal(emblem: String) -> void:
	var c := _medal.size * Vector2(0.5, 0.5)
	var col := _god_color
	for i in 16:
		var a := _t * 0.35 + TAU * i / 16.0
		var d := Vector2.from_angle(a)
		var n := d.orthogonal()
		var len := 70.0 + 10.0 * sin(_t * 2.0 + i * 1.3)
		_medal.draw_colored_polygon(PackedVector2Array([c + n * 4.0, c + d * len, c - n * 4.0]), Color(col.r * 1.3, col.g * 1.3, col.b * 1.3, 0.28))
	Art.glow(_medal, c, 86.0, col, 0.55 + 0.1 * sin(_t * 3.0))
	_medal.draw_circle(c, 52.0, Color(0, 0, 0, 0.5))
	_medal.draw_circle(c, 49.0, Color(col.darkened(0.75), 0.95))
	_medal.draw_arc(c, 52.0, 0, TAU, 64, Art.hdr(UI.GOLD, 1.2), 2.5, true)
	_medal.draw_arc(c, 45.0, 0, TAU, 64, Color(col, 0.6), 1.2, true)
	if not BoonArt.draw_emblem(_medal, god, c, 78.0):
		UI.draw_icon(_medal, emblem, c, 28.0, Art.hdr(col.lightened(0.35), 1.35))


# ---------------------------------------------------------------- cards

func _card(offer: Dictionary, index: int) -> Button:
	var color: Color = offer["color"]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = true
	b.custom_minimum_size = Vector2(0, _card_h)
	for state in ["normal", "disabled", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())

	var plate := Control.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.draw.connect(_draw_card.bind(plate, b, offer, index))
	b.add_child(plate)

	var text_x := 100.0
	var text_w := _vp.x - 24.0 - text_x - 14.0
	var tag_w := _rarity_width(offer)
	var name_text := String(offer["name"]).to_upper()
	var name_font := _spaced(UI.title_font(), 1)
	var name_size := 15
	while name_size > 11 and name_font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > text_w - tag_w - 6.0:
		name_size -= 1
	var name_label := UI.label(name_text, name_size, color.lightened(0.45))
	name_label.add_theme_font_override("font", name_font)
	name_label.position = Vector2(text_x, 10 + (15 - name_size) * 0.5)
	name_label.size = Vector2(text_w - tag_w - 2.0, 20)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	plate.add_child(name_label)

	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.scroll_active = false
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.position = Vector2(text_x, 34)
	desc.size = Vector2(text_w, _card_h - 34.0 - 28.0)
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("normal_font_size", 12)
	desc.add_theme_color_override("default_color", Color(1, 1, 1, 0.92))
	desc.add_theme_constant_override("outline_size", 2)
	desc.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	desc.text = BoonArt.rich_desc(String(offer["desc"]), UI.GOLD.lightened(0.2))
	plate.add_child(desc)

	var stat := RichTextLabel.new()
	stat.bbcode_enabled = true
	stat.scroll_active = false
	stat.autowrap_mode = TextServer.AUTOWRAP_OFF
	stat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stat.position = Vector2(text_x, _card_h - 26.0)
	stat.size = Vector2(text_w - 64.0, 16)
	stat.add_theme_font_size_override("normal_font_size", 10)
	stat.add_theme_color_override("default_color", Color(1, 1, 1, 0.65))
	stat.text = _stat_text(offer)
	plate.add_child(stat)

	b.pressed.connect(_pick.bind(offer, b))
	b.button_down.connect(func(): b.scale = Vector2(0.98, 0.98))
	b.button_up.connect(func(): b.scale = Vector2.ONE)
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	return b


func _rarity_width(offer: Dictionary) -> float:
	var tier := int(offer.get("tier", -1))
	var text: String = "DUO" if offer.get("duo", false) else (RARITY_NAMES[tier].to_upper() if tier >= 0 else "")
	if text == "":
		return 0.0
	return _spaced(UI.title_font(), 2).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 18.0


## "▸ Dano extra: +20% → +50%" for boons already owned, "+30%" for new ones.
func _stat_text(offer: Dictionary) -> String:
	var gold := UI.GOLD.lightened(0.25).to_html(false)
	if offer.get("duo", false):
		var duo_line: Array = BoonArt.stat_line(offer)
		return "▸ %s: [color=#%s]%s[/color]" % [duo_line[0], gold, duo_line[1]]
	var id: String = offer["id"]
	var st: Array = BoonArt.STATS.get(id, ["", ""])
	if st[0] == "":
		return ""
	var fmt: String = st[1]
	var lvl := int(picks.get(id, 0))
	if not fmt.contains("%s"):
		if lvl == 0 or id == "ambrosia":
			return "▸ %s: [color=#%s]%s[/color]" % [st[0], gold, fmt]
		return "▸ %s: +%d → [color=#%s]+%d[/color]" % [st[0], lvl, gold, lvl + 1]
	var per := float(offer.get("per", 0.0))
	var before := per * float(totals.get(id, 0.0))
	var after := before + per * float(offer.get("mult", 1.0))
	if lvl == 0:
		return "▸ %s: [color=#%s]%s[/color]" % [st[0], gold, fmt % _num(after)]
	return "▸ %s: %s → [color=#%s]%s[/color]" % [st[0], fmt % _num(before), gold, fmt % _num(after)]


func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


func _card_poly(w: float, h: float) -> PackedVector2Array:
	var cut := 12.0
	return PackedVector2Array([Vector2(0, 0), Vector2(w - cut, 0), Vector2(w, cut), Vector2(w, h), Vector2(cut, h), Vector2(0, h - cut)])


func _draw_card(plate: Control, b: Button, offer: Dictionary, index: int) -> void:
	var w := plate.size.x
	var h := plate.size.y
	var color: Color = offer["color"]
	var tier := int(offer.get("tier", -1))
	var duo: bool = offer.get("duo", false)
	var frame_col: Color = GameData.DUO_COLOR if duo else (GameData.RARITIES[tier]["color"] if tier >= 0 else UI.GOLD)
	var pressed := b.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]
	var lift := 1.25 if pressed else 1.0

	var poly := _card_poly(w, h)
	var left := Color(color.darkened(0.6).lerp(Color(0.05, 0.02, 0.08), 0.25), 0.95)
	var right := Color(0.03, 0.015, 0.05, 0.94)
	plate.draw_polygon(poly, PackedColorArray([left * lift, right, right, right, left * lift, left * lift]))
	var sheen := PackedVector2Array([Vector2(0, 0), Vector2(w - 12, 0), Vector2(w - 12, h * 0.42), Vector2(0, h * 0.5)])
	plate.draw_polygon(sheen, PackedColorArray([Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
	if tier >= 2 or duo:
		var x := fmod(_t * 0.55 + index * 0.37, 1.6) * (w + 120.0) - 60.0
		var band := PackedVector2Array([Vector2(x, 0), Vector2(x + 26, 0), Vector2(x - 14, h), Vector2(x - 40, h)])
		for part in Geometry2D.intersect_polygons(band, poly):
			plate.draw_colored_polygon(part, Color(frame_col.r, frame_col.g, frame_col.b, 0.14))
	var loop := poly.duplicate()
	loop.append(poly[0])
	plate.draw_polyline(loop, Color(color.lightened(0.2), 0.55 * lift), 1.2, true)
	plate.draw_line(Vector2(w - 12, 0), Vector2(w, 12), Art.hdr(frame_col, 1.3), 2.0, true)
	plate.draw_line(Vector2(0, h - 12), Vector2(12, h), Art.hdr(frame_col, 1.3), 2.0, true)

	var rarity_text: String = "DUO" if duo else (RARITY_NAMES[tier].to_upper() if tier >= 0 else "")
	if rarity_text != "":
		var font := _spaced(UI.title_font(), 2)
		var tw := _rarity_width(offer)
		var rx := w - 14.0 - tw
		var tag := PackedVector2Array([Vector2(rx + 6, 8), Vector2(rx + tw, 8), Vector2(rx + tw - 6, 24), Vector2(rx, 24)])
		plate.draw_colored_polygon(tag, Color(frame_col.darkened(0.55), 0.95))
		var tl := tag.duplicate()
		tl.append(tag[0])
		plate.draw_polyline(tl, Art.hdr(frame_col, 1.25), 1.2, true)
		plate.draw_string(font, Vector2(rx + 9, 20), rarity_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Art.hdr(frame_col.lightened(0.3), 1.2))

	var id: String = offer["id"]
	if not duo and id != "ambrosia":
		var lvl := int(picks.get(id, 0))
		var max_lvl := int(offer.get("max", 1))
		var by := h - 19.0
		if lvl == 0:
			plate.draw_string(_spaced(UI.title_font(), 2), Vector2(w - 62, by + 4), "NOVO", HORIZONTAL_ALIGNMENT_RIGHT, 48, 10, Art.hdr(UI.GOLD, 1.2))
		else:
			var n := mini(max_lvl, 6)
			var pw := 7.0
			var gap := 3.0
			var x0 := w - 16.0 - n * (pw + gap)
			for i in n:
				var r := Rect2(x0 + i * (pw + gap), by - 3, pw, 6)
				if i < lvl:
					plate.draw_rect(r, Art.hdr(color, 1.2))
				elif i == lvl:
					var pulse := 0.6 + 0.4 * sin(_t * 6.0)
					plate.draw_rect(r, Art.hdr(UI.GOLD, 1.0 + pulse))
				else:
					plate.draw_rect(r, Color(1, 1, 1, 0.14))

	var ic := Vector2(50, h * 0.5)
	_draw_frame(plate, ic, 38.0, frame_col, color, tier)
	if duo:
		BoonArt.draw_emblem(plate, offer["gods"][0], ic + Vector2(-10, -7), 50.0)
		BoonArt.draw_emblem(plate, offer["gods"][1], ic + Vector2(11, 9), 50.0)
	else:
		var g := BoonArt.god_of(offer)
		if not BoonArt.draw_emblem(plate, g, ic, 62.0):
			UI.draw_icon(plate, GameData.GODS[g]["emblem"], ic, 20.0, Art.hdr(color.lightened(0.35), 1.3))
	plate.draw_line(Vector2(98, 31), Vector2(w - 16, 31), Color(color, 0.22), 1.0)


func _draw_frame(ci: Control, c: Vector2, r: float, frame_col: Color, god_col: Color, tier: int) -> void:
	var sq := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	var inner := PackedVector2Array()
	for p in sq:
		inner.append(c + (p - c) * 0.86)
	Art.glow(ci, c, r * 1.5, god_col, 0.35 + 0.08 * sin(_t * 2.4))
	ci.draw_colored_polygon(sq, Color(0.02, 0.01, 0.03, 0.95))
	ci.draw_colored_polygon(inner, Color(god_col.darkened(0.72), 1.0))
	var ring := sq.duplicate()
	ring.append(sq[0])
	ci.draw_polyline(ring, Art.hdr(frame_col, 1.25), 2.4, true)
	var ring2 := inner.duplicate()
	ring2.append(inner[0])
	ci.draw_polyline(ring2, Color(frame_col, 0.45), 1.0, true)
	for p in sq:
		ci.draw_circle(p, 3.0, Art.hdr(frame_col, 1.4))
	if tier >= 3:
		for k in 4:
			var a := _t * 1.2 + TAU * k / 4.0
			ci.draw_circle(c + Vector2.from_angle(a) * r * 1.08, 1.6, Art.hdr(frame_col, 2.0))


func _pick(offer: Dictionary, card: Button) -> void:
	if _closing:
		return
	_closing = true
	for b in _buttons:
		b.disabled = true
	_sfx("boon_pick")
	Divine.stinger(BoonArt.god_of(offer), -8.0)
	if Save.haptics and OS.has_feature("mobile"):
		Input.vibrate_handheld(40)
	card.pivot_offset = card.size / 2
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(card, "scale", Vector2(1.05, 1.05), 0.12).set_trans(Tween.TRANS_BACK)
	t.parallel().tween_property(card, "modulate", Color(1.7, 1.7, 1.7), 0.12)
	for b in _buttons:
		if b != card:
			t.parallel().tween_property(b, "modulate:a", 0.0, 0.22)
			t.parallel().tween_property(b.get_child(0), "position:x", 80.0, 0.22)
	t.tween_property(card, "modulate", Color.WHITE, 0.16)
	for node in [_portrait, _glow]:
		if node:
			t.parallel().tween_property(node, "modulate:a", 0.0, 0.3)
	t.tween_property(_root, "modulate:a", 0.0, 0.22)
	t.tween_callback(func():
		chosen.emit(offer)
		queue_free())


func _sfx(sound: String, pitch := 1.0) -> void:
	var s := Sfx.stream(sound)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = "Sfx"
	p.pitch_scale = pitch
	p.volume_db = Sfx.volume(sound) + 1.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

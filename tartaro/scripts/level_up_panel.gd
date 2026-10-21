class_name LevelUpPanel
extends CanvasLayer

signal chosen(offer: Dictionary)

const INPUT_DELAY := 0.85
const TYPE_SPEED := 38.0

var title := ""
var offers: Array = []
var picks: Dictionary = {}
var god := "olimpo"
var voiced := true

var _root: Control
var _buttons: Array[Button] = []
var _medal: Control
var _dialog: Label
var _t := 0.0
var _typed := 0
var _god_color := Color("ffd84a")
var _closing := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_god_color = offers[0]["color"] if not offers.is_empty() else UI.GOLD
	var info: Dictionary = GameData.GODS.get(god, GameData.GODS["olimpo"])

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var vp := _root.get_viewport_rect().size

	var frost := Glass.make(Color(0.04, 0.02, 0.08), 0.6, 0.0)
	frost.blur = 4.5
	frost.edge_light = 0.0
	frost.refraction = 0.0
	_root.add_child(frost)
	var aura := Control.new()
	aura.set_anchors_preset(Control.PRESET_FULL_RECT)
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aura.draw.connect(func():
		Art.glow(aura, Vector2(vp.x / 2, vp.y * 0.2), vp.x * 0.75, _god_color, 0.35))
	_root.add_child(aura)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", int(UI.safe_top(vp.x)) + 10)
	margin.add_theme_constant_override("margin_bottom", int(UI.safe_bottom(vp.x)) + 10)
	_root.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	if title != "":
		box.add_child(UI.label(title, 11, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	_medal = Control.new()
	_medal.custom_minimum_size = Vector2(0, 128)
	_medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medal.draw.connect(_draw_medal.bind(info["emblem"]))
	box.add_child(_medal)

	var name_label := UI.label(info["name"], 30, Art.hdr(_god_color.lightened(0.25), 1.25), HORIZONTAL_ALIGNMENT_CENTER)
	name_label.add_theme_constant_override("outline_size", 0)
	box.add_child(name_label)
	box.add_child(UI.label(String(info["epithet"]).to_upper(), 8, Color(1, 1, 1, 0.65), HORIZONTAL_ALIGNMENT_CENTER))

	var dlg := UI.panel(_god_color, 0.1, 16.0, 10.0)
	_dialog = UI.wrap_label("", 12, Color(1, 0.97, 0.9))
	_dialog.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog.custom_minimum_size.y = 18
	var n := Divine.next_line(god)
	_dialog.text = "“%s”" % Divine.line_text(god, n)
	_dialog.visible_characters = 0
	UI.body(dlg).add_child(_dialog)
	box.add_child(dlg)
	box.add_child(UI.spacer(2))

	for i in offers.size():
		var card := _card(offers[i])
		box.add_child(card)
		_buttons.append(card)
		card.modulate.a = 0.0

	box.add_child(UI.label("Toque em uma bênção", 8, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_CENTER))
	_play_intro(n, name_label, dlg)


func _play_intro(line: int, name_label: Control, dlg: Control) -> void:
	_root.modulate.a = 0.0
	_medal.pivot_offset = Vector2(_root.get_viewport_rect().size.x / 2 - 16, 64)
	_medal.scale = Vector2(0.4, 0.4)
	name_label.modulate.a = 0.0
	dlg.modulate.a = 0.0
	Divine.stinger(god)
	_sfx("boon_appear")
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(_root, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(_medal, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(name_label, "modulate:a", 1.0, 0.2)
	t.tween_property(dlg, "modulate:a", 1.0, 0.15)
	t.tween_callback(func():
		if voiced:
			Divine.speak(god, line))
	for i in _buttons.size():
		var card := _buttons[i]
		t.tween_callback(func(): _sfx("card_in", 0.9 + 0.08 * i))
		t.tween_property(card, "modulate:a", 1.0, 0.16)
	var enable := create_tween().set_ignore_time_scale(true)
	enable.tween_interval(INPUT_DELAY)
	enable.tween_callback(func():
		for b in _buttons:
			b.disabled = false)


func _process(delta: float) -> void:
	_t += delta
	_medal.queue_redraw()
	if _t > 0.75 and _dialog.visible_characters < _dialog.text.length():
		var target := int((_t - 0.75) * TYPE_SPEED)
		if target > _dialog.visible_characters:
			_dialog.visible_characters = target
			if target / 2 != _typed:
				_typed = target / 2
				_sfx("tick", randf_range(0.9, 1.15))


func _draw_medal(emblem: String) -> void:
	var c := Vector2(_medal.size.x / 2, 64)
	var col := _god_color
	for i in 16:
		var a := _t * 0.35 + TAU * i / 16.0
		var d := Vector2.from_angle(a)
		var n := d.orthogonal()
		var len := 58.0 + 8.0 * sin(_t * 2.0 + i * 1.3)
		_medal.draw_colored_polygon(PackedVector2Array([c + n * 4.0, c + d * len, c - n * 4.0]), Color(col.r * 1.3, col.g * 1.3, col.b * 1.3, 0.28))
	Art.glow(_medal, c, 70.0, col, 0.55 + 0.1 * sin(_t * 3.0))
	_medal.draw_circle(c, 44.0, Color(0, 0, 0, 0.5))
	_medal.draw_circle(c, 41.0, Color(col.darkened(0.75), 0.95))
	_medal.draw_arc(c, 44.0, 0, TAU, 64, Art.hdr(UI.GOLD, 1.2), 2.5, true)
	_medal.draw_arc(c, 38.0, 0, TAU, 64, Color(col, 0.6), 1.2, true)
	for i in 24:
		var a := TAU * i / 24.0
		_medal.draw_line(c + Vector2.from_angle(a) * 39.5, c + Vector2.from_angle(a) * 43.0, Color(UI.GOLD, 0.6), 1.0)
	UI.draw_icon(_medal, emblem, c, 24.0, Art.hdr(col.lightened(0.35), 1.35))
	_medal.draw_arc(c, 34.0, PI * 1.1, PI * 1.45, 16, Color(1, 1, 1, 0.22), 2.0, true)


func _card(offer: Dictionary) -> Button:
	var color: Color = offer["color"]
	var tier := int(offer.get("tier", -1))
	var duo: bool = offer.get("duo", false)
	var god_id: String = offer["gods"][0] if duo else (offer["id"] if GameData.GODS.has(offer["id"]) else "olimpo")
	var emblem: String = GameData.GODS[god_id]["emblem"]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = true
	b.custom_minimum_size = Vector2(0, 84)
	for state in ["normal", "disabled", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var glass := Glass.make(color, 0.24 if duo else 0.16, 18.0)
	b.add_child(glass)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -12
	row.offset_top = 8
	row.offset_bottom = -8
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	b.add_child(row)

	var tile := Control.new()
	tile.custom_minimum_size = Vector2(56, 56)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.draw.connect(func():
		var r := Rect2(Vector2.ZERO, Vector2(56, 56))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(color.darkened(0.7), 0.92)
		sb.border_color = Art.hdr(color, 1.2) if tier < 2 else Art.hdr(GameData.RARITIES[tier]["color"], 1.4)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(12)
		sb.anti_aliasing = true
		tile.draw_style_box(sb, r)
		Art.glow(tile, r.get_center(), 30.0, color, 0.35)
		UI.draw_icon(tile, emblem, r.get_center(), 16.0, Art.hdr(color.lightened(0.35), 1.3)))
	row.add_child(tile)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 1)
	row.add_child(v)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := UI.label(offer["name"], 15, color.lightened(0.45))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	head.add_child(name_label)
	if duo:
		head.add_child(_pill("DUO", GameData.DUO_COLOR))
	elif tier >= 0:
		head.add_child(_pill(GameData.RARITIES[tier]["name"], GameData.RARITIES[tier]["color"]))
	v.add_child(head)
	v.add_child(UI.wrap_label(offer["desc"], 9, Color(1, 1, 1, 0.88)))
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var god_label := UI.label(offer["god"], 7, Color(color.lightened(0.2), 0.8))
	god_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(god_label)
	var lvl := int(picks.get(offer["id"], 0))
	if not duo and offer["id"] != "ambrosia":
		foot.add_child(UI.label("NOVO" if lvl == 0 else "NÍVEL %d" % (lvl + 1), 7, UI.GOLD if lvl == 0 else UI.MUTED))
	v.add_child(foot)

	b.pressed.connect(_pick.bind(offer, b))
	if tier >= 2 or duo:
		var shine := b.create_tween().set_loops().set_ignore_time_scale(true)
		var set_tint := func(x: float):
			glass.tint_amount = x
			glass.apply()
		shine.tween_method(set_tint, 0.16, 0.34, 0.7)
		shine.tween_method(set_tint, 0.34, 0.16, 0.7)
	return b


func _pill(text: String, color: Color) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.25)
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UI.label(text, 7, color.lightened(0.3)))
	return p


func _pick(offer: Dictionary, card: Button) -> void:
	if _closing:
		return
	_closing = true
	for b in _buttons:
		b.disabled = true
	_sfx("boon_pick")
	var picked_god: String = offer["gods"][0] if offer.get("duo", false) else (offer["id"] if GameData.GODS.has(offer["id"]) else "olimpo")
	Divine.stinger(picked_god, -8.0)
	if Save.haptics and OS.has_feature("mobile"):
		Input.vibrate_handheld(40)
	card.pivot_offset = card.size / 2
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(card, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_BACK)
	t.parallel().tween_property(card, "modulate", Color(1.6, 1.6, 1.6), 0.12)
	for b in _buttons:
		if b != card:
			t.parallel().tween_property(b, "modulate:a", 0.0, 0.25)
	t.tween_property(card, "modulate", Color.WHITE, 0.18)
	t.tween_property(_root, "modulate:a", 0.0, 0.25)
	t.tween_callback(func():
		chosen.emit(offer)
		queue_free())


func _sfx(sound: String, pitch := 1.0) -> void:
	if not Sfx._cache.has(sound):
		return
	var p := AudioStreamPlayer.new()
	p.stream = Sfx._cache[sound]
	p.pitch_scale = pitch
	p.volume_db = -2.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

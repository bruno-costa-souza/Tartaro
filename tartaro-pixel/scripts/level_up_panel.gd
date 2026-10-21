class_name LevelUpPanel
extends CanvasLayer

signal chosen(offer: Dictionary)

const INPUT_DELAY := 0.45

var title := "NÍVEL!"
var offers: Array = []
var picks: Dictionary = {}

var _buttons: Array[Button] = []


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	root.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	box.add_child(UI.label(title, 24, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("Escolha uma bênção", 10, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	for i in offers.size():
		var card := _card(offers[i])
		box.add_child(card)
		_buttons.append(card)
		card.modulate.a = 0.0
		var t := card.create_tween().set_ignore_time_scale(true)
		t.tween_interval(0.08 * i)
		t.tween_property(card, "modulate:a", 1.0, 0.18)

	var enable := create_tween().set_ignore_time_scale(true)
	enable.tween_interval(INPUT_DELAY)
	enable.tween_callback(func():
		for b in _buttons:
			b.disabled = false)


func _card(offer: Dictionary) -> Button:
	var color: Color = offer["color"]
	var tier := int(offer.get("tier", -1))
	var duo: bool = offer.get("duo", false)
	var border := color
	if tier >= 1:
		border = GameData.RARITIES[tier]["color"]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = true
	b.custom_minimum_size = Vector2(0, 92)
	var normal := UI.style(color.darkened(0.82), border, 3 if tier >= 2 or duo else 2)
	for state in ["normal", "disabled", "hover"]:
		b.add_theme_stylebox_override(state, normal)
	b.add_theme_stylebox_override("pressed", UI.style(color.darkened(0.5), Color.WHITE, 2))

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -12
	v.offset_top = 8
	v.offset_bottom = -8
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var god := UI.label(offer["god"], 8, color)
	god.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(god)
	if duo:
		head.add_child(UI.label("DUO", 8, GameData.DUO_COLOR))
	elif tier >= 0:
		head.add_child(UI.label(GameData.RARITIES[tier]["name"], 8, GameData.RARITIES[tier]["color"]))
	v.add_child(head)

	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := UI.label(offer["name"], 16)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_label)
	var lvl := int(picks.get(offer["id"], 0))
	if not duo and offer["id"] != "ambrosia":
		name_row.add_child(UI.label("NOVO!" if lvl == 0 else "NV %d" % (lvl + 1), 8, UI.GOLD if lvl == 0 else UI.MUTED))
	v.add_child(name_row)
	v.add_child(UI.wrap_label(offer["desc"], 8, Color("ddd6f0")))

	b.pressed.connect(_pick.bind(offer))
	if tier >= 2 or duo:
		var shine := b.create_tween().set_loops().set_ignore_time_scale(true)
		shine.tween_property(b, "self_modulate", Color(1.25, 1.25, 1.25), 0.5)
		shine.tween_property(b, "self_modulate", Color.WHITE, 0.5)
	return b


func _pick(offer: Dictionary) -> void:
	for b in _buttons:
		b.disabled = true
	chosen.emit(offer)
	queue_free()

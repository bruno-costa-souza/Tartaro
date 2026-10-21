class_name SettingsSheet


static func build(on_close: Callable, title := "AJUSTES", extra: Array = []) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.process_mode = Node.PROCESS_MODE_ALWAYS

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var card := UI.panel(UI.GLASS_TINT, 0.14, 26.0, 18.0)
	card.custom_minimum_size = Vector2(280, 0)
	center.add_child(card)
	var v := UI.body(card)
	v.add_theme_constant_override("separation", 10)
	v.add_child(UI.label(title, 24, Color("f0e2c0"), HORIZONTAL_ALIGNMENT_CENTER))
	if not extra.is_empty():
		var resume := UI.button("Continuar", UI.EMBER, 16)
		resume.custom_minimum_size.y = 48
		resume.pressed.connect(on_close)
		v.add_child(resume)
	v.add_child(_toggle("Vibração", Save.haptics, func(on: bool):
		Save.haptics = on
		Save.save_data()))
	v.add_child(_toggle("Som", Save.sound, func(on: bool):
		Save.sound = on
		Save.apply_settings()
		Save.save_data()))
	v.add_child(_toggle("Efeitos leves", Save.low_fx, func(on: bool):
		Save.low_fx = on
		Save.save_data()))
	if extra.is_empty():
		var close := UI.button("Fechar", UI.GLASS_TINT, 12)
		close.custom_minimum_size.y = 40
		close.pressed.connect(on_close)
		v.add_child(close)
	else:
		v.add_child(UI.spacer(6))
		for b in extra:
			b.custom_minimum_size.y = 36
			v.add_child(b)

	card.pivot_offset = Vector2(140, 100)
	card.scale = Vector2(0.92, 0.92)
	card.modulate.a = 0.0
	var t := card.create_tween().set_parallel(true).set_ignore_time_scale(true)
	t.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "modulate:a", 1.0, 0.15)
	return root


static func _toggle(name: String, value: bool, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	var l := UI.label(name, 12, Color.WHITE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var state := [value]
	var b := UI.button("", Color("34c759") if value else UI.GLASS_TINT, 10)
	b.custom_minimum_size = Vector2(96, 32)
	var refresh := func():
		b.text = "Ligado" if state[0] else "Desligado"
		var g: Glass = b.get_child(0)
		g.tint = Color("34c759") if state[0] else UI.GLASS_TINT
		g.tint_amount = 0.45 if state[0] else 0.2
		g.apply()
	b.pressed.connect(func():
		state[0] = not state[0]
		refresh.call()
		on_change.call(state[0]))
	b.ready.connect(refresh)
	row.add_child(b)
	return row

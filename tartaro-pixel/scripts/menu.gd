extends Control

var _list: VBoxContainer
var _sfx: Sfx


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sfx = Sfx.new()
	add_child(_sfx)

	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", int(UI.safe_top(get_viewport_rect().size.x)) + 14)
	margin.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(margin)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	margin.add_child(_list)
	_build()


func _build() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()

	_list.add_child(UI.label("TÁRTARO", 32, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	_list.add_child(UI.label("Fuga do Submundo", 10, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_list.add_child(_spacer(6))

	var seed_value := Save.daily_seed()
	var daily := UI.panel()
	var dv := VBoxContainer.new()
	daily.add_child(dv)
	dv.add_child(UI.label("DESAFIO DIÁRIO", 10, Color("b06cff")))
	var best := Save.best_score(seed_value)
	dv.add_child(UI.label("Seed %d   -   Seu recorde: %s" % [seed_value, str(best) if best > 0 else "--"], 8, UI.MUTED))
	_list.add_child(daily)

	var play := UI.button("JOGAR", Color("c0392b"), 24)
	play.custom_minimum_size.y = 54
	play.pressed.connect(_start.bind(0))
	_list.add_child(play)

	var train := UI.button("Treino (seed aleatória)", Color("5a5470"), 10)
	train.custom_minimum_size.y = 30
	train.pressed.connect(func(): _start(randi_range(1, 999999)))
	_list.add_child(train)

	_list.add_child(_spacer(4))
	_list.add_child(UI.label("ÓBOLOS: %d" % Save.coins, 16, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	_list.add_child(_section("ARSENAL", "Armas compradas ficam para sempre. Escolha uma para levar."))
	for id in GameData.WEAPON_ORDER:
		_list.add_child(_weapon_row(id))

	_list.add_child(_section("BÊNÇÃOS ETERNAS", "Melhorias permanentes para todas as runs."))
	for id in GameData.PERMA_ORDER:
		_list.add_child(_perma_row(id))


func _weapon_row(id: String) -> Control:
	var w: Dictionary = GameData.WEAPONS[id]
	var color: Color = w["color"]
	var owned: bool = id in Save.owned_weapons
	var equipped := Save.equipped == id

	var p := UI.panel()
	if equipped:
		p.add_theme_stylebox_override("panel", UI.style(UI.PANEL, color, 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.label(w["name"], 12, color))
	info.add_child(UI.wrap_label(w["desc"]))
	info.add_child(UI.label("Dano %d  -  Alcance %d  -  %.1f ataques/s" % [w["damage"], w["range"], 1.0 / float(w["interval"])], 8, Color("6f6888")))
	row.add_child(info)

	var btn: Button
	if equipped:
		btn = UI.button("EQUIPADA", Color("27ae60"), 10)
	elif owned:
		btn = UI.button("EQUIPAR", Color("2980b9"), 10)
		btn.pressed.connect(func():
			Save.equip(id)
			_sfx.play("coin")
			_build())
	else:
		btn = UI.button("COMPRAR\n%d óbolos" % w["cost"], UI.GOLD, 10)
		btn.disabled = Save.coins < int(w["cost"])
		btn.pressed.connect(func():
			if Save.buy_weapon(id):
				_sfx.play("buy")
				_build())
	btn.custom_minimum_size = Vector2(92, 44)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(btn)
	return p


func _perma_row(id: String) -> Control:
	var u: Dictionary = GameData.PERMA[id]
	var lvl := Save.perma_level(id)
	var max_lvl := int(u["max"])

	var p := UI.panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.label(u["name"], 12))
	info.add_child(UI.wrap_label(u["desc"]))
	info.add_child(UI.label("Nível %d / %d" % [lvl, max_lvl], 8, UI.GOLD))
	row.add_child(info)

	var btn: Button
	if lvl >= max_lvl:
		btn = UI.button("MÁXIMO", Color("5a5470"), 10)
		btn.disabled = true
	else:
		btn = UI.button("MELHORAR\n%d óbolos" % Save.perma_cost(id), UI.GOLD, 10)
		btn.disabled = Save.coins < Save.perma_cost(id)
		btn.pressed.connect(func():
			if Save.buy_perma(id):
				_sfx.play("buy")
				_build())
	btn.custom_minimum_size = Vector2(92, 44)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(btn)
	return p


func _section(title: String, sub: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(_spacer(6))
	v.add_child(UI.label(title, 14, Color("e8d9b0")))
	v.add_child(UI.wrap_label(sub))
	return v


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _start(seed_value: int) -> void:
	Save.next_seed = seed_value
	get_tree().change_scene_to_file("res://scenes/game.tscn")

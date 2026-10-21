extends Control

const TABS := [
	{"id": "play", "name": "Jogar", "icon": "flame"},
	{"id": "arsenal", "name": "Arsenal", "icon": "sword"},
	{"id": "perma", "name": "Bênçãos", "icon": "laurel"},
]

const TIPS := [
	"Durante o dash você é invencível: atravesse projéteis e investidas.",
	"Tendo bênçãos de dois deuses, pode surgir uma bênção Duo, bem mais forte.",
	"Inimigos com anel dourado são elites: mais vida, mais óbolos.",
	"Mate o Bombardeiro antes que ele chegue: a explosão fere só os inimigos.",
	"Os anéis do Talos sempre têm uma brecha. Procure-a!",
	"Fique atrás de colunas: elas bloqueiam projéteis inimigos.",
	"Escolha a porta pela recompensa: bênção, óbolos, cura, vida ou Bigorna.",
	"Atraia inimigos para as poças: elas ferem eles também.",
	"O olhar da Medusa deixa você lento. Saia da linha vermelha!",
]

var _page := "play"
var _list: VBoxContainer
var _scroll: ScrollContainer
var _coins: Label
var _countdown: Label
var _tab_buttons: Array[Button] = []
var _tab_pill: Glass
var _settings: Control
var _sfx: Sfx
var _vp := Vector2(360, 640)


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_vp = get_viewport_rect().size
	_sfx = Sfx.new()
	add_child(_sfx)
	_build_backdrop()
	_build_stage()
	_build_top_bar()
	_build_content_area()
	_build_tab_bar()
	_show_page("play")
	Music.play("menu")


func _process(_delta: float) -> void:
	if _countdown and is_instance_valid(_countdown):
		var now := Time.get_time_dict_from_system()
		var left := 86400 - (int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now["second"]))
		_countdown.text = "Nova escalada em %02d:%02d:%02d" % [left / 3600, (left / 60) % 60, left % 60]


func _build_backdrop() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/menu_bg.gdshader")
	bg.material = mat
	add_child(bg)

	var embers := CPUParticles2D.new()
	embers.material = Art.additive()
	embers.position = Vector2(_vp.x / 2, _vp.y + 10)
	embers.amount = 40
	embers.lifetime = 8.0
	embers.preprocess = 8.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(_vp.x / 2, 10)
	embers.direction = Vector2.UP
	embers.spread = 15.0
	embers.gravity = Vector2(0, -6)
	embers.initial_velocity_min = 20.0
	embers.initial_velocity_max = 60.0
	embers.scale_amount_min = 0.8
	embers.scale_amount_max = 2.0
	embers.color = Art.hdr(Color("ff8a3d"), 2.0)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	embers.color_ramp = ramp
	add_child(embers)


func _stage_h() -> float:
	return clampf(_vp.y * 0.37, 220.0, 300.0)


func _build_stage() -> void:
	var top := UI.safe_top(_vp.x)
	var title := UI.label("TÁRTARO", 38, Art.hdr(UI.GOLD, 1.25), HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 0)
	title.position = Vector2(0, top + 30)
	title.size = Vector2(_vp.x, 44)
	add_child(title)
	var sub := UI.label("FUGA DO SUBMUNDO", 9, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(0, top + 74)
	sub.size = Vector2(_vp.x, 14)
	add_child(sub)

	var stage := HeroStage.new()
	stage.position = Vector2(_vp.x / 2, _stage_h() + top - 6)
	add_child(stage)


func _build_top_bar() -> void:
	var top := UI.safe_top(_vp.x)
	var gear := UI.button("", UI.GLASS_TINT, 10)
	gear.position = Vector2(14, top)
	gear.size = Vector2(36, 36)
	gear.add_child(_centered_icon("gear", 16, Color(1, 1, 1, 0.9)))
	gear.pressed.connect(_open_settings)
	add_child(gear)

	var pill := UI.panel(UI.GOLD, 0.12, 999.0, 0.0)
	pill.position = Vector2(_vp.x - 110, top)
	pill.custom_minimum_size = Vector2(96, 36)
	pill.size = Vector2(96, 36)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.add_child(UI.icon("coin", 16, UI.GOLD))
	_coins = UI.label(str(Save.coins), 14, UI.GOLD)
	row.add_child(_coins)
	UI.body(pill).alignment = BoxContainer.ALIGNMENT_CENTER
	UI.body(pill).add_child(row)
	add_child(pill)


func _centered_icon(kind: String, px: float, color: Color) -> Control:
	var ic := UI.icon(kind, px, color)
	ic.set_anchors_preset(Control.PRESET_CENTER)
	ic.position = -Vector2(px, px) / 2
	return ic


func _build_content_area() -> void:
	var top := UI.safe_top(_vp.x) + _stage_h() + 8
	var bottom := UI.safe_bottom(_vp.x) + 74
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, top)
	_scroll.size = Vector2(_vp.x, _vp.y - top - bottom)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	_scroll.add_child(margin)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	margin.add_child(_list)


func _build_tab_bar() -> void:
	var h := 58.0
	var bar := UI.panel(UI.GLASS_TINT, 0.08, 999.0, 0.0)
	bar.position = Vector2(16, _vp.y - UI.safe_bottom(_vp.x) - h - 6)
	bar.size = Vector2(_vp.x - 32, h)
	add_child(bar)
	_tab_pill = Glass.make(UI.GOLD, 0.22, 999.0)
	_tab_pill.fill_parent = false
	_tab_pill.show_behind_parent = false
	var w := (_vp.x - 32 - 12) / TABS.size()
	add_child(_tab_pill)
	_tab_pill.position = bar.position + Vector2(6, 6)
	_tab_pill.size = Vector2(w, h - 12)
	for i in TABS.size():
		var tab: Dictionary = TABS[i]
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.position = bar.position + Vector2(6 + i * w, 6)
		b.size = Vector2(w, h - 12)
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 1)
		var ic := UI.icon(tab["icon"], 18, Color.WHITE)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		v.add_child(UI.label(tab["name"], 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		b.add_child(v)
		b.pressed.connect(_show_page.bind(tab["id"]))
		add_child(b)
		_tab_buttons.append(b)


func _show_page(id: String) -> void:
	if id != _page:
		_sfx.play("xp", 1.3)
	_page = id
	for i in TABS.size():
		var selected: bool = TABS[i]["id"] == id
		_tab_buttons[i].modulate = Color.WHITE if selected else Color(1, 1, 1, 0.55)
		if selected:
			_tab_pill.create_tween().tween_property(_tab_pill, "position:x", _tab_buttons[i].position.x, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_rebuild()


func _rebuild() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_countdown = null
	_coins.text = str(Save.coins)
	match _page:
		"play":
			_page_play()
		"arsenal":
			_page_arsenal()
		"perma":
			_page_perma()
	_scroll.scroll_vertical = 0


func _page_play() -> void:
	var seed_value := Save.daily_seed()
	var daily := UI.panel(Color("b06cff"), 0.14)
	var v := UI.body(daily)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.add_child(UI.icon("flame", 14, Color("ff9a4a")))
	var t := UI.label("DESAFIO DIÁRIO", 11, Color("e2c4ff"))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var best := Save.best_score(seed_value)
	head.add_child(UI.label("Recorde  %s" % (str(best) if best > 0 else "--"), 10, UI.GOLD))
	v.add_child(head)
	v.add_child(UI.wrap_label("Hoje todos enfrentam a mesma escalada. Supere seus amigos.", 9))
	_countdown = UI.label("", 8, Color(1, 1, 1, 0.55))
	v.add_child(_countdown)
	_list.add_child(daily)

	var play := UI.button("JOGAR", UI.EMBER, 26)
	play.custom_minimum_size.y = 60
	play.pressed.connect(_start.bind(0))
	_list.add_child(play)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var train := UI.button("Treino", UI.GLASS_TINT, 11)
	train.custom_minimum_size.y = 38
	train.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	train.pressed.connect(func(): _start(randi_range(1, 999999)))
	row.add_child(train)
	var w: Dictionary = GameData.WEAPONS[Save.equipped]
	var arm := UI.button(w["name"], w["color"], 10)
	arm.custom_minimum_size.y = 38
	arm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arm.pressed.connect(_show_page.bind("arsenal"))
	row.add_child(arm)
	_list.add_child(row)

	var stats := UI.panel()
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 0)
	for s in [["RUNS", Save.stats["runs"]], ["SALA MÁX", Save.stats["best_room"]], ["CHEFES", Save.stats["bosses"]], ["ABATES", Save.stats["kills"]]]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		cell.add_child(UI.label(str(int(s[1])), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		cell.add_child(UI.label(s[0], 7, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		grid.add_child(cell)
	UI.body(stats).add_child(grid)
	_list.add_child(stats)

	var tip := UI.panel(Color("4aa3ff"), 0.08)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	trow.add_child(UI.icon("laurel", 18, Color("9ccfff")))
	trow.add_child(UI.wrap_label(TIPS[randi() % TIPS.size()], 9, Color(1, 1, 1, 0.85)))
	UI.body(tip).add_child(trow)
	_list.add_child(tip)


func _page_arsenal() -> void:
	_list.add_child(_section("ARSENAL", "Armas compradas são suas para sempre."))
	for id in GameData.WEAPON_ORDER:
		_list.add_child(_weapon_card(id))


func _page_perma() -> void:
	_list.add_child(_section("BÊNÇÃOS ETERNAS", "Melhorias permanentes para todas as runs."))
	for id in GameData.PERMA_ORDER:
		_list.add_child(_perma_card(id))


func _section(title: String, sub: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(UI.label(title, 20, Color("f0e2c0")))
	v.add_child(UI.wrap_label(sub, 9))
	return v


func _emblem(kind: String, color: Color) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(48, 48)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Glass.make(color, 0.3, 999.0)
	holder.add_child(g)
	var ic := UI.icon(kind, 26, color.lightened(0.35))
	ic.position = Vector2(11, 11)
	holder.add_child(ic)
	return holder


func _stat_bar(name: String, ratio: float, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var l := UI.label(name, 7, UI.MUTED)
	l.custom_minimum_size.x = 46
	row.add_child(l)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.draw.connect(func():
		var r := Rect2(Vector2(0, 2), Vector2(bar.size.x, 4))
		bar.draw_rect(r, Color(1, 1, 1, 0.12))
		bar.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0.05, 1.0), 4)), color))
	row.add_child(bar)
	return row


func _weapon_card(id: String) -> Control:
	var w: Dictionary = GameData.WEAPONS[id]
	var color: Color = w["color"]
	var owned: bool = id in Save.owned_weapons
	var equipped := Save.equipped == id
	var card := UI.panel(color, 0.16 if equipped else 0.07)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_emblem(UI.weapon_icon(id), color))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	info.add_child(UI.label(w["name"], 12, color.lightened(0.25)))
	info.add_child(UI.wrap_label(w["desc"], 8))
	var dps := float(w["damage"]) / float(w["interval"])
	info.add_child(_stat_bar("DANO", dps / 7.0, color))
	info.add_child(_stat_bar("ALCANCE", float(w["range"]) / 240.0, color))
	row.add_child(info)
	UI.body(card).add_child(row)

	var btn: Button
	if equipped:
		btn = UI.button("Equipada", Color("27ae60"), 10)
		btn.disabled = true
	elif owned:
		btn = UI.button("Equipar", Color("4aa3ff"), 10)
		btn.pressed.connect(func():
			Save.equip(id)
			_sfx.play("coin")
			_rebuild())
	else:
		btn = UI.button("Comprar  -  %d" % int(w["cost"]), UI.GOLD, 10)
		btn.disabled = Save.coins < int(w["cost"])
		btn.pressed.connect(func():
			if Save.buy_weapon(id):
				_sfx.play("buy")
				_rebuild())
	btn.custom_minimum_size.y = 34
	UI.body(card).add_child(btn)
	return card


func _perma_card(id: String) -> Control:
	var u: Dictionary = GameData.PERMA[id]
	var lvl := Save.perma_level(id)
	var max_lvl := int(u["max"])
	var color: Color = {"vida": Color("ff5e6c"), "forca": Color("ff9a4a"), "fortuna": UI.GOLD}[id]
	var icon_kind: String = {"vida": "heart", "forca": "fist", "fortuna": "coin"}[id]
	var card := UI.panel(color, 0.08)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_emblem(icon_kind, color))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	var head := HBoxContainer.new()
	var n := UI.label(u["name"], 12, color.lightened(0.3))
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	head.add_child(UI.label("%d/%d" % [lvl, max_lvl], 10, UI.MUTED))
	info.add_child(head)
	info.add_child(UI.wrap_label(u["desc"], 8))
	var pips := Control.new()
	pips.custom_minimum_size = Vector2(0, 8)
	pips.draw.connect(func():
		var gap := 3.0
		var w := (pips.size.x - gap * (max_lvl - 1)) / max_lvl
		for i in max_lvl:
			var r := Rect2(i * (w + gap), 1, w, 5)
			pips.draw_rect(r, color if i < lvl else Color(1, 1, 1, 0.12)))
	info.add_child(pips)
	row.add_child(info)
	UI.body(card).add_child(row)

	var btn: Button
	if lvl >= max_lvl:
		btn = UI.button("Máximo", UI.GLASS_TINT, 10)
		btn.disabled = true
	else:
		btn = UI.button("Melhorar  -  %d" % Save.perma_cost(id), UI.GOLD, 10)
		btn.disabled = Save.coins < Save.perma_cost(id)
		btn.pressed.connect(func():
			if Save.buy_perma(id):
				_sfx.play("buy")
				_rebuild())
	btn.custom_minimum_size.y = 34
	UI.body(card).add_child(btn)
	return card


func _open_settings() -> void:
	if _settings:
		return
	_sfx.play("xp", 1.1)
	_settings = SettingsSheet.build(func():
		_settings.queue_free()
		_settings = null)
	add_child(_settings)


func _start(seed_value: int) -> void:
	Save.next_seed = seed_value
	_sfx.play("levelup", 0.8)
	get_tree().change_scene_to_file("res://scenes/game.tscn")


class HeroStage extends Node2D:
	var _t := 0.0
	var _hero: HeroSprite

	func _ready() -> void:
		for x in [-112.0, 112.0]:
			var b := Room.Brazier.new()
			b.flame = Color("ff8a3d")
			b.position = Vector2(x, -6)
			b.scale = Vector2(2.2, 2.2)
			b.light_power = 0.35
			add_child(b)
		if HeroSprite.available():
			_hero = HeroSprite.new()
			_hero.position = Vector2(0, -2)
			_hero.z_index = 1
			add_child(_hero)
			_hero.fit_height(128.0)

	func _process(delta: float) -> void:
		_t += delta
		if _hero:
			var d := int(_t / 1.3) % 8
			var deg := 90.0 - d * 45.0
			_hero.show_state("idle", Vector2.from_angle(deg_to_rad(deg)))
		queue_redraw()

	func _draw() -> void:
		Art.glow(self, Vector2(0, -40), 120.0, Color(1.0, 0.45, 0.2), 0.3)
		draw_colored_polygon(Art._ellipse(Vector2(0, 2), Vector2(138, 34), 48), Color("0e0a12"))
		draw_colored_polygon(Art._ellipse(Vector2.ZERO, Vector2(134, 31), 48), Color("2c2436"))
		draw_colored_polygon(Art._ellipse(Vector2(0, -2), Vector2(118, 25), 48), Color("3a3046"))
		draw_set_transform(Vector2(0, -2), 0, Vector2(1.0, 0.21))
		draw_arc(Vector2.ZERO, 110, 0, TAU, 72, Color("9a6a3a"), 4.0, true)
		draw_arc(Vector2.ZERO, 98, 0, TAU, 72, Color("9a6a3a"), 1.5, true)
		for i in 36:
			var a := TAU * i / 36.0
			draw_line(Vector2.from_angle(a) * 100.0, Vector2.from_angle(a) * 108.0, Color("9a6a3a"), 2.5)
		draw_set_transform(Vector2.ZERO)
		Art.soft_shadow(self, Vector2(4, 0), 44, 10)
		if _hero:
			return
		draw_set_transform(Vector2(0, -2), 0, Vector2(4.3, 4.3))
		Player.draw_figure(self, Vector2(0.18, 1.0).normalized(), Color.WHITE, 1.0, sin(_t * 1.4) * 0.35)
		draw_set_transform(Vector2.ZERO)

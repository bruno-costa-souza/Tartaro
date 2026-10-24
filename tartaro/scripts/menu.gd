extends Control

## Main menu: home (hero, journey and play), arsenal (weapon showcase and
## grid) and eternal blessings (permanent upgrades), with a bottom tab bar
## whose selected tab grows, mobile-game style.

const TABS := [
	{"id": "arsenal", "name": "Arsenal", "icon": "sword"},
	{"id": "play", "name": "Jogar", "icon": "flame"},
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
	"Toque no laurel durante a run para ver todos os seus poderes.",
]

const WEAPON_EMBLEM := {"lanca": "lanca", "arco": "artemis", "espada": "ares", "cetro": "cetro"}
const PERMA_EMBLEM := {"vida": "vida", "forca": "forca", "fortuna": "tique"}
const PERMA_COLOR := {"vida": Color("ff5a6e"), "forca": Color("ff8c3a"), "fortuna": Color("ffd84a")}
const REGIONS := [
	{"name": "Tártaro", "boss": "Cérbero", "color": Color("b06cff"), "god": "hecate"},
	{"name": "Asfódelo", "boss": "Medusa", "color": Color("8be05a"), "god": "demeter"},
	{"name": "Elísio", "boss": "Talos", "color": Color("ffcf6a"), "god": "apolo"},
]
const NAV_H := 66.0

var _page := "play"
var _vp := Vector2(360, 640)
var _top := 8.0
var _bottom := 8.0
var _scroll: ScrollContainer
var _list: VBoxContainer
var _coins: Label
var _countdown: Label
var _tab_buttons: Array[Button] = []
var _tab_glow: Glass
var _settings: Control
var _sfx: Sfx
var _stage: HeroStage
var _brand: Control
var _weapon_pick := ""


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_vp = get_viewport_rect().size
	_top = UI.safe_top(_vp.x)
	_bottom = UI.safe_bottom(_vp.x)
	_weapon_pick = Save.equipped
	_sfx = Sfx.new()
	add_child(_sfx)
	_build_backdrop()
	_build_stage()
	_build_content_area()
	_build_top_bar()
	_build_tab_bar()
	_show_page("play", false)
	Music.play("menu")


func _process(_delta: float) -> void:
	if _countdown and is_instance_valid(_countdown):
		var now := Time.get_time_dict_from_system()
		var left := 86400 - (int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now["second"]))
		_countdown.text = "Nova escalada em %02d:%02d:%02d" % [left / 3600, (left / 60) % 60, left % 60]


# ---------------------------------------------------------------- frame

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
	return clampf(_vp.y * 0.36, 210.0, 300.0)


func _build_stage() -> void:
	_brand = Control.new()
	_brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brand.position = Vector2(0, _top + 28)
	_brand.size = Vector2(_vp.x, 60)
	var title := UI.label("TÁRTARO", 38, Art.hdr(UI.GOLD, 1.25), HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 0)
	title.size = Vector2(_vp.x, 44)
	_brand.add_child(title)
	var sub := UI.label("FUGA DO SUBMUNDO", 9, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(0, 44)
	sub.size = Vector2(_vp.x, 14)
	_brand.add_child(sub)
	add_child(_brand)

	_stage = HeroStage.new()
	_stage.position = Vector2(_vp.x / 2, _stage_h() + _top - 6)
	add_child(_stage)


func _build_top_bar() -> void:
	var gear := UI.button("", UI.GLASS_TINT, 10)
	gear.position = Vector2(14, _top)
	gear.size = Vector2(36, 36)
	gear.add_child(_centered_icon("gear", 16, Color(1, 1, 1, 0.9)))
	gear.pressed.connect(_open_settings)
	add_child(gear)

	var pill := UI.panel(UI.GOLD, 0.12, 999.0, 0.0)
	pill.position = Vector2(_vp.x - 110, _top)
	pill.custom_minimum_size = Vector2(96, 36)
	pill.size = Vector2(96, 36)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.add_child(UI.icon("coin", 16, UI.GOLD))
	_coins = UI.label("", 14, UI.GOLD)
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
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	_scroll.add_child(margin)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	margin.add_child(_list)


func _layout_content() -> void:
	var top := _top + (_stage_h() + 2.0 if _page == "play" else 48.0)
	var bottom := _bottom + NAV_H + 12.0
	_scroll.position = Vector2(0, top)
	_scroll.size = Vector2(_vp.x, _vp.y - top - bottom)


func _build_tab_bar() -> void:
	var bar := UI.panel(Color(0.1, 0.07, 0.16), 0.55, 26.0, 0.0)
	bar.position = Vector2(10, _vp.y - _bottom - NAV_H - 4)
	bar.size = Vector2(_vp.x - 20, NAV_H)
	add_child(bar)
	_tab_glow = Glass.make(UI.GOLD, 0.3, 20.0)
	_tab_glow.fill_parent = false
	_tab_glow.show_behind_parent = false
	add_child(_tab_glow)
	for i in TABS.size():
		var tab: Dictionary = TABS[i]
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 2)
		var ic := UI.icon(tab["icon"], 22, Color.WHITE)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var name_label := UI.label(String(tab["name"]).to_upper(), 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		name_label.add_theme_font_override("font", _spaced(UI.title_font(), 1))
		v.add_child(name_label)
		b.add_child(v)
		b.set_meta("label", name_label)
		b.set_meta("icon", ic)
		b.pressed.connect(_show_page.bind(tab["id"]))
		add_child(b)
		_tab_buttons.append(b)


func _tab_rects(selected: int) -> Array:
	var x := 16.0
	var w := _vp.x - 32.0
	var big := w * 0.42
	var small := (w - big) / (TABS.size() - 1)
	var y := _vp.y - _bottom - NAV_H + 2.0
	var out: Array = []
	for i in TABS.size():
		var tw := big if i == selected else small
		out.append(Rect2(Vector2(x, y), Vector2(tw, NAV_H - 12.0)))
		x += tw
	return out


func _show_page(id: String, animate := true) -> void:
	if id != _page and animate:
		Music.ui("select")
	_page = id
	var sel := 0
	for i in TABS.size():
		if TABS[i]["id"] == id:
			sel = i
	var rects := _tab_rects(sel)
	for i in TABS.size():
		var b := _tab_buttons[i]
		var r: Rect2 = rects[i]
		var label: Label = b.get_meta("label")
		var on := i == sel
		if animate:
			var t := b.create_tween().set_parallel(true)
			t.tween_property(b, "position", r.position, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(b, "size", r.size, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(b, "modulate", Color.WHITE if on else Color(1, 1, 1, 0.55), 0.18)
		else:
			b.position = r.position
			b.size = r.size
			b.modulate = Color.WHITE if on else Color(1, 1, 1, 0.55)
		label.visible = on
		(b.get_meta("icon") as Control).scale = Vector2.ONE * (1.15 if on else 1.0)
	var target: Rect2 = rects[sel]
	if animate:
		var gt := _tab_glow.create_tween().set_parallel(true)
		gt.tween_property(_tab_glow, "position", target.position, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		gt.tween_property(_tab_glow, "size", target.size, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_tab_glow.position = target.position
		_tab_glow.size = target.size
	var home := id == "play"
	for n: CanvasItem in [_stage, _brand]:
		if animate:
			n.create_tween().tween_property(n, "modulate:a", 1.0 if home else 0.0, 0.2)
		else:
			n.modulate.a = 1.0 if home else 0.0
	_layout_content()
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


func _spaced(base: Font, spacing: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = base
	f.spacing_glyph = spacing
	return f


func _header(title: String, sub: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	var t := UI.label(title, 24, Color("f0e2c0"))
	t.add_theme_font_override("font", _spaced(UI.title_font(), 2))
	v.add_child(t)
	v.add_child(UI.wrap_label(sub, 10, Color(1, 1, 1, 0.62)))
	return v


# ---------------------------------------------------------------- home

func _page_play() -> void:
	_list.add_child(_journey())

	var seed_value := Save.daily_seed()
	var daily := UI.panel(Color("b06cff"), 0.14, 18.0, 12.0)
	var v := UI.body(daily)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.add_child(UI.icon("flame", 14, Color("ff9a4a")))
	var t := UI.label("DESAFIO DIÁRIO", 11, Color("e2c4ff"))
	t.add_theme_font_override("font", _spaced(UI.title_font(), 1))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var best := Save.best_score(seed_value)
	head.add_child(UI.label("Recorde  %s" % (str(best) if best > 0 else "--"), 11, UI.GOLD))
	v.add_child(head)
	v.add_child(UI.wrap_label("Hoje todos enfrentam a mesma escalada. Supere seus amigos.", 10, Color(1, 1, 1, 0.78)))
	_countdown = UI.label("", 9, Color(1, 1, 1, 0.55))
	v.add_child(_countdown)
	_list.add_child(daily)

	var play := UI.button("JOGAR", UI.EMBER, 28)
	play.custom_minimum_size.y = 62
	play.pressed.connect(_start.bind(0))
	_list.add_child(play)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var train := UI.button("Treino", UI.GLASS_TINT, 12)
	train.custom_minimum_size.y = 42
	train.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	train.pressed.connect(func(): _start(randi_range(1, 999999)))
	row.add_child(train)
	var w: Dictionary = GameData.WEAPONS[Save.equipped]
	var arm := UI.button("   " + String(w["name"]), w["color"], 11)
	arm.custom_minimum_size.y = 42
	arm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mini := Medallion.new()
	mini.emblem = WEAPON_EMBLEM.get(Save.equipped, "lanca")
	mini.color = w["color"]
	mini.custom_minimum_size = Vector2(30, 30)
	mini.position = Vector2(8, 6)
	mini.size = Vector2(30, 30)
	arm.add_child(mini)
	arm.pressed.connect(_show_page.bind("arsenal"))
	row.add_child(arm)
	_list.add_child(row)

	var stats := UI.panel(UI.GLASS_TINT, 0.08, 18.0, 10.0)
	var grid := HBoxContainer.new()
	for s in [["RUNS", Save.stats["runs"]], ["SALA MÁX", Save.stats["best_room"]], ["CHEFES", Save.stats["bosses"]], ["ABATES", Save.stats["kills"]]]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		cell.add_child(UI.label(str(int(s[1])), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		cell.add_child(UI.label(s[0], 8, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		grid.add_child(cell)
	UI.body(stats).add_child(grid)
	_list.add_child(stats)

	var tip := UI.panel(Color("4aa3ff"), 0.08, 18.0, 10.0)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	trow.add_child(UI.icon("laurel", 18, Color("9ccfff")))
	trow.add_child(UI.wrap_label(TIPS[randi() % TIPS.size()], 10, Color(1, 1, 1, 0.85)))
	UI.body(tip).add_child(trow)
	_list.add_child(tip)


func _journey() -> Control:
	var card := UI.panel(Color(0.5, 0.42, 0.7), 0.1, 18.0, 10.0)
	var best := int(Save.stats["best_room"])
	var road := Control.new()
	road.custom_minimum_size = Vector2(0, 74)
	road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	road.draw.connect(func():
		var w := road.size.x
		var y := 26.0
		var xs := [w * 0.16, w * 0.5, w * 0.84]
		for i in 2:
			var reached := best > (i + 1) * GameData.ROOMS_PER_BIOME
			var a := Vector2(xs[i] + 24, y)
			var b := Vector2(xs[i + 1] - 24, y)
			var k := 0
			var steps := 9
			while k < steps:
				var p0 := a.lerp(b, float(k) / steps)
				var p1 := a.lerp(b, float(k + 0.55) / steps)
				road.draw_line(p0, p1, Color(UI.GOLD, 0.8) if reached else Color(1, 1, 1, 0.18), 2.0, true)
				k += 1
		for i in 3:
			var reg: Dictionary = REGIONS[i]
			var c := Vector2(xs[i], y)
			var unlocked := best > i * GameData.ROOMS_PER_BIOME or i == 0
			var col: Color = reg["color"]
			if unlocked:
				Art.glow(road, c, 34.0, col, 0.35)
			road.draw_circle(c, 21.0, Color(0.03, 0.02, 0.05, 0.95))
			road.draw_arc(c, 21.0, 0, TAU, 40, Art.hdr(UI.GOLD, 1.2) if unlocked else Color(1, 1, 1, 0.25), 2.0, true)
			if not BoonArt.draw_emblem(road, reg["god"], c, 30.0, Color.WHITE if unlocked else Color(0.35, 0.35, 0.4)):
				road.draw_circle(c, 8.0, col)
			var name_col := col.lightened(0.3) if unlocked else Color(1, 1, 1, 0.35)
			var f := UI.title_font()
			road.draw_string(f, Vector2(c.x - 50, y + 36), String(reg["name"]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 100, 10, name_col)
			var boss_done := best > (i + 1) * GameData.ROOMS_PER_BIOME - 1
			road.draw_string(ThemeDB.fallback_font, Vector2(c.x - 50, y + 48), ("✓ " if boss_done else "") + String(reg["boss"]), HORIZONTAL_ALIGNMENT_CENTER, 100, 8,
				Color(UI.GOLD, 0.85) if boss_done else Color(1, 1, 1, 0.4)))
	UI.body(card).add_child(road)
	var foot := UI.label("Sua melhor escalada: sala %d" % best if best > 0 else "Sua primeira escalada te espera.", 9, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	UI.body(card).add_child(foot)
	return card


# ---------------------------------------------------------------- arsenal

func _page_arsenal() -> void:
	_list.add_child(_header("ARSENAL", "Armas compradas são suas para sempre."))
	_list.add_child(_weapon_showcase(_weapon_pick))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for id in GameData.WEAPON_ORDER:
		grid.add_child(_weapon_tile(id))
	_list.add_child(grid)


func _weapon_showcase(id: String) -> Control:
	var w: Dictionary = GameData.WEAPONS[id]
	var color: Color = w["color"]
	var owned: bool = id in Save.owned_weapons
	var equipped := Save.equipped == id
	var card := UI.panel(color, 0.14, 22.0, 14.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var med := Medallion.new()
	med.emblem = WEAPON_EMBLEM.get(id, "lanca")
	med.color = color
	med.rays = true
	med.custom_minimum_size = Vector2(108, 108)
	med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(med)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	var name_label := UI.label(w["name"], 17, color.lightened(0.3))
	name_label.add_theme_font_override("font", UI.title_font())
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(name_label)
	info.add_child(UI.wrap_label(w["desc"], 10, Color(1, 1, 1, 0.82)))
	var dps := float(w["damage"]) / float(w["interval"])
	info.add_child(_stat_bar("DANO", dps / 7.0, color))
	info.add_child(_stat_bar("ALCANCE", float(w["range"]) / 240.0, color))
	info.add_child(_stat_bar("CADÊNCIA", (1.0 / float(w["interval"])) / 3.2, color))
	row.add_child(info)
	UI.body(card).add_child(row)

	var btn: Button
	if equipped:
		btn = UI.button("✓  Equipada", Color("27ae60"), 13)
		btn.disabled = true
	elif owned:
		btn = UI.button("Equipar", Color("4aa3ff"), 14)
		btn.pressed.connect(func():
			Save.equip(id)
			_sfx.play("select")
			_rebuild())
	else:
		var cost := int(w["cost"])
		btn = UI.button("Comprar   ◎ %d" % cost, UI.GOLD, 14)
		btn.disabled = not Save.can_afford(cost)
		btn.pressed.connect(func():
			if Save.buy_weapon(id):
				_sfx.play("buy")
				_rebuild())
	btn.custom_minimum_size.y = 44
	UI.body(card).add_child(btn)
	return card


func _weapon_tile(id: String) -> Control:
	var w: Dictionary = GameData.WEAPONS[id]
	var color: Color = w["color"]
	var owned: bool = id in Save.owned_weapons
	var equipped := Save.equipped == id
	var selected := id == _weapon_pick
	var b := UI.button("", color if selected else UI.GLASS_TINT, 10, 18.0)
	b.custom_minimum_size = Vector2(0, 96)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var g: Glass = b.get_child(0)
	g.tint_amount = 0.32 if selected else 0.12
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	var med := Medallion.new()
	med.emblem = WEAPON_EMBLEM.get(id, "lanca")
	med.color = color
	med.dim = not owned
	med.custom_minimum_size = Vector2(52, 52)
	med.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(med)
	v.add_child(UI.label(String(w["name"]), 10, color.lightened(0.35) if owned else Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER))
	var status := "✓ Equipada" if equipped else ("Sua" if owned else "◎ %d" % int(w["cost"]))
	v.add_child(UI.label(status, 9, Color("6fe39a") if equipped else (UI.MUTED if owned else UI.GOLD), HORIZONTAL_ALIGNMENT_CENTER))
	b.add_child(v)
	b.pressed.connect(func():
		_weapon_pick = id
		_rebuild())
	return b


func _stat_bar(label_text: String, ratio: float, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var l := UI.label(label_text, 8, UI.MUTED)
	l.custom_minimum_size.x = 58
	row.add_child(l)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		var segs := 10
		var gap := 2.0
		var sw := (bar.size.x - gap * (segs - 1)) / segs
		var lit := clampf(ratio, 0.05, 1.0) * segs
		for i in segs:
			var r := Rect2(Vector2(i * (sw + gap), 2), Vector2(sw, 6))
			bar.draw_rect(r, Art.hdr(color, 1.15) if i < lit else Color(1, 1, 1, 0.1)))
	row.add_child(bar)
	return row


# ---------------------------------------------------------------- eternal blessings

func _page_perma() -> void:
	_list.add_child(_header("BÊNÇÃOS ETERNAS", "Melhorias permanentes, valem para todas as runs."))
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	for id in GameData.PERMA_ORDER:
		chips.add_child(_bonus_chip(id))
	_list.add_child(chips)
	for id in GameData.PERMA_ORDER:
		_list.add_child(_perma_card(id))


func _perma_total(id: String, lvl: int) -> String:
	match id:
		"vida":
			return "+%d de vida" % (10 * lvl)
		"forca":
			return "+%d%% de dano" % (10 * lvl)
		"fortuna":
			return "+%d%% de óbolos" % (25 * lvl)
	return ""


func _bonus_chip(id: String) -> Control:
	var color: Color = PERMA_COLOR[id]
	var p := UI.panel(color, 0.14, 999.0, 6.0)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := UI.label(_perma_total(id, Save.perma_level(id)), 9, color.lightened(0.35), HORIZONTAL_ALIGNMENT_CENTER)
	UI.body(p).add_child(l)
	return p


func _perma_card(id: String) -> Control:
	var u: Dictionary = GameData.PERMA[id]
	var lvl := Save.perma_level(id)
	var max_lvl := int(u["max"])
	var color: Color = PERMA_COLOR[id]
	var card := UI.panel(color, 0.12, 22.0, 12.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var med := Medallion.new()
	med.emblem = PERMA_EMBLEM[id]
	med.color = color
	med.custom_minimum_size = Vector2(72, 72)
	med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(med)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	var head := HBoxContainer.new()
	var n := UI.label(String(u["name"]).to_upper(), 15, color.lightened(0.3))
	n.add_theme_font_override("font", _spaced(UI.title_font(), 1))
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	head.add_child(UI.label("NV %d/%d" % [lvl, max_lvl], 10, UI.GOLD if lvl >= max_lvl else UI.MUTED))
	info.add_child(head)
	var effect := RichTextLabel.new()
	effect.bbcode_enabled = true
	effect.fit_content = true
	effect.scroll_active = false
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.add_theme_font_size_override("normal_font_size", 10)
	effect.add_theme_color_override("default_color", Color(1, 1, 1, 0.8))
	var hex := color.lightened(0.35).to_html(false)
	if lvl >= max_lvl:
		effect.text = "Atual: [color=#%s]%s[/color]  •  no máximo" % [hex, _perma_total(id, lvl)]
	else:
		effect.text = "Atual: [color=#%s]%s[/color]\nPróximo: [color=#%s]%s[/color]" % [hex, _perma_total(id, lvl) if lvl > 0 else "nada", UI.GOLD.to_html(false), _perma_total(id, lvl + 1)]
	info.add_child(effect)
	var pips := Control.new()
	pips.custom_minimum_size = Vector2(0, 10)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.draw.connect(func():
		var gap := 3.0
		var pw := (pips.size.x - gap * (max_lvl - 1)) / max_lvl
		for i in max_lvl:
			var r := Rect2(i * (pw + gap), 2, pw, 6)
			pips.draw_rect(r, Art.hdr(color, 1.2) if i < lvl else Color(1, 1, 1, 0.12)))
	info.add_child(pips)
	row.add_child(info)
	UI.body(card).add_child(row)

	var btn: Button
	if lvl >= max_lvl:
		btn = UI.button("Máximo", UI.GLASS_TINT, 12)
		btn.disabled = true
	else:
		var cost := Save.perma_cost(id)
		btn = UI.button("Melhorar   ◎ %d" % cost, UI.GOLD, 13)
		btn.disabled = not Save.can_afford(cost)
		btn.pressed.connect(func():
			if Save.buy_perma(id):
				_sfx.play("buy")
				_rebuild())
	btn.custom_minimum_size.y = 40
	UI.body(card).add_child(btn)
	return card


# ---------------------------------------------------------------- actions

func _open_settings() -> void:
	if _settings:
		return
	Music.ui("open")
	_settings = SettingsSheet.build(func():
		_settings.queue_free()
		_settings = null)
	add_child(_settings)


func _start(seed_value: int) -> void:
	Save.next_seed = seed_value
	Music.ui("start")
	get_tree().change_scene_to_file("res://scenes/game.tscn")


## Round medallion with an embossed emblem (art/emblems), used for weapons
## and upgrades.
class Medallion extends Control:
	var emblem := ""
	var color := Color.WHITE
	var rays := false
	var dim := false
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if rays:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		if rays:
			for i in 12:
				var a := _t * 0.4 + TAU * i / 12.0
				var d := Vector2.from_angle(a)
				var n := d.orthogonal()
				draw_colored_polygon(PackedVector2Array([c + n * 3.0, c + d * r * 1.25 + n * 9.0, c + d * r * 1.25 - n * 9.0, c - n * 3.0]),
					Color(color.r, color.g, color.b, 0.12))
		Art.glow(self, c, r * 1.3, color, 0.3 if dim else 0.55)
		draw_circle(c, r * 0.92, Color(0.03, 0.02, 0.05, 0.95))
		draw_circle(c, r * 0.84, Color(color.darkened(0.78), 1.0))
		draw_arc(c, r * 0.92, 0, TAU, 48, Art.hdr(UI.GOLD, 1.15) if not dim else Color(1, 1, 1, 0.3), maxf(1.5, r * 0.06), true)
		var tint := Color(0.4, 0.4, 0.45) if dim else Color.WHITE
		BoonArt.draw_emblem(self, emblem, c, r * 1.45, tint)
		if dim:
			UI.draw_icon(self, "lock", c + Vector2(r * 0.55, r * 0.55), r * 0.28, Color(1, 1, 1, 0.85))


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
			_hero.showcase = true
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

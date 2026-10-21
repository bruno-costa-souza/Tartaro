class_name Hud
extends CanvasLayer

signal retry_pressed
signal menu_pressed

var _root: Control
var _score: Label
var _room: Label
var _level: Label
var _coins: Label
var _combo: Label
var _seed: Label
var _banner: Label
var _hint: Label
var _boss_name: Label
var _intro: VBoxContainer
var _over: VBoxContainer
var _fade: ColorRect

var _hp := 1
var _max_hp := 1
var _xp_ratio := 0.0
var _xp_shown := 0.0
var _picks := {}
var _dash := 1
var _dash_max := 1
var _dash_ratio := 1.0
var _boss_ratio := -1.0
var _boss_shown := 1.0
var _hurt_flash := 0.0
var _level_flash := 0.0
var _top := 6.0


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_on_draw)
	add_child(_root)
	_top = UI.safe_top(_root.get_viewport_rect().size.x)

	_score = _add(UI.label("0", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT))
	_level = _add(UI.label("NV 1", 8, Color("5ff7ff")))
	_room = _add(UI.label("", 8, UI.MUTED))
	_coins = _add(UI.label("0", 10, UI.GOLD, HORIZONTAL_ALIGNMENT_RIGHT))
	_combo = _add(UI.label("", 16, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	_combo.visible = false
	_boss_name = _add(UI.label("", 10, Color("ff6b6b"), HORIZONTAL_ALIGNMENT_CENTER))
	_boss_name.visible = false
	_seed = _add(UI.label("", 8, UI.MUTED))
	_seed.modulate.a = 0.5
	_banner = _add(UI.label("", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	_banner.modulate.a = 0.0
	_hint = _add(UI.label("Arraste para mover\nToque rápido ou deslize para DASH", 8, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	var t := _hint.create_tween()
	t.tween_interval(5.0)
	t.tween_property(_hint, "modulate:a", 0.0, 0.6)


func _add(c: Control) -> Control:
	_root.add_child(c)
	return c


func _process(delta: float) -> void:
	_hurt_flash = maxf(_hurt_flash - delta * 3.0, 0.0)
	_level_flash = maxf(_level_flash - delta * 2.0, 0.0)
	_xp_shown = lerpf(_xp_shown, _xp_ratio, minf(delta * 12.0, 1.0))
	if _boss_ratio >= 0.0:
		_boss_shown = lerpf(_boss_shown, _boss_ratio, minf(delta * 6.0, 1.0))
	var vp := _root.get_viewport_rect().size
	_score.position = Vector2(vp.x - 170, _top + 8)
	_score.size = Vector2(160, 20)
	_level.position = Vector2(126, _top + 9)
	_room.position = Vector2(10, _top + 26)
	_coins.position = Vector2(vp.x - 130, _top + 28)
	_coins.size = Vector2(108, 14)
	_boss_name.position = Vector2(0, _top + 42)
	_boss_name.size = Vector2(vp.x, 14)
	_combo.position = Vector2(0, _top + (70 if _boss_name.visible else 44))
	_combo.size = Vector2(vp.x, 20)
	_combo.pivot_offset = _combo.size / 2
	_seed.position = Vector2(8, vp.y - 16)
	_banner.position = Vector2(0, vp.y * 0.3)
	_banner.size = Vector2(vp.x, 30)
	_banner.pivot_offset = _banner.size / 2
	_hint.position = Vector2(0, vp.y * 0.62)
	_hint.size = Vector2(vp.x, 30)
	if _intro:
		_intro.position = Vector2(0, vp.y * 0.36)
		_intro.size.x = vp.x
	if _over:
		_over.position = Vector2(20, vp.y * 0.22)
		_over.size.x = vp.x - 40
	_root.queue_redraw()


func set_hp(hp: int, max_hp: int) -> void:
	if hp < _hp:
		_hurt_flash = 1.0
	_hp = hp
	_max_hp = max_hp


func set_level(level: int, xp: float, need: int) -> void:
	if _level.text != "NV %d" % level:
		_level_flash = 1.0
		_xp_shown = 0.0
	_level.text = "NV %d" % level
	_xp_ratio = clampf(xp / need, 0.0, 1.0)


func set_coins(coins: int) -> void:
	_coins.text = str(coins)


func set_score(score: int) -> void:
	_score.text = str(score)


func set_room(biome_name: String, room_num: int, wave: int, waves: int, cycle: int) -> void:
	var text := "%s  %d/%d" % [biome_name, room_num, GameData.ROOMS_PER_BIOME]
	if cycle > 0:
		text = "C%d  " % (cycle + 1) + text
	if waves > 0:
		text += "  -  ONDA %d/%d" % [wave, waves]
	_room.text = text


func set_dash(charges: int, max_charges: int, ratio: float) -> void:
	_dash = charges
	_dash_max = max_charges
	_dash_ratio = ratio


func set_boons(picks: Dictionary) -> void:
	_picks = picks.duplicate()


func set_seed(seed_value: int, daily: bool) -> void:
	_seed.text = "SEED %d%s" % [seed_value, " - DESAFIO DIÁRIO" if daily else " - TREINO"]


func set_combo(combo: int) -> void:
	if combo < 2:
		_combo.visible = false
		return
	_combo.visible = true
	_combo.text = "COMBO x%d" % combo
	_combo.scale = Vector2(1.4, 1.4)
	_combo.create_tween().tween_property(_combo, "scale", Vector2.ONE, 0.15)


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	_banner.scale = Vector2(1.5, 1.5)
	var t := _banner.create_tween()
	t.tween_property(_banner, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.9)
	t.tween_property(_banner, "modulate:a", 0.0, 0.3)


func hide_banner() -> void:
	_banner.modulate.a = 0.0


func fade(alpha: float, duration: float) -> Tween:
	var t := _fade.create_tween()
	t.tween_property(_fade, "modulate:a", alpha, duration)
	return t


func show_boss_intro(boss_name: String, title: String) -> void:
	_intro = VBoxContainer.new()
	_intro.add_theme_constant_override("separation", 2)
	_root.add_child(_intro)
	_intro.add_child(UI.label(boss_name, 32, Color("ff5e57"), HORIZONTAL_ALIGNMENT_CENTER))
	_intro.add_child(UI.label(title, 10, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_intro.modulate.a = 0.0
	_intro.scale = Vector2(1.3, 1.3)
	var t := _intro.create_tween()
	t.tween_property(_intro, "modulate:a", 1.0, 0.3)
	t.tween_interval(1.4)
	t.tween_property(_intro, "modulate:a", 0.0, 0.4)
	t.tween_callback(_intro.queue_free)


func show_boss_bar(boss_name: String) -> void:
	_boss_name.text = boss_name
	_boss_name.visible = true
	_boss_ratio = 1.0
	_boss_shown = 0.0


func set_boss_hp(ratio: float) -> void:
	_boss_ratio = ratio


func hide_boss_bar() -> void:
	_boss_name.visible = false
	_boss_ratio = -1.0


func show_game_over(r: Dictionary) -> void:
	_combo.visible = false
	_over = VBoxContainer.new()
	_over.add_theme_constant_override("separation", 6)
	_over.modulate.a = 0.0
	_root.add_child(_over)

	_over.add_child(UI.label("VOCÊ CAIU", 24, Color("ff5e57"), HORIZONTAL_ALIGNMENT_CENTER))
	if r["record"]:
		_over.add_child(UI.label("NOVO RECORDE!", 12, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	_over.add_child(UI.label("%d pts" % r["score"], 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	_over.add_child(UI.label("%s  -  Sala %d" % [r["biome"], r["room"]], 10, Color("e8d9b0"), HORIZONTAL_ALIGNMENT_CENTER))
	var secs := int(r["seconds"])
	_over.add_child(UI.label("Nível %d  -  Combo x%d  -  %d:%02d" % [
		r["level"], r["combo"], secs / 60, secs % 60], 8, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_over.add_child(UI.label("+%d óbolos" % r["coins"], 16, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	_over.add_child(spacer)
	var retry := UI.button("TENTAR DE NOVO", Color("c0392b"), 16)
	retry.custom_minimum_size.y = 46
	retry.pressed.connect(func(): retry_pressed.emit())
	_over.add_child(retry)
	var menu := UI.button("ARSENAL", Color("2980b9"), 12)
	menu.custom_minimum_size.y = 38
	menu.pressed.connect(func(): menu_pressed.emit())
	_over.add_child(menu)

	retry.disabled = true
	menu.disabled = true
	var t := _over.create_tween().set_ignore_time_scale(true)
	t.tween_property(_over, "modulate:a", 1.0, 0.4)
	t.tween_interval(0.5)
	t.tween_callback(func():
		retry.disabled = false
		menu.disabled = false)


func _on_draw() -> void:
	var vp := _root.get_viewport_rect().size
	if _hurt_flash > 0.0:
		_root.draw_rect(Rect2(Vector2.ZERO, vp), Color(1, 0, 0, 0.25 * _hurt_flash))

	var xp_bar := Rect2(10, _top, vp.x - 20, 4)
	_root.draw_rect(xp_bar.grow(1), Color.BLACK)
	_root.draw_rect(xp_bar, Color("10303a"))
	_root.draw_rect(Rect2(xp_bar.position, Vector2(xp_bar.size.x * _xp_shown, 4)), Color("5ff7ff"))
	if _level_flash > 0.0:
		_root.draw_rect(xp_bar.grow(1), Color(1, 1, 1, _level_flash * 0.8))

	var bar := Rect2(10, _top + 10, 110, 8)
	_root.draw_rect(bar.grow(1), Color.BLACK)
	_root.draw_rect(bar, Color("3a1010"))
	_root.draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(_hp) / _max_hp, bar.size.y)), Color("e74c3c"))

	for i in _dash_max:
		var r := Rect2(10 + i * 18, _top + 21, 15, 3)
		_root.draw_rect(r, Color("1a3a44"))
		var fill := 1.0 if i < _dash else (_dash_ratio if i == _dash else 0.0)
		_root.draw_rect(Rect2(r.position, Vector2(r.size.x * fill, 3)), Color("7fe7ff") if i < _dash else Color("3d8a99"))

	var coin := Vector2(vp.x - 15, _top + 35)
	_root.draw_circle(coin, 4.0, Color("b8860b"))
	_root.draw_circle(coin, 3.0, UI.GOLD)

	if _boss_ratio >= 0.0:
		var bb := Rect2(30, _top + 57, vp.x - 60, 7)
		_root.draw_rect(bb.grow(1), Color.BLACK)
		_root.draw_rect(bb, Color("3a1010"))
		_root.draw_rect(Rect2(bb.position, Vector2(bb.size.x * _boss_shown, bb.size.y)), Color("ffb142"))
		_root.draw_rect(Rect2(bb.position, Vector2(bb.size.x * _boss_ratio, bb.size.y)), Color("ff4757"))
		_root.draw_line(Vector2(bb.position.x + bb.size.x / 2, bb.position.y), Vector2(bb.position.x + bb.size.x / 2, bb.end.y), Color(1, 1, 1, 0.5))

	var font := ThemeDB.fallback_font
	var x := 10.0
	var y := vp.y - 34
	for b in GameData.BOONS:
		var lvl := int(_picks.get(b["id"], 0))
		if lvl == 0:
			continue
		var c: Color = b["color"]
		_root.draw_rect(Rect2(x, y, 24, 12), c.darkened(0.6))
		_root.draw_rect(Rect2(x, y, 24, 12), c, false, 1.0)
		_root.draw_string(font, Vector2(x + 2, y + 10), "%s%d" % [String(b["god"]).left(2), lvl], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
		x += 27
		if x > vp.x - 34:
			x = 10.0
			y -= 15
	for d in GameData.DUOS:
		if _picks.has(d["id"]):
			_root.draw_rect(Rect2(x, y, 24, 12), GameData.DUO_COLOR.darkened(0.5))
			_root.draw_rect(Rect2(x, y, 24, 12), GameData.DUO_COLOR, false, 1.0)
			_root.draw_string(font, Vector2(x + 2, y + 10), "DUO", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
			x += 27
			if x > vp.x - 34:
				x = 10.0
				y -= 15

	if _over:
		_root.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.65 * _over.modulate.a))

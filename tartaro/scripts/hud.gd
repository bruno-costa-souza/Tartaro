class_name Hud
extends CanvasLayer

signal retry_pressed
signal menu_pressed
signal pause_pressed

const VITALS_W := 172.0
const VITALS_H := 46.0
const BOON_ROW := 12

var _root: Control
var _vitals: PanelContainer
var _vitals_draw: Control
var _level: Label
var _hp_text: Label
var _score: Label
var _room: Label
var _coins: Label
var _combo: Label
var _seed: Label
var _banner: Label
var _hint: Label
var _boss_panel: PanelContainer
var _boss_name: Label
var _boss_draw: Control
var _boons_panel: PanelContainer
var _boons_draw: Control
var _letterbox: Control
var _intro: VBoxContainer
var _over: Control
var _fade: ColorRect

var _hp := 1
var _max_hp := 1
var _hp_shown := 1.0
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
var _bars := 0.0
var _top := 8.0
var _boon_rows := 0
var _vp := Vector2(360, 640)


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_on_draw)
	add_child(_root)
	_vp = _root.get_viewport_rect().size
	_top = UI.safe_top(_vp.x)

	_vitals = UI.panel(UI.GLASS_TINT, 0.1, 999.0, 0.0)
	_vitals.position = Vector2(10, _top)
	_vitals.size = Vector2(VITALS_W, VITALS_H)
	_vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_vitals)
	_vitals_draw = Control.new()
	_vitals_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals_draw.draw.connect(_draw_vitals)
	UI.body(_vitals).add_child(_vitals_draw)
	_vitals_draw.custom_minimum_size = Vector2(VITALS_W, VITALS_H)
	_level = UI.label("1", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_level.position = Vector2(4, 13)
	_level.size = Vector2(34, 20)
	_vitals_draw.add_child(_level)
	_hp_text = UI.label("", 7, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_RIGHT)
	_hp_text.position = Vector2(VITALS_W - 80, 3)
	_hp_text.size = Vector2(66, 10)
	_vitals_draw.add_child(_hp_text)

	var pause := UI.button("", UI.GLASS_TINT, 10)
	pause.position = Vector2(_vp.x - 46, _top + 5)
	pause.size = Vector2(36, 36)
	var pause_icon := UI.icon("pause", 12, Color.WHITE)
	pause_icon.position = Vector2(12, 12)
	pause.add_child(pause_icon)
	pause.pressed.connect(func(): pause_pressed.emit())
	_root.add_child(pause)

	var coin_pill := UI.panel(UI.GOLD, 0.12, 999.0, 0.0)
	coin_pill.position = Vector2(_vp.x - 136, _top + 5)
	coin_pill.size = Vector2(84, 36)
	coin_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_theme_constant_override("separation", 5)
	crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crow.add_child(UI.icon("coin", 14, UI.GOLD))
	_coins = UI.label("0", 13, UI.GOLD)
	crow.add_child(_coins)
	UI.body(coin_pill).alignment = BoxContainer.ALIGNMENT_CENTER
	UI.body(coin_pill).add_child(crow)
	_root.add_child(coin_pill)

	_score = UI.label("0", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_score.position = Vector2(_vp.x - 180, _top + 44)
	_score.size = Vector2(168, 24)
	_root.add_child(_score)
	_room = UI.label("", 8, Color(1, 1, 1, 0.75))
	_room.position = Vector2(16, _top + VITALS_H + 4)
	_root.add_child(_room)

	_boss_panel = UI.panel(Color("ff5e57"), 0.12, 999.0, 0.0)
	_boss_panel.position = Vector2(26, _top + 74)
	_boss_panel.size = Vector2(_vp.x - 52, 34)
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.visible = false
	_boss_draw = Control.new()
	_boss_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_draw.custom_minimum_size = _boss_panel.size
	_boss_draw.draw.connect(_draw_boss_bar)
	UI.body(_boss_panel).add_child(_boss_draw)
	_boss_name = UI.label("", 11, Color("ffd0c0"), HORIZONTAL_ALIGNMENT_CENTER)
	_boss_name.position = Vector2(0, 2)
	_boss_name.size = Vector2(_boss_panel.size.x, 14)
	_boss_draw.add_child(_boss_name)
	_root.add_child(_boss_panel)

	_boons_panel = UI.panel(UI.GLASS_TINT, 0.08, 999.0, 0.0)
	_boons_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boons_panel.visible = false
	_boons_draw = Control.new()
	_boons_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boons_draw.draw.connect(_draw_boons)
	UI.body(_boons_panel).add_child(_boons_draw)
	_root.add_child(_boons_panel)

	_combo = UI.label("", 20, Art.hdr(UI.GOLD, 1.2), HORIZONTAL_ALIGNMENT_CENTER)
	_combo.visible = false
	_root.add_child(_combo)
	_seed = UI.label("", 7, Color(1, 1, 1, 0.4))
	_root.add_child(_seed)
	_banner = UI.label("", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.modulate.a = 0.0
	_root.add_child(_banner)
	_hint = UI.label("Arraste para mover\nToque rápido ou deslize para DASH", 9, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	_root.add_child(_hint)

	_letterbox = Control.new()
	_letterbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_letterbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letterbox.draw.connect(_draw_letterbox)
	_root.add_child(_letterbox)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	var t := _hint.create_tween()
	t.tween_interval(5.0)
	t.tween_property(_hint, "modulate:a", 0.0, 0.6)


func _process(delta: float) -> void:
	_hurt_flash = maxf(_hurt_flash - delta * 3.0, 0.0)
	_level_flash = maxf(_level_flash - delta * 2.0, 0.0)
	_xp_shown = lerpf(_xp_shown, _xp_ratio, minf(delta * 12.0, 1.0))
	_hp_shown = lerpf(_hp_shown, float(_hp) / _max_hp, minf(delta * 4.0, 1.0))
	if _boss_ratio >= 0.0:
		_boss_shown = lerpf(_boss_shown, _boss_ratio, minf(delta * 5.0, 1.0))
	_vp = _root.get_viewport_rect().size
	var boon_h := (_boon_rows * 20.0 + 8.0) if _boons_panel.visible else 0.0
	_boss_panel.position.y = _top + 74 + boon_h
	_combo.position = Vector2(0, _top + (116 if _boss_panel.visible else 74) + boon_h)
	_combo.size = Vector2(_vp.x, 26)
	_combo.pivot_offset = _combo.size / 2
	_seed.position = Vector2(12, _vp.y - UI.safe_bottom(_vp.x) - 10)
	_banner.position = Vector2(0, _vp.y * 0.3)
	_banner.size = Vector2(_vp.x, 34)
	_banner.pivot_offset = _banner.size / 2
	_hint.position = Vector2(0, _vp.y * 0.62)
	_hint.size = Vector2(_vp.x, 30)
	if _intro:
		_intro.position = Vector2(0, _vp.y * 0.38)
		_intro.size.x = _vp.x
	_vitals_draw.queue_redraw()
	if _boss_panel.visible:
		_boss_draw.queue_redraw()
	_root.queue_redraw()
	_letterbox.queue_redraw()


func set_hp(hp: int, max_hp: int) -> void:
	if hp < _hp:
		_hurt_flash = 1.0
	_hp = hp
	_max_hp = max_hp
	_hp_text.text = "%d/%d" % [hp, max_hp]


func set_level(level: int, xp: float, need: int) -> void:
	if _level.text != str(level):
		_level_flash = 1.0
		_xp_shown = 0.0
		_level.scale = Vector2(1.5, 1.5)
		_level.pivot_offset = _level.size / 2
		_level.create_tween().tween_property(_level, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	_level.text = str(level)
	_xp_ratio = clampf(xp / need, 0.0, 1.0)


func set_coins(coins: int) -> void:
	_coins.text = str(coins)


func set_score(score: int) -> void:
	_score.text = str(score)


func set_room(biome_name: String, room_num: int, wave: int, waves: int, cycle: int) -> void:
	var text := "%s  ·  %d/%d" % [biome_name.capitalize(), room_num, GameData.ROOMS_PER_BIOME]
	if cycle > 0:
		text = "Ciclo %d  ·  " % (cycle + 1) + text
	if waves > 0:
		text += "  ·  Onda %d/%d" % [wave, waves]
	_room.text = text


func set_dash(charges: int, max_charges: int, ratio: float) -> void:
	_dash = charges
	_dash_max = max_charges
	_dash_ratio = ratio


func set_boons(picks: Dictionary) -> void:
	_picks = picks.duplicate()
	var n := 0
	for b in GameData.BOONS:
		if _picks.has(b["id"]):
			n += 1
	for d in GameData.DUOS:
		if _picks.has(d["id"]):
			n += 1
	_boons_panel.visible = n > 0
	var per_row := BOON_ROW
	var rows := ceili(float(n) / per_row)
	_boon_rows = rows
	var w := 6.0 + minf(n, per_row) * 20.0
	var h := 6.0 + rows * 20.0
	_boons_panel.size = Vector2(w, h)
	_boons_draw.custom_minimum_size = Vector2(w, h)
	_boons_panel.position = Vector2(10, _top + VITALS_H + 18)
	var g: Glass = _boons_panel.get_child(0)
	g.radius = 999.0 if rows <= 1 else 16.0
	g.apply()


func set_seed(seed_value: int, daily: bool) -> void:
	_seed.text = "SEED %d%s" % [seed_value, " · DESAFIO DIÁRIO" if daily else " · TREINO"]


func set_combo(combo: int) -> void:
	if combo < 2:
		_combo.visible = false
		return
	_combo.visible = true
	_combo.text = "COMBO ×%d" % combo
	_combo.scale = Vector2(1.45, 1.45)
	_combo.create_tween().tween_property(_combo, "scale", Vector2.ONE, 0.16)


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	_banner.scale = Vector2(1.4, 1.4)
	var t := _banner.create_tween()
	t.tween_property(_banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
	_intro.add_theme_constant_override("separation", 0)
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_intro)
	var name_label := UI.label(boss_name, 40, Art.hdr(Color("ff7a55"), 1.4), HORIZONTAL_ALIGNMENT_CENTER)
	name_label.add_theme_constant_override("outline_size", 0)
	_intro.add_child(name_label)
	_intro.add_child(UI.label(title.to_upper(), 9, Color(1, 0.9, 0.8, 0.85), HORIZONTAL_ALIGNMENT_CENTER))
	_intro.modulate.a = 0.0
	var t := _intro.create_tween()
	t.tween_property(self, "_bars", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_intro, "modulate:a", 1.0, 0.4)
	t.tween_interval(1.3)
	t.tween_property(_intro, "modulate:a", 0.0, 0.35)
	t.parallel().tween_property(self, "_bars", 0.0, 0.45).set_ease(Tween.EASE_IN)
	t.tween_callback(_intro.queue_free)


func show_boss_bar(boss_name: String) -> void:
	_boss_name.text = boss_name
	_boss_panel.visible = true
	_boss_ratio = 1.0
	_boss_shown = 0.0


func set_boss_hp(ratio: float) -> void:
	_boss_ratio = ratio


func hide_boss_bar() -> void:
	_boss_panel.visible = false
	_boss_ratio = -1.0


func show_game_over(r: Dictionary) -> void:
	_combo.visible = false
	_over = Control.new()
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_over)

	var frost := Glass.make(Color(0.05, 0.03, 0.08), 0.45, 0.0)
	frost.edge_light = 0.0
	frost.refraction = 0.0
	_over.add_child(frost)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.add_child(center)
	var card := UI.panel(Color("ff5e57"), 0.08, 26.0, 18.0)
	card.custom_minimum_size = Vector2(_vp.x - 44, 0)
	center.add_child(card)
	var v := UI.body(card)
	v.add_theme_constant_override("separation", 8)

	v.add_child(UI.label("VOCÊ CAIU", 30, Color("ff6b5e"), HORIZONTAL_ALIGNMENT_CENTER))
	if r["record"]:
		v.add_child(UI.label("NOVO RECORDE!", 11, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var score := UI.label(str(r["score"]), 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(score)
	v.add_child(UI.label("PONTOS", 7, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var grid := HBoxContainer.new()
	var secs := int(r["seconds"])
	for s in [[String(r["biome"]).capitalize(), "Sala %d" % r["room"]], [str(r["level"]), "Nível"], ["×%d" % r["combo"], "Combo"], ["%d:%02d" % [secs / 60, secs % 60], "Tempo"]]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		cell.add_child(UI.label(s[0], 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		cell.add_child(UI.label(s[1], 7, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		grid.add_child(cell)
	v.add_child(grid)

	var coins_row := HBoxContainer.new()
	coins_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coins_row.add_theme_constant_override("separation", 6)
	coins_row.add_child(UI.icon("coin", 16, UI.GOLD))
	coins_row.add_child(UI.label("+%d óbolos" % r["coins"], 15, UI.GOLD))
	v.add_child(coins_row)
	v.add_child(UI.spacer(4))

	var retry := UI.button("Tentar de novo", UI.EMBER, 16)
	retry.custom_minimum_size.y = 50
	retry.pressed.connect(func(): retry_pressed.emit())
	v.add_child(retry)
	var menu := UI.button("Menu", UI.GLASS_TINT, 12)
	menu.custom_minimum_size.y = 40
	menu.pressed.connect(func(): menu_pressed.emit())
	v.add_child(menu)

	retry.disabled = true
	menu.disabled = true
	_over.modulate.a = 0.0
	card.pivot_offset = Vector2(card.custom_minimum_size.x / 2, 180)
	card.scale = Vector2(0.92, 0.92)
	var t := _over.create_tween().set_ignore_time_scale(true)
	t.tween_property(_over, "modulate:a", 1.0, 0.4)
	t.parallel().tween_property(card, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.4)
	t.tween_callback(func():
		retry.disabled = false
		menu.disabled = false)


func _pill(ci: CanvasItem, r: Rect2, color: Color) -> void:
	if r.size.x <= 0.5:
		return
	var rad := minf(r.size.y / 2, r.size.x / 2)
	ci.draw_rect(Rect2(r.position + Vector2(rad, 0), Vector2(maxf(r.size.x - rad * 2, 0), r.size.y)), color)
	ci.draw_circle(r.position + Vector2(rad, rad), rad, color)
	ci.draw_circle(Vector2(r.end.x - rad, r.position.y + rad), rad, color)


func _draw_vitals() -> void:
	var c := _vitals_draw
	var badge := Vector2(21, 23)
	c.draw_circle(badge, 16.0, Color(0, 0, 0, 0.35))
	c.draw_arc(badge, 16.0, -PI / 2, -PI / 2 + TAU * _xp_shown, 32, Color("5ff7ff"), 2.5, true)
	if _level_flash > 0.0:
		c.draw_circle(badge, 16.0, Color(1, 1, 1, 0.4 * _level_flash))
	var bar := Rect2(44, 13, VITALS_W - 58, 9)
	_pill(c, bar, Color(0, 0, 0, 0.45))
	_pill(c, Rect2(bar.position, Vector2(bar.size.x * _hp_shown, bar.size.y)), Color(1, 0.85, 0.75, 0.8))
	_pill(c, Rect2(bar.position, Vector2(bar.size.x * float(_hp) / _max_hp, bar.size.y)), Color("ff4d5e"))
	c.draw_rect(Rect2(bar.position + Vector2(4, 1), Vector2(maxf(bar.size.x * float(_hp) / _max_hp - 8, 0), 2)), Color(1, 1, 1, 0.3))
	UI.draw_icon(c, "heart", Vector2(bar.position.x + 1, bar.position.y - 6), 4.0, Color("ff4d5e"))
	var xp := Rect2(44, 26, VITALS_W - 58, 4)
	_pill(c, xp, Color(0, 0, 0, 0.4))
	_pill(c, Rect2(xp.position, Vector2(xp.size.x * _xp_shown, xp.size.y)), Color("5ff7ff"))
	for i in _dash_max:
		var r := Rect2(44 + i * 20, 34, 16, 4)
		_pill(c, r, Color(0, 0, 0, 0.4))
		var fill := 1.0 if i < _dash else (_dash_ratio if i == _dash else 0.0)
		_pill(c, Rect2(r.position, Vector2(r.size.x * fill, r.size.y)), Color("9be8ff") if i < _dash else Color("3d8a99"))


func _draw_boss_bar() -> void:
	var c := _boss_draw
	var bar := Rect2(14, 18, _boss_panel.size.x - 28, 8)
	_pill(c, bar, Color(0, 0, 0, 0.5))
	_pill(c, Rect2(bar.position, Vector2(bar.size.x * _boss_shown, bar.size.y)), Color(1, 0.85, 0.6, 0.85))
	_pill(c, Rect2(bar.position, Vector2(bar.size.x * maxf(_boss_ratio, 0.0), bar.size.y)), Color("ff4d4d"))
	c.draw_line(Vector2(bar.position.x + bar.size.x / 2, bar.position.y - 1), Vector2(bar.position.x + bar.size.x / 2, bar.end.y + 1), Color(1, 1, 1, 0.6), 1.0)


func _draw_boons() -> void:
	var c := _boons_draw
	var font := UI.title_font()
	var i := 0
	var entries: Array = []
	for b in GameData.BOONS:
		if _picks.has(b["id"]):
			entries.append([b["color"], String(b["god"]).left(1), int(_picks[b["id"]])])
	for d in GameData.DUOS:
		if _picks.has(d["id"]):
			entries.append([GameData.DUO_COLOR, "D", 1])
	for e in entries:
		var p := Vector2(13 + (i % BOON_ROW) * 20, 13 + (i / BOON_ROW) * 20)
		var col: Color = e[0]
		c.draw_circle(p, 8.5, Color(col.darkened(0.6), 0.75))
		c.draw_arc(p, 8.5, 0, TAU, 24, col, 1.4, true)
		c.draw_string(font, p + Vector2(-8, 3.5), e[1], HORIZONTAL_ALIGNMENT_CENTER, 16, 9, Color.WHITE)
		if int(e[2]) > 1:
			c.draw_circle(p + Vector2(6.5, 6.5), 3.8, col)
			c.draw_string(ThemeDB.fallback_font, p + Vector2(4.6, 8.8), str(e[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color.BLACK)
		i += 1


func _draw_letterbox() -> void:
	if _bars <= 0.0:
		return
	var h := 64.0 * _bars
	_letterbox.draw_rect(Rect2(0, 0, _vp.x, h), Color.BLACK)
	_letterbox.draw_rect(Rect2(0, _vp.y - h, _vp.x, h), Color.BLACK)


func _on_draw() -> void:
	var vp := _vp
	if _hurt_flash > 0.0:
		for i in 6:
			var inset := i * 8.0
			_root.draw_rect(Rect2(Vector2(inset, inset), vp - Vector2(inset, inset) * 2), Color(1, 0, 0, 0.09 * _hurt_flash * (1.0 - i / 6.0)), false, 8.0)

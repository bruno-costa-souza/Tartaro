class_name PowersSheet
## Every power of the current run in detail (weapon, totals and each boon with
## its stacked effect). Opened from the HUD's laurel button; the run is
## paused while it is open.

const WEAPON_EMBLEM := {"lanca": "lanca", "arco": "artemis", "espada": "ares", "cetro": "cetro"}


static func build(game: Node, on_close: Callable) -> Control:
	var vp: Vector2 = game.get_viewport().get_visible_rect().size
	var top := UI.safe_top(vp.x)
	var bottom := UI.safe_bottom(vp.x)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.process_mode = Node.PROCESS_MODE_ALWAYS

	var frost := Glass.make(Color(0.03, 0.015, 0.06), 0.78, 0.0)
	frost.blur = 5.0
	frost.edge_light = 0.0
	frost.refraction = 0.0
	root.add_child(frost)

	var box := VBoxContainer.new()
	box.position = Vector2(16, top + 8)
	box.size = Vector2(vp.x - 32, vp.y - top - bottom - 16)
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)

	var head := HBoxContainer.new()
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	var title := UI.label("PODERES", 26, Art.hdr(UI.GOLD, 1.2))
	title.add_theme_font_override("font", _spaced(UI.title_font(), 3))
	titles.add_child(title)
	var room := int(game.room_index) % GameData.ROOMS_PER_BIOME + 1
	titles.add_child(UI.label("Nível %d  •  %s, sala %d" % [game.level, String(game.biome()["name"]).capitalize(), room], 10, UI.MUTED))
	head.add_child(titles)
	var close := UI.button("✕", UI.GLASS_TINT, 14)
	close.custom_minimum_size = Vector2(40, 40)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(on_close)
	head.add_child(close)
	box.add_child(head)

	box.add_child(_weapon_card(game))
	box.add_child(_stats(game))

	var count := 0
	for b in GameData.BOONS:
		if game.picks.has(b["id"]):
			count += 1
	for d in GameData.DUOS:
		if game.picks.has(d["id"]):
			count += 1
	var section := UI.label("BÊNÇÃOS  (%d)" % count, 11, Color("f0e2c0"))
	section.add_theme_font_override("font", _spaced(UI.title_font(), 2))
	box.add_child(section)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	box.add_child(scroll)
	if count == 0:
		var empty := UI.wrap_label("Nenhuma bênção ainda. Derrote inimigos para subir de nível e pegue os orbes dos deuses.", 11, Color(1, 1, 1, 0.6))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(UI.spacer(20))
		list.add_child(empty)
	for d in GameData.DUOS:
		if game.picks.has(d["id"]):
			list.add_child(_row(d, 1.0, 1, true))
	for b in GameData.BOONS:
		if game.picks.has(b["id"]):
			list.add_child(_row(b, float(game.boons.get(b["id"], 0.0)), int(game.picks[b["id"]]), false))

	var resume := UI.button("Continuar", UI.EMBER, 16)
	resume.custom_minimum_size.y = 50
	resume.pressed.connect(on_close)
	box.add_child(resume)

	root.modulate.a = 0.0
	root.create_tween().set_ignore_time_scale(true).tween_property(root, "modulate:a", 1.0, 0.18)
	return root


static func _spaced(base: Font, spacing: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = base
	f.spacing_glyph = spacing
	return f


static func _weapon_card(game: Node) -> Control:
	var w: Dictionary = game.weapon
	var color: Color = w["color"]
	var card := UI.panel(color, 0.12, 18.0, 10.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon := _emblem_box(WEAPON_EMBLEM.get(game.weapon_id, "lanca"), "", color, UI.GOLD, 46.0)
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 1)
	info.add_child(UI.label(String(w["name"]), 14, color.lightened(0.3)))
	var forge := int(game.forge)
	var line := "Dano base %d" % (int(w["damage"]) + forge)
	if forge > 0:
		line += "  •  Bigorna +%d" % forge
	info.add_child(UI.label(line, 9, UI.MUTED))
	row.add_child(info)
	UI.body(card).add_child(row)
	return card


static func _stats(game: Node) -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var base_interval := float(game.weapon["interval"])
	var atk := (base_interval / float(game.attack_interval()) - 1.0) * 100.0
	var pickup := float(game.boon("demeter")) * 40.0
	var items := [
		["DANO", "×%.2f" % game.damage_mult(), Color("ff5e57")],
		["ATAQUE", "+%d%%" % roundi(atk), Color("ffb142")],
		["CRÍTICO", "%d%%" % roundi(game.crit_chance() * 100.0), Color("9be36d")],
		["MOVIMENTO", "+%d%%" % roundi((game.move_speed_mult() - 1.0) * 100.0), Color("f7f1e3")],
		["DASH", "%d %s" % [game.player.max_dash_charges, "carga" if game.player.max_dash_charges == 1 else "cargas"], Color("7fe7ff")],
		["COLETA", "+%d%%" % roundi(pickup), Color("e1b12c")],
	]
	for it in items:
		var p := UI.panel(it[2], 0.08, 14.0, 6.0)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UI.body(p)
		v.add_theme_constant_override("separation", 0)
		v.add_child(UI.label(it[1], 15, (it[2] as Color).lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(UI.label(it[0], 7, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		grid.add_child(p)
	return grid


static func _row(b: Dictionary, total: float, level: int, duo: bool) -> Control:
	var color: Color = GameData.DUO_COLOR if duo else b["color"]
	var card := UI.panel(color, 0.1, 18.0, 10.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var god_a: String = b["gods"][0] if duo else (b["id"] if GameData.GODS.has(b["id"]) else "olimpo")
	var god_b: String = b["gods"][1] if duo else ""
	row.add_child(_emblem_box(god_a, god_b, color, GameData.DUO_COLOR if duo else color.lightened(0.2), 50.0))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	var top := HBoxContainer.new()
	var name_label := UI.label(String(b["name"]).to_upper(), 12, color.lightened(0.4))
	name_label.add_theme_font_override("font", _spaced(UI.title_font(), 1))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name_label)
	top.add_child(UI.label("DUO" if duo else "NV %d" % level, 9, GameData.DUO_COLOR if duo else UI.GOLD))
	info.add_child(top)
	if not duo:
		var max_lvl := int(b["max"])
		var pips := Control.new()
		pips.custom_minimum_size = Vector2(0, 8)
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.draw.connect(func():
			var gap := 3.0
			var n := mini(max_lvl, 10)
			var pw := minf(18.0, (pips.size.x - gap * (n - 1)) / n)
			for i in n:
				pips.draw_rect(Rect2(i * (pw + gap), 1, pw, 5), Art.hdr(color, 1.2) if i < level else Color(1, 1, 1, 0.12)))
		info.add_child(pips)
	var god_line: String = b["god"]
	info.add_child(UI.label(god_line, 8, Color(color.lightened(0.2), 0.75)))
	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.scroll_active = false
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.add_theme_font_size_override("normal_font_size", 11)
	desc.add_theme_color_override("default_color", Color(1, 1, 1, 0.9))
	desc.text = BoonArt.rich_desc(BoonArt.current_effect(b, total, level), UI.GOLD.lightened(0.2))
	info.add_child(desc)
	row.add_child(info)
	UI.body(card).add_child(row)
	return card


static func _emblem_box(god_a: String, god_b: String, color: Color, frame: Color, size: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var m := c.size * 0.5
		var r := size * 0.5
		var sq := PackedVector2Array([m + Vector2(0, -r), m + Vector2(r, 0), m + Vector2(0, r), m + Vector2(-r, 0)])
		Art.glow(c, m, r * 1.3, color, 0.35)
		c.draw_colored_polygon(sq, Color(0.02, 0.01, 0.03, 0.95))
		var inner := PackedVector2Array()
		for p in sq:
			inner.append(m + (p - m) * 0.86)
		c.draw_colored_polygon(inner, Color(color.darkened(0.72), 1.0))
		var ring := sq.duplicate()
		ring.append(sq[0])
		c.draw_polyline(ring, Art.hdr(frame, 1.2), 2.0, true)
		if god_b != "":
			BoonArt.draw_emblem(c, god_a, m + Vector2(-6, -4), size * 0.62)
			BoonArt.draw_emblem(c, god_b, m + Vector2(7, 6), size * 0.62)
		else:
			BoonArt.draw_emblem(c, god_a, m, size * 0.86))
	return c

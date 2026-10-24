extends Node2D

const MIN_SPAWN_DIST := 110.0
const BASE_PICKUP_RADIUS := 40.0

var seed_value := 0
var is_daily := true
var boon_rng := RandomNumberGenerator.new()
var _room_rng := RandomNumberGenerator.new()

var room: Room
var world: Node2D
var player: Player
var camera: GameCamera
var controls: TouchControls
var hud: Hud
var sfx: Sfx
var boss: Boss

var weapon_id := "lanca"
var weapon: Dictionary
var boons := {}
var picks := {}
var forge := 0

var room_index := 0
var biome_index := 0
var cycle := 0
var waves_total := 0
var wave_in_room := 0

var score := 0
var combo := 0
var best_combo := 0
var elapsed := 0.0
var level := 1
var xp := 0.0
var run_coins := 0
var is_game_over := false
var kills := 0
var bosses_killed := 0
var _pause_sheet: Control

var _room_state := "intro"
var _combo_timer := 0.0
var _pending_spawns := 0
var _room_token := 0
var _room_reward := ""
var _current_req: Dictionary = {}
var _last_voice_ms := -100000
var _hitstop_count := 0
var _panel_queue: Array = []
var _choosing := false
var _hazard_tick := 0.0
var _heal_acc := 0.0
var _frenzy_t := 0.0
var _moon_angle := 0.0
var _moon_hits := {}
var _moons_node: Node2D
var _ambient: CanvasModulate
var _atmo: ShaderMaterial
var _motes: CPUParticles2D
var _guide: Node2D
var _guide_t := 0.0


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	is_daily = Save.next_seed == 0
	seed_value = Save.daily_seed() if is_daily else Save.next_seed
	boon_rng.seed = seed_value * 7919 + 13
	weapon_id = Save.equipped
	weapon = GameData.WEAPONS[weapon_id]

	sfx = Sfx.new()
	sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sfx)

	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)

	controls = TouchControls.new()
	add_child(controls)

	player = Player.new()
	player.controls = controls
	player.main = self
	player.max_hp = 50 + 10 * Save.perma_level("vida")
	player.hp = player.max_hp
	world.add_child(player)

	camera = GameCamera.new()
	player.add_child(camera)
	_build_lighting()

	_moons_node = Node2D.new()
	_moons_node.z_index = 45
	_moons_node.material = Art.unshaded()
	_moons_node.draw.connect(_draw_moons)
	add_child(_moons_node)

	hud = Hud.new()
	add_child(hud)
	hud.set_seed(seed_value, is_daily)
	hud.set_hp(player.hp, player.max_hp)
	hud.set_level(level, xp, xp_to_next())
	hud.set_coins(0)
	player.hp_changed.connect(hud.set_hp)
	player.died.connect(_on_player_died)
	hud.retry_pressed.connect(_retry)
	hud.menu_pressed.connect(_to_menu)
	hud.pause_pressed.connect(_open_pause)
	hud.powers_pressed.connect(_open_powers)

	_enter_room("")


func _build_lighting() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	_ambient = CanvasModulate.new()
	add_child(_ambient)

	var torch := Art.make_light(Color(1.0, 0.84, 0.66), 1.5, 240.0, not Save.low_fx)
	env.glow_enabled = not Save.low_fx
	torch.position = Vector2(0, -12)
	player.add_child(torch)

	var atmo_layer := CanvasLayer.new()
	atmo_layer.layer = 3
	var atmo_rect := ColorRect.new()
	atmo_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	atmo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atmo = ShaderMaterial.new()
	_atmo.shader = preload("res://shaders/atmosphere.gdshader")
	atmo_rect.material = _atmo
	atmo_layer.add_child(atmo_rect)
	add_child(atmo_layer)

	_motes = CPUParticles2D.new()
	_motes.material = Art.additive()
	_motes.amount = 12 if Save.low_fx else 36
	_motes.lifetime = 7.0
	_motes.preprocess = 7.0
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.emission_rect_extents = Vector2(220, 420)
	_motes.direction = Vector2.UP
	_motes.spread = 60.0
	_motes.gravity = Vector2(0, -4)
	_motes.initial_velocity_min = 3.0
	_motes.initial_velocity_max = 10.0
	_motes.scale_amount_min = 0.6
	_motes.scale_amount_max = 1.5
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_motes.color_ramp = ramp
	_motes.z_index = 60
	camera.add_child(_motes)

	_guide = Node2D.new()
	_guide.material = Art.unshaded()
	_guide.z_index = 70
	_guide.draw.connect(_draw_guide)
	player.add_child(_guide)


func _apply_biome_look() -> void:
	var b := biome()
	_ambient.color = b["ambient"]
	_atmo.set_shader_parameter("fog_color", b["fog"])
	_atmo.set_shader_parameter("fog_amount", 0.12)
	_atmo.set_shader_parameter("vignette", 0.55)
	_motes.color = Art.hdr(b["torch"], 1.6)


func boon(id: String) -> float:
	return float(boons.get(id, 0.0))


func picked(id: String) -> int:
	return int(picks.get(id, 0))


func has_duo(id: String) -> bool:
	return picks.has(id)


func damage_mult() -> float:
	return (1.0 + 0.2 * boon("ares")) * (1.0 + 0.1 * Save.perma_level("forca"))


func attack_interval() -> float:
	var speed := 1.0 + 0.15 * boon("apolo")
	if _frenzy_t > 0.0:
		speed *= 1.6
	return float(weapon["interval"]) / speed


func move_speed_mult() -> float:
	return 1.0 + 0.12 * boon("hermes")


func dash_cd_mult() -> float:
	return 1.0 / (1.0 + 0.12 * boon("hermes"))


func crit_chance() -> float:
	return 0.05 + 0.1 * boon("artemis") + 0.03 * boon("tique")


func crit_mult() -> float:
	return 3.0 if has_duo("golpe_mortal") else 2.0


func pickup_radius() -> float:
	return BASE_PICKUP_RADIUS * (1.0 + 0.4 * boon("demeter"))


func xp_to_next() -> int:
	return 5 + (level - 1) * 4


func biome() -> Dictionary:
	return GameData.BIOMES[biome_index]


func _hp_mult() -> float:
	return (1.0 + 0.18 * room_index) * pow(1.5, cycle)


func _dmg_mult() -> float:
	return (1.0 + 0.05 * room_index) * pow(1.25, cycle)


func _is_boss_room() -> bool:
	return room_index % GameData.ROOMS_PER_BIOME == GameData.ROOMS_PER_BIOME - 1


func _physics_process(delta: float) -> void:
	if is_game_over:
		return
	elapsed += delta
	_frenzy_t -= delta
	if combo > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo = 0
			hud.set_combo(0)
	hud.set_dash(player.dash_charges, player.max_dash_charges, player.recharge_ratio())
	if boss and is_instance_valid(boss):
		hud.set_boss_hp(float(boss.hp) / boss.max_hp)

	_update_moons(delta)
	_guide_t += delta
	_guide.queue_redraw()
	_update_hazards(delta)

	if _room_state == "fight" and _pending_spawns == 0 and get_tree().get_nodes_in_group("enemies").is_empty():
		if wave_in_room < waves_total:
			_room_state = "between"
			var token := _room_token
			await get_tree().create_timer(0.9, false).timeout
			if not is_game_over and token == _room_token:
				_room_state = "fight"
				_next_wave()
		else:
			_on_room_cleared()


func _update_hazards(delta: float) -> void:
	if room.hazards.is_empty():
		return
	_hazard_tick -= delta
	if _hazard_tick > 0.0:
		return
	_hazard_tick = 0.5
	if room.hazard_at(player.position) and player.can_be_hit():
		player.take_damage(4 + room_index / 3, player.position + Vector2(0, 1))
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.hp > 0 and not e.is_spawning() and room.hazard_at(e.position):
			status_damage(e, 2, biome()["hazard"])


func _enter_room(reward: String) -> void:
	_room_state = "intro"
	_room_token += 1
	var token := _room_token
	_pending_spawns = 0
	if room:
		room.queue_free()
	for n in world.get_children():
		if n != player:
			n.queue_free()
	boss = null
	_moon_hits.clear()
	biome_index = (room_index / GameData.ROOMS_PER_BIOME) % GameData.BIOMES.size()
	cycle = room_index / (GameData.ROOMS_PER_BIOME * GameData.BIOMES.size())
	var boss_room := _is_boss_room()

	_room_rng.seed = hash([seed_value, room_index])
	room = Room.new()
	room.z_index = -10
	room.generate(_room_rng, biome(), boss_room)
	room.player = player
	room.door_entered.connect(_on_door_entered)
	add_child(room)
	room.build_props(world)
	_apply_biome_look()
	Music.play("boss" if _is_boss_room() else ["tartaro", "asfodelo", "elisio"][biome_index])

	player.position = room.player_spawn()
	player.velocity = Vector2.ZERO
	camera.limit_right = int(room.size.x)
	camera.limit_bottom = int(room.size.y)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.reset_smoothing()

	var num := room_index % GameData.ROOMS_PER_BIOME + 1
	hud.set_room(biome()["name"], num, 0, 0, cycle)
	hud.fade(0.0, 0.35)

	_room_reward = reward
	_try_open_panel()

	if boss_room:
		waves_total = 0
		wave_in_room = 0
		_start_boss()
	else:
		waves_total = 2 + (1 if num >= 3 else 0) + mini(cycle, 2)
		wave_in_room = 0
		hud.show_banner("%s  -  SALA %d" % [biome()["name"], num])
		_pending_spawns += 1
		await get_tree().create_timer(1.0, false).timeout
		if token != _room_token:
			return
		_pending_spawns -= 1
		if not is_game_over:
			_room_state = "fight"
			_next_wave()


func _next_wave() -> void:
	wave_in_room += 1
	hud.set_room(biome()["name"], room_index % GameData.ROOMS_PER_BIOME + 1, wave_in_room, waves_total, cycle)
	if wave_in_room > 1:
		hud.show_banner("ONDA %d/%d" % [wave_in_room, waves_total])
	var count := mini(4 + room_index + wave_in_room * 2, 24)
	var kinds: Array = biome()["enemies"]
	var elite_chance := minf(0.02 + 0.025 * room_index, 0.3)
	_pending_spawns += count
	for i in count:
		var kind: Enemy.Kind = kinds[_room_rng.randi() % kinds.size()]
		var elite := _room_rng.randf() < elite_chance
		var pos := player.position + Vector2.from_angle(_room_rng.randf_range(0.0, TAU)) * _room_rng.randf_range(MIN_SPAWN_DIST, MIN_SPAWN_DIST + 130.0)
		_telegraph_spawn(_free_spot(pos), kind, elite, 0.5 + i * 0.08)


func _free_spot(pos: Vector2) -> Vector2:
	var lo := Vector2(Room.WALL + 12, Room.WALL + 12)
	var p := pos.clamp(lo, room.size - lo)
	var center := room.size / 2
	var guard := 0
	while room.blocked(p) and guard < 40:
		p = p.move_toward(center, 6.0)
		guard += 1
	return p


func _telegraph_spawn(pos: Vector2, kind: Enemy.Kind, elite: bool, delay: float) -> void:
	var token := _room_token
	var marker := Node2D.new()
	marker.position = pos
	marker.z_index = -1
	marker.material = Art.unshaded()
	var c := Color(1, 0.84, 0.3) if elite else Color(1, 0.25, 0.25)
	marker.draw.connect(func():
		marker.draw_arc(Vector2.ZERO, 9, 0, TAU, 16, Color(c, 0.8), 1.0)
		marker.draw_circle(Vector2.ZERO, 5, Color(c, 0.25)))
	world.add_child(marker)
	marker.scale = Vector2(2.2, 2.2)
	marker.create_tween().tween_property(marker, "scale", Vector2(0.6, 0.6), delay)
	await get_tree().create_timer(delay, false).timeout
	if token != _room_token or not is_instance_valid(marker):
		return
	marker.queue_free()
	_pending_spawns -= 1
	if is_game_over:
		return
	sfx.play("spawn", randf_range(0.9, 1.15))
	spawn_enemy(kind, pos, elite)


func spawn_enemy(kind: Enemy.Kind, pos: Vector2, elite := false) -> Enemy:
	var e := Enemy.new()
	e.setup(kind, player, self, _hp_mult(), _dmg_mult(), elite)
	e.position = pos
	world.add_child(e)
	return e


func spawn_minion(kind: Enemy.Kind, pos: Vector2) -> void:
	spawn_enemy(kind, _free_spot(pos))


func _on_room_cleared() -> void:
	_room_state = "cleared"
	var bonus := 3 + room_index
	run_coins += bonus
	score += 50 * (room_index + 1)
	hud.set_coins(run_coins)
	hud.set_score(score)
	sfx.play("wave")
	for p in get_tree().get_nodes_in_group("pickups"):
		p.attract()
	var reward := _room_reward
	_room_reward = ""
	if reward == "boon" or reward == "boon_epic":
		hud.show_banner("SALA LIMPA!  UMA BÊNÇÃO AGUARDA")
		_spawn_boon_orb(reward)
		return
	if reward != "":
		_grant_reward(reward)
	hud.show_banner("SALA LIMPA! SUBA ATÉ AS PORTAS")
	_open_exits()


func _open_exits() -> void:
	sfx.play("doors")
	room.open_doors(_roll_door_rewards())
	if (room_index + 1) % GameData.ROOMS_PER_BIOME == GameData.ROOMS_PER_BIOME - 1:
		await get_tree().create_timer(1.4, false).timeout
		if _room_state == "cleared":
			hud.show_banner("CHEFE À FRENTE!")


func _roll_door_rewards() -> Array:
	if _is_boss_room():
		return ["boon_epic", "maxhp"]
	var door_rng := RandomNumberGenerator.new()
	door_rng.seed = hash([seed_value, room_index, "doors"])
	var pool: Array = []
	for id in GameData.REWARDS:
		if int(GameData.REWARDS[id]["weight"]) > 0:
			pool.append(id)
	var out: Array = []
	while out.size() < 2:
		var total := 0
		for id in pool:
			total += int(GameData.REWARDS[id]["weight"])
		var roll := door_rng.randi_range(1, total)
		for id in pool:
			roll -= int(GameData.REWARDS[id]["weight"])
			if roll <= 0:
				out.append(id)
				pool.erase(id)
				break
	return out


func _on_door_entered(reward: String) -> void:
	_room_state = "transition"
	controls.reset()
	sfx.play("dash", 0.7)
	for p in get_tree().get_nodes_in_group("pickups"):
		collect(p, true)
		p.queue_free()
	await hud.fade(1.0, 0.25).finished
	room_index += 1
	if room_index % (GameData.ROOMS_PER_BIOME * GameData.BIOMES.size()) == 0:
		_queue_message("CICLO %d" % (room_index / (GameData.ROOMS_PER_BIOME * GameData.BIOMES.size()) + 1))
	_enter_room(reward)


func _queue_message(text: String) -> void:
	await get_tree().create_timer(0.6, false).timeout
	hud.show_banner(text)


func _grant_reward(reward: String) -> void:
	match reward:
		"boon":
			_panel_queue.append({"title": "BÊNÇÃO DOS DEUSES", "min_tier": 0})
		"boon_epic":
			_panel_queue.append({"title": "DÁDIVA DO OLIMPO", "min_tier": 2})
		"coins":
			var c := 12 + room_index * 2
			run_coins += c
			hud.set_coins(run_coins)
			_queue_message("+%d ÓBOLOS" % c)
			sfx.play("coin")
		"heal":
			var h := ceili(player.max_hp * 0.4)
			player.heal(h)
			sfx.play("heal")
			_queue_message("AMBROSIA  +%d VIDA" % h)
		"maxhp":
			player.max_hp += 10
			player.heal(10)
			sfx.play("heal", 0.9)
			_queue_message("+10 VIDA MÁXIMA")
		"forge":
			forge += 1
			_queue_message("ARMA FORJADA!  +1 DANO")
			sfx.play("buy")


func _start_boss() -> void:
	var id: String = biome()["boss"]
	var info: Dictionary = GameData.BOSSES[id]
	var token := _room_token
	_pending_spawns += 1
	hud.show_boss_intro(info["name"], info["title"])
	sfx.play("boss_intro")
	await get_tree().create_timer(1.8, false).timeout
	if is_game_over or token != _room_token:
		return
	boss = Boss.new()
	boss.setup_boss(id, player, self, 1.0 + 0.6 * cycle, _dmg_mult())
	boss.position = Vector2(room.size.x / 2, room.size.y * 0.3)
	world.add_child(boss)
	camera.add_trauma(0.5)
	haptic(60)
	hud.show_boss_bar(info["name"])
	_pending_spawns -= 1
	_room_state = "fight"


func on_boss_phase(b: Boss) -> void:
	hud.show_banner("FÚRIA!")
	camera.add_trauma(0.7)
	hitstop(0.15)
	haptic(50)
	sfx.play("boss_phase")
	spawn_burst(b.position + Vector2(0, -10), Color("ff3b3b"), 30)


func _on_boss_killed(b: Boss) -> void:
	bosses_killed += 1
	kills += 1
	score += 500 * (biome_index + 1) * (cycle + 1)
	hud.set_score(score)
	hud.hide_boss_bar()
	hud.show_banner("%s DERROTADO!" % b.data["name"])
	for n in world.get_children():
		if n is EnemyBullet:
			n.queue_free()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != b and e.hp > 0:
			e.take_hit(e.hp, Vector2.ZERO, false, true)
	for i in 3:
		spawn_burst(b.position + Vector2(randf_range(-12, 12), randf_range(-24, 0)), b.color, 30)
	for i in 8:
		_drop(Pickup.Type.XP, b.position, 3)
	for i in 10 + 4 * biome_index:
		_drop(Pickup.Type.COIN, b.position, 1)
	camera.add_trauma(1.0)
	hitstop(0.3)
	haptic(120)
	sfx.play("boss_death")
	boss = null
	_boss_slowmo()


func fire_weapon(target: Node2D) -> void:
	var from := player.position + Vector2(0, -5)
	var dir := (target.position + Vector2(0, -4) - from).normalized()
	var extra := picked("hefesto")
	var dmg := int(weapon["damage"]) + forge
	var color: Color = weapon["color"]
	match weapon_id:
		"lanca":
			_fan(from, dir, 1 + extra, 0.1, dmg, 330.0, 0, color)
		"arco":
			_fan(from, dir, 3 + extra, 0.14, dmg, 430.0, 1, color)
		"espada":
			_slash(dir, deg_to_rad(110 + 40 * extra), 48.0, dmg, color)
		"cetro":
			_lightning(target, 2 + extra, dmg, color)
	sfx.play(weapon["sound"], randf_range(0.95, 1.08))


func _fan(from: Vector2, dir: Vector2, count: int, step: float, dmg: int, speed: float, pierce: int, color: Color) -> void:
	for i in count:
		var p := Projectile.new()
		p.game = self
		var k := (i + 1) / 2
		p.dir = dir.rotated(step * k * (1.0 if i % 2 == 1 else -1.0))
		p.position = from + p.dir * 6
		p.damage = dmg
		p.speed = speed
		p.pierce = pierce
		p.bounces = picked("iris")
		p.color = color
		world.add_child(p)


func line_clear(a: Vector2, b: Vector2) -> bool:
	var steps := int(a.distance_to(b) / 6.0)
	for i in range(1, steps):
		if room.blocked(a.lerp(b, float(i) / steps)):
			return false
	return true


func _slash(dir: Vector2, arc: float, radius: float, dmg: int, color: Color) -> void:
	var center := player.position + Vector2(0, -5)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_spawning() or e.hp <= 0:
			continue
		var to: Vector2 = e.position + Vector2(0, -4) - center
		var reach: float = radius + 6.0 + e.body_radius
		if to.length() <= reach and absf(dir.angle_to(to)) <= arc / 2.0:
			damage_enemy(e, dmg, to.normalized())
	var fx := Node2D.new()
	fx.position = center
	fx.z_index = 40
	fx.material = Art.unshaded()
	var a0 := dir.angle() - arc / 2.0
	fx.draw.connect(func():
		fx.draw_arc(Vector2.ZERO, radius - 8.0, a0, a0 + arc, 24, Art.hdr(Color(color, 0.7), 1.5), 8.0, true)
		fx.draw_arc(Vector2.ZERO, radius - 3.0, a0, a0 + arc, 24, Art.hdr(Color.WHITE, 2.2), 2.0, true))
	add_child(fx)
	var t := fx.create_tween()
	t.tween_property(fx, "modulate:a", 0.0, 0.16)
	t.tween_callback(fx.queue_free)


func _lightning(first: Node2D, jumps: int, dmg: int, color: Color) -> void:
	var points: Array = [player.position + Vector2(0, -6)]
	var hit: Array = []
	var current: Node2D = first
	for i in jumps + 1:
		if current == null:
			break
		hit.append(current)
		var pos := current.position
		points.append(pos + Vector2(0, -5))
		damage_enemy(current, dmg, (pos - player.position).normalized(), false)
		current = nearest_enemy(pos, 85.0, hit)
	_bolt_fx(points, color)


func nearest_enemy(pos: Vector2, max_dist: float, exclude: Array) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist
	for e in get_tree().get_nodes_in_group("enemies"):
		if e in exclude or e.is_spawning() or e.hp <= 0:
			continue
		var d := pos.distance_to(e.position)
		if d < best_d:
			best_d = d
			best = e
	return best


func damage_enemy(e: Node2D, base: int, dir: Vector2, can_chain := true) -> void:
	if e.hp <= 0:
		return
	var dmg := float(base) * damage_mult()
	var crit := randf() < crit_chance()
	if crit:
		dmg *= crit_mult()
	var pos := e.position
	if boon("hestia") > 0.0:
		e.apply_burn(boon("hestia"))
	if boon("boreas") > 0.0:
		e.apply_slow(minf(0.15 * boon("boreas"), 0.6), 2.0)
	e.take_hit(maxi(1, roundi(dmg)), dir, crit)
	if can_chain and boon("zeus") > 0.0 and randf() < 0.15 * boon("zeus"):
		var other := nearest_enemy(pos, 90.0, [e])
		if other:
			damage_enemy(other, 2 + forge, (other.position - pos).normalized(), false)
			_bolt_fx([pos + Vector2(0, -5), other.position + Vector2(0, -5)], Color("7fd4ff"))
			sfx.play("zap", 1.3)


func status_damage(e: Node2D, amount: int, color: Color) -> void:
	if e.hp <= 0:
		return
	e.take_hit(amount, Vector2.ZERO, false, true)
	if is_instance_valid(e):
		spawn_damage_number(e.position, amount, false, color)


func explode(pos: Vector2, radius: float, dmg: int, color: Color, hurts_player: bool) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_spawning() and e.hp > 0 and pos.distance_to(e.position) < radius + e.body_radius:
			damage_enemy(e, dmg, (e.position - pos).normalized(), false)
	if hurts_player and player.can_be_hit() and pos.distance_to(player.position) < radius:
		player.take_damage(dmg, pos)
	var ring := Node2D.new()
	ring.position = pos
	ring.z_index = 30
	ring.material = Art.unshaded()
	ring.draw.connect(func():
		ring.draw_circle(Vector2.ZERO, radius, Art.hdr(Color(color, 0.3), 1.4))
		ring.draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Art.hdr(color, 2.0), 2.0, true))
	add_child(ring)
	ring.scale = Vector2(0.3, 0.3)
	var t := ring.create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "modulate:a", 0.0, 0.3)
	t.chain().tween_callback(ring.queue_free)
	spawn_burst(pos, color, 10)
	camera.add_trauma(0.2)
	sfx.play("explode", randf_range(0.9, 1.1))


func spawn_meteor(pos: Vector2, dmg: int, delay: float) -> void:
	var p := _free_spot(pos)
	var marker := Node2D.new()
	marker.position = p
	marker.z_index = -1
	marker.material = Art.unshaded()
	marker.draw.connect(func():
		marker.draw_circle(Vector2.ZERO, 22, Color(1, 0.55, 0.2, 0.2))
		marker.draw_arc(Vector2.ZERO, 22, 0, TAU, 24, Color(1, 0.55, 0.2, 0.9), 1.0))
	world.add_child(marker)
	sfx.play("meteor", randf_range(0.92, 1.08))
	marker.scale = Vector2(0.2, 0.2)
	marker.create_tween().tween_property(marker, "scale", Vector2.ONE, delay)
	await get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(marker) or is_game_over:
		return
	marker.queue_free()
	explode(p, 22.0, dmg, Color("ff8c3a"), true)


func spawn_enemy_bullet(pos: Vector2, vel: Vector2, dmg: int, color: Color, petrify := false) -> void:
	var b := EnemyBullet.new()
	b.game = self
	b.position = pos
	b.vel = vel
	b.damage = dmg
	b.color = color
	b.petrify = petrify
	world.add_child(b)


func on_dash_end(pos: Vector2) -> void:
	var power := boon("poseidon")
	if power <= 0.0:
		return
	var radius := 40.0 + 4.0 * power
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_spawning() and e.hp > 0 and pos.distance_to(e.position) < radius:
			damage_enemy(e, roundi(3 * power), (e.position - pos).normalized(), false)
	if has_duo("tempestade"):
		var hit: Array = []
		for i in 3:
			var e := nearest_enemy(pos, 130.0, hit)
			if e == null:
				break
			hit.append(e)
			damage_enemy(e, 3 + forge, (e.position - pos).normalized(), false)
			_bolt_fx([pos + Vector2(0, -6), e.position + Vector2(0, -5)], Color("7fd4ff"))
	var ring := Node2D.new()
	ring.position = pos
	ring.z_index = 30
	ring.material = Art.unshaded()
	ring.draw.connect(func(): ring.draw_arc(Vector2.ZERO, 10.0, 0, TAU, 32, Art.hdr(Color("34ace0"), 2.0), 1.5, true))
	add_child(ring)
	var t := ring.create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector2.ONE * radius / 10.0, 0.22).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "modulate:a", 0.0, 0.22)
	t.chain().tween_callback(ring.queue_free)
	camera.add_trauma(0.15)


func _update_moons(delta: float) -> void:
	var n := picked("selene")
	for k in _moon_hits.keys():
		_moon_hits[k] -= delta
		if _moon_hits[k] <= 0.0:
			_moon_hits.erase(k)
	if n == 0:
		return
	var eclipse := has_duo("eclipse")
	_moon_angle += delta * (6.0 if eclipse else 3.0)
	var hit_r := 11.0 if eclipse else 8.0
	for pos in _moon_positions():
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.hp <= 0 or e.is_spawning() or _moon_hits.has(e.get_instance_id()):
				continue
			if pos.distance_to(e.position + Vector2(0, -4)) < hit_r + e.body_radius:
				_moon_hits[e.get_instance_id()] = 0.5
				damage_enemy(e, (4 if eclipse else 2) + forge, (e.position - player.position).normalized(), false)
	_moons_node.queue_redraw()


func _moon_positions() -> Array:
	var out: Array = []
	var n := picked("selene")
	var r := 36.0 if has_duo("eclipse") else 30.0
	for i in n:
		out.append(player.position + Vector2(0, -5) + Vector2.from_angle(_moon_angle + TAU * i / n) * r)
	return out


func _draw_moons() -> void:
	var big := has_duo("eclipse")
	for pos in _moon_positions():
		Art.glow(_moons_node, pos, 12.0 if big else 9.0, Color("c8d4ff"), 0.9)
		_moons_node.draw_circle(pos, 3.0 if big else 2.5, Art.hdr(Color("e0e6ff"), 2.0))


func on_enemy_hit(enemy: Enemy, amount: int, crit: bool, status: bool) -> void:
	if status:
		return
	spawn_damage_number(enemy.position, amount, crit)
	camera.add_trauma(0.12 if crit else 0.07)
	if crit:
		sfx.play("crit", randf_range(0.95, 1.05))
	else:
		sfx.play("hit", randf_range(0.9, 1.1))


func on_enemy_killed(enemy: Enemy, by_player := true) -> void:
	if enemy is Boss:
		_on_boss_killed(enemy)
		return
	combo += 1
	best_combo = maxi(best_combo, combo)
	_combo_timer = 2.0
	score += 10 * (1 + combo / 5) * enemy.score_mult
	kills += 1
	hud.set_score(score)
	hud.set_combo(combo)

	var pos := enemy.position
	_drop(Pickup.Type.XP, pos, enemy.xp_value)
	var coins := randi_range(2, 4) if enemy.elite else (1 if randf() < 0.2 else 0)
	if enemy.kind == Enemy.Kind.BRUTE:
		coins += 1
	for i in coins:
		_drop(Pickup.Type.COIN, pos, 1)

	if by_player and enemy.kind == Enemy.Kind.BOMBER:
		explode.call_deferred(pos, 34.0, 4 + forge, Color("ff9f43"), false)
	if boon("hecate") > 0.0:
		explode.call_deferred(pos, 30.0, roundi(3 * boon("hecate")), Color("b06cff"), false)
	if boon("dionisio") > 0.0:
		_heal_acc += 0.5 * boon("dionisio")
		if _heal_acc >= 1.0:
			player.heal(int(_heal_acc))
			_heal_acc -= int(_heal_acc)

	spawn_burst(pos + Vector2(0, -5), enemy.color, 16 if enemy.elite else 12)
	camera.add_trauma(0.3 if enemy.elite else 0.18)
	hitstop(0.08 if enemy.elite else 0.04)
	haptic(20 if enemy.elite else 10)
	sfx.play("kill", 1.0 + minf(combo, 24) * 0.04)


func on_player_hurt() -> void:
	combo = 0
	hud.set_combo(0)
	camera.add_trauma(0.55)
	hitstop(0.09)
	haptic(45)
	sfx.play("hurt")
	if boon("nemesis") > 0.0:
		explode.call_deferred(player.position, 50.0, roundi(8 * boon("nemesis")), Color("c0392b"), false)


func on_footstep(pos: Vector2) -> void:
	sfx.play("step", randf_range(0.85, 1.15))
	if Save.low_fx:
		return
	var puff := Node2D.new()
	puff.position = pos + Vector2(0, 1)
	puff.z_index = -1
	var tint: Color = biome()["floor_a"].lightened(0.35)
	puff.draw.connect(func():
		puff.draw_set_transform(Vector2.ZERO, 0, Vector2(1.0, 0.5))
		puff.draw_circle(Vector2(-2, 0), 3.0, Color(tint, 0.45))
		puff.draw_circle(Vector2(2, -1), 2.2, Color(tint, 0.35)))
	world.add_child(puff)
	var t := puff.create_tween().set_parallel(true)
	t.tween_property(puff, "scale", Vector2(2.2, 2.2), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(puff, "modulate:a", 0.0, 0.35)
	t.chain().tween_callback(puff.queue_free)


func on_player_dash() -> void:
	sfx.play("dash", randf_range(0.95, 1.1))
	haptic(8)
	if has_duo("frenesi"):
		_frenzy_t = 2.0


func _drop(type: Pickup.Type, pos: Vector2, value: int) -> void:
	var p := Pickup.new()
	p.type = type
	p.value = value
	p.game = self
	p.position = pos
	world.add_child.call_deferred(p)


func collect(p: Pickup, quiet := false) -> void:
	if p.type == Pickup.Type.COIN:
		var gain := p.value
		if randf() < 0.3 * boon("tique"):
			gain += 1
		run_coins += gain
		hud.set_coins(run_coins)
		if not quiet:
			sfx.play("coin", randf_range(0.95, 1.1))
		return
	xp += p.value * (1.0 + 0.2 * boon("demeter"))
	if has_duo("fartura"):
		player.heal(1)
	if not quiet:
		sfx.play("xp", 1.0 + minf(xp / xp_to_next(), 1.0) * 0.6)
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		_panel_queue.append({"title": "NÍVEL %d!" % level, "min_tier": 0})
	hud.set_level(level, xp, xp_to_next())
	if not quiet:
		_try_open_panel()


func _try_open_panel() -> void:
	if _choosing or _panel_queue.is_empty() or is_game_over:
		return
	var req: Dictionary = _panel_queue.pop_front()
	_current_req = req
	_choosing = true
	get_tree().paused = true
	Music.duck(true)
	controls.reset()
	hud.hide_banner()
	haptic(30)
	var offers: Array = req["offers"] if req.has("offers") else _roll_offers(int(req["min_tier"]))
	var panel := LevelUpPanel.new()
	panel.title = req["title"]
	panel.offers = offers
	panel.god = req.get("god", featured_god(offers))
	var now := Time.get_ticks_msec()
	panel.voiced = req.get("orb", false) or (now - _last_voice_ms > 25000 and randf() < 0.5)
	if panel.voiced:
		_last_voice_ms = now
	panel.picks = picks
	panel.totals = boons
	panel.chosen.connect(_on_boon_chosen)
	add_child(panel)


func _roll_offers(min_tier: int) -> Array:
	var pool: Array = []
	for b in GameData.BOONS:
		if picked(b["id"]) >= int(b["max"]):
			continue
		if b.has("weapons") and not weapon_id in b["weapons"]:
			continue
		pool.append(b)
	var duos: Array = []
	for d in GameData.DUOS:
		if not has_duo(d["id"]) and boon(d["gods"][0]) > 0.0 and boon(d["gods"][1]) > 0.0:
			duos.append(d)
	var offers: Array = []
	if not duos.is_empty() and boon_rng.randf() < 0.4:
		offers.append(_make_offer(duos[boon_rng.randi() % duos.size()], -1, true))
	while offers.size() < 3 and not pool.is_empty():
		var b: Dictionary = pool.pop_at(boon_rng.randi_range(0, pool.size() - 1))
		offers.append(_make_offer(b, _roll_tier(min_tier), false))
	if offers.is_empty():
		offers.append(_make_offer(GameData.AMBROSIA, -1, false))
	return offers


func _roll_tier(min_tier: int) -> int:
	var total := 0
	for i in range(min_tier, GameData.RARITIES.size()):
		total += int(GameData.RARITIES[i]["weight"])
	var roll := boon_rng.randi_range(1, total)
	for i in range(min_tier, GameData.RARITIES.size()):
		roll -= int(GameData.RARITIES[i]["weight"])
		if roll <= 0:
			return i
	return min_tier


func _make_offer(b: Dictionary, tier: int, duo: bool) -> Dictionary:
	var o := b.duplicate()
	o["duo"] = duo
	if duo:
		o["color"] = GameData.DUO_COLOR
	var flat: bool = duo or b.get("flat", false)
	o["tier"] = -1 if flat else tier
	o["mult"] = 1.0 if flat else float(GameData.RARITIES[tier]["mult"])
	if b.has("per"):
		var v := float(b["per"]) * float(o["mult"])
		o["desc"] = String(b["desc"]).replace("{v}", str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v)
	return o


func _on_boon_chosen(offer: Dictionary) -> void:
	var id: String = offer["id"]
	match id:
		"ambrosia":
			player.heal(20)
		"atena":
			var gain := roundi(15 * float(offer["mult"]))
			player.max_hp += gain
			player.heal(gain)
	if id != "ambrosia":
		boons[id] = boon(id) + float(offer["mult"])
		picks[id] = picked(id) + 1
	if id == "eolo":
		player.max_dash_charges = 1 + picked("eolo")
		player.dash_charges = player.max_dash_charges
	hud.set_boons(picks)
	_choosing = false
	get_tree().paused = false
	Music.duck(false)
	if _current_req.get("orb", false):
		_open_exits()
	_current_req = {}
	_try_open_panel()


func featured_god(offers: Array) -> String:
	if offers.is_empty():
		return "olimpo"
	var o: Dictionary = offers[0]
	if o.get("duo", false):
		return o["gods"][0]
	return o["id"] if GameData.GODS.has(o["id"]) else "olimpo"


func _spawn_boon_orb(reward: String) -> void:
	var min_tier := 2 if reward == "boon_epic" else 0
	var offers := _roll_offers(min_tier)
	var god := featured_god(offers)
	var orb := BoonOrb.new()
	orb.god = god
	orb.color = offers[0]["color"]
	orb.player = player
	orb.position = _free_spot(player.position + Vector2(0, -70))
	world.add_child(orb)
	sfx.play("boon_appear")
	orb.taken.connect(func():
		_panel_queue.push_front({"title": "DÁDIVA DO OLIMPO" if min_tier > 0 else "", "offers": offers, "god": god, "orb": true})
		_try_open_panel())


func _on_player_died() -> void:
	is_game_over = true
	sfx.play("death")
	Music.stop(2.0)
	spawn_burst(player.position + Vector2(0, -5), Player.COLOR_CLOAK, 24)
	camera.add_trauma(0.8)
	var earned := _bank_run()
	var record := Save.record_score(seed_value, score)
	Save.save_data()
	Engine.time_scale = 0.35
	hud.hide_boss_bar()
	hud.show_game_over({
		"score": score, "room": room_index + 1, "biome": biome()["name"], "level": level,
		"combo": best_combo, "seconds": elapsed, "coins": earned, "record": record,
	})
	await get_tree().create_timer(0.9, true, false, true).timeout
	Engine.time_scale = 1.0


func _bank_run() -> int:
	var earned := roundi(run_coins * (1.0 + 0.25 * Save.perma_level("fortuna")))
	Save.coins += earned
	Save.record_run(room_index + 1, kills, bosses_killed)
	return earned


func _open_pause() -> void:
	if is_game_over or _pause_sheet or _choosing:
		return
	get_tree().paused = true
	Music.duck(true)
	controls.reset()
	Music.ui("open")
	var quit := UI.button("Abandonar run", Color("ff5e57"), 11)
	var armed := [false]
	quit.pressed.connect(func():
		if not armed[0]:
			armed[0] = true
			quit.text = "Toque de novo para abandonar"
			return
		get_tree().paused = false
		_bank_run()
		Save.record_score(seed_value, score)
		Save.save_data()
		_to_menu())
	_pause_sheet = SettingsSheet.build(_close_pause, "PAUSADO", [quit])
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(_pause_sheet)
	add_child(layer)


func _open_powers() -> void:
	if is_game_over or _pause_sheet or _choosing:
		return
	get_tree().paused = true
	Music.duck(true)
	controls.reset()
	Music.ui("open")
	_pause_sheet = PowersSheet.build(self, _close_pause)
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(_pause_sheet)
	add_child(layer)


func _close_pause() -> void:
	if _pause_sheet:
		_pause_sheet.get_parent().queue_free()
		_pause_sheet = null
	get_tree().paused = false
	Music.duck(false)


func _notification(what: int) -> void:
	if OS.has_feature("mobile") and (what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED):
		_open_pause()


func _retry() -> void:
	Engine.time_scale = 1.0
	Music.duck(false)
	get_tree().reload_current_scene()


func _to_menu() -> void:
	Engine.time_scale = 1.0
	Music.duck(false)
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _boss_slowmo() -> void:
	await get_tree().create_timer(0.32, true, false, true).timeout
	if is_game_over:
		return
	Engine.time_scale = 0.3
	await get_tree().create_timer(1.1, true, false, true).timeout
	if not is_game_over:
		Engine.time_scale = 1.0


func hitstop(duration: float) -> void:
	_hitstop_count += 1
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	_hitstop_count -= 1
	if _hitstop_count == 0 and not is_game_over:
		Engine.time_scale = 1.0


func haptic(ms: int) -> void:
	if Save.haptics and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func spawn_afterimage(pos: Vector2, facing: Vector2, walk: float) -> void:
	if player.sprite:
		var s := Sprite2D.new()
		s.texture = player.sprite.current_texture()
		s.offset = player.sprite.offset
		s.scale = player.sprite.scale
		s.position = pos
		s.material = Art.additive()
		s.modulate = Color(0.4, 1.1, 1.6, 0.55)
		world.add_child(s)
		var st := s.create_tween()
		st.tween_property(s, "modulate:a", 0.0, 0.2)
		st.tween_callback(s.queue_free)
		return
	var ghost := Node2D.new()
	ghost.position = pos
	ghost.material = Art.additive()
	ghost.scale = Vector2(Player.HERO_SCALE, Player.HERO_SCALE)
	ghost.draw.connect(func(): Player.draw_figure(ghost, facing, Color(0.5, 1.4, 1.8), 0.45, walk))
	world.add_child(ghost)
	var t := ghost.create_tween()
	t.tween_property(ghost, "modulate:a", 0.0, 0.2)
	t.tween_callback(ghost.queue_free)


func _bolt_fx(points: Array, color: Color) -> void:
	var jag := PackedVector2Array()
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		jag.append(a)
		for k in range(1, 4):
			jag.append(a.lerp(b, k / 4.0) + Vector2(randf_range(-4, 4), randf_range(-4, 4)))
	jag.append(points[-1])
	var fx := Node2D.new()
	fx.z_index = 60
	fx.material = Art.unshaded()
	fx.draw.connect(func():
		fx.draw_polyline(jag, Art.hdr(color, 1.8), 3.0, true)
		fx.draw_polyline(jag, Art.hdr(Color.WHITE, 3.0), 1.0, true))
	add_child(fx)
	var t := fx.create_tween()
	t.tween_property(fx, "modulate:a", 0.0, 0.18)
	t.tween_callback(fx.queue_free)


func spawn_burst(pos: Vector2, color: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 50
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.5
	p.spread = 180.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 150.0
	p.gravity = Vector2.ZERO
	p.damping_min = 150.0
	p.damping_max = 250.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	p.color = Art.hdr(color.lightened(0.25), 1.8)
	p.material = Art.additive()
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	p.emitting = true
	add_child(p)
	get_tree().create_timer(1.0, false).timeout.connect(p.queue_free)


func spawn_damage_number(pos: Vector2, amount: int, crit := false, color := Color("fff2a8")) -> void:
	var l := Label.new()
	l.material = Art.unshaded()
	l.text = str(amount) + ("!" if crit else "")
	l.z_index = 100
	l.add_theme_font_size_override("font_size", 15 if crit else 8)
	if crit:
		l.add_theme_font_override("font", UI.title_font())
	l.add_theme_color_override("font_color", Color("ff9f1a") if crit else color)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.position = pos + Vector2(randf_range(-8, 2), -26)
	add_child(l)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 12, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.2).set_delay(0.3)
	t.chain().tween_callback(l.queue_free)


func _draw_guide() -> void:
	if room == null or not room.doors_open or room._entered:
		return
	var best := Vector2.ZERO
	var best_d := INF
	for d in room.doors:
		var p := Vector2(d["x"], Room.WALL)
		var dist := p.distance_to(player.position)
		if dist < best_d:
			best_d = dist
			best = p
	if best_d < 60.0:
		return
	var dir := (best - player.position).normalized()
	var pulse := 0.6 + 0.4 * sin(_guide_t * 6.0)
	var base := Vector2(0, -8) + dir * (24.0 + 3.0 * sin(_guide_t * 6.0))
	var side := dir.orthogonal() * 5.0
	var tip := base + dir * 6.0
	_guide.draw_colored_polygon(PackedVector2Array([tip, base + side, base + dir * 2.0, base - side]), Art.hdr(UI.GOLD, 1.4 * pulse))

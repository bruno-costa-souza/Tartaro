class_name Boss
extends Enemy

var boss_id := "cerbero"
var data: Dictionary
var phase := 1
var bullet_damage := 8

var _steps: Array = []
var _si := -1
var _step: Dictionary = {}
var _st := 0.0
var _sub := 0.0
var _sc := 0
var _sstate := ""
var _aim := Vector2.DOWN
var _spin_a := 0.0
var _beam_hit := false
var _bounces := 0
var _alpha := 1.0


func setup_boss(id: String, player: Player, main_ref: Node, hp_mult: float, dmg_mult: float) -> void:
	boss_id = id
	data = GameData.BOSSES[id]
	target = player
	main = main_ref
	kind = Kind.BRUTE
	max_hp = ceili(data["hp"] * hp_mult)
	hp = max_hp
	damage = roundi(data["damage"] * dmg_mult)
	bullet_damage = roundi(damage * 0.7)
	color = data["color"]
	speed = data["speed"]
	body_radius = data["radius"]
	contact_radius = body_radius + 4.0
	knock_mult = 0.0
	score_mult = 50
	xp_value = 25
	_spawn_t = 1.2


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape.shape = circle
	add_child(shape)
	_make_fx()
	if CharSprite.available(boss_id):
		sprite = CharSprite.new()
		add_child(sprite)
		move_child(sprite, 0)
		sprite.setup(boss_id, {"cerbero": 60.0, "medusa": 64.0, "talos": 80.0}.get(boss_id, 60.0))


func _physics_process(delta: float) -> void:
	_t += delta
	_flash -= delta
	_update_boss_sprite()
	if _spawn_t > 0.0:
		_spawn_t -= delta
		queue_redraw()
		return
	_tick_status(delta)
	if hp <= 0 or target.is_dead:
		velocity = Vector2.ZERO
		queue_redraw()
		return
	if phase == 1 and hp * 2 <= max_hp:
		phase = 2
		_si = -1
		_step = {}
		main.on_boss_phase(self)
	if _step.is_empty():
		_next_step()

	velocity = _update_step(delta) * (1.0 - _slow * 0.5)
	move_and_slide()
	if _step.get("do", "") == "charge" and _sstate == "go" and get_slide_collision_count() > 0:
		_on_charge_wall(get_slide_collision(0).get_normal())

	if position.distance_to(target.position) < contact_radius and _alpha > 0.5:
		target.take_damage(damage, position)
	queue_redraw()


func _next_step() -> void:
	_steps = data["p2"] if phase == 2 else data["p1"]
	_si = (_si + 1) % _steps.size()
	_step = _steps[_si]
	_st = 0.0
	_sub = 0.0
	_sc = 0
	_sstate = "start"
	_bounces = 0


func _update_step(delta: float) -> Vector2:
	_st += delta
	_sub -= delta
	var s := _step
	var to_player := target.position - position
	match s["do"]:
		"wait":
			if _st >= float(s["t"]):
				_next_step()
			var d := to_player.length()
			if d > 140.0:
				return to_player.normalized() * speed
			if d < 80.0:
				return -to_player.normalized() * speed
			return to_player.orthogonal().normalized() * speed * 0.5
		"spread":
			if _sub <= 0.0:
				if _sc >= int(s["repeat"]):
					_next_step()
					return Vector2.ZERO
				_fire_spread(int(s["count"]), float(s["spread"]), float(s["speed"]), s.get("heads", false))
				_sc += 1
				_sub = float(s["gap"])
		"ring":
			if _sub <= 0.0:
				if _sc >= int(s["repeat"]):
					_next_step()
					return Vector2.ZERO
				_fire_ring(int(s["count"]), _sc * float(s.get("rot", 0.0)), int(s.get("gap_size", 0)), float(s["speed"]))
				_sc += 1
				_sub = float(s["gap"])
		"spiral":
			if _st >= float(s["t"]):
				_next_step()
				return Vector2.ZERO
			if _sub <= 0.0:
				_sub = float(s["gap"])
				var arms := int(s["arms"])
				for a in arms:
					_bullet(position + Vector2(0, -10), Vector2.from_angle(_spin_a + TAU * a / arms) * float(s["speed"]))
				_spin_a += float(s["spin"]) * float(s["gap"])
				_sc += 1
				if _sc % 3 == 1:
					main.sfx.play("enemy_shot", randf_range(0.8, 0.95), -4.0)
		"charge":
			return _charge_step(s, to_player)
		"beam":
			_beam_step(s, to_player)
		"meteors":
			if _sstate == "start":
				_sstate = "falling"
				for i in int(s["count"]):
					var offset := Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(30.0, 100.0)
					main.spawn_meteor(target.position + offset, damage, 1.0 + i * 0.12)
			if _st >= 1.4:
				_next_step()
		"summon":
			for i in int(s["count"]):
				var off := Vector2.from_angle(TAU * i / int(s["count"])) * 30.0
				main.spawn_minion(s["kind"], position + off)
			main.camera.add_trauma(0.3)
			main.sfx.play("summon")
			_next_step()
		"teleport":
			_teleport_step()
	return Vector2.ZERO


func _charge_step(s: Dictionary, to_player: Vector2) -> Vector2:
	match _sstate:
		"start":
			_sstate = "windup"
			_sub = 0.6
			_aim = to_player.normalized()
			main.sfx.play("growl", 0.75)
		"windup":
			if _sub > 0.2:
				_aim = to_player.normalized()
			if _sub <= 0.0:
				_sstate = "go"
				_sub = 0.55
				main.sfx.play("charge", 0.85)
		"go":
			if _sub <= 0.0:
				_end_charge(s)
				return Vector2.ZERO
			return _aim * float(s["speed"])
		"recover":
			if _sub <= 0.0:
				_sstate = "start"
	return Vector2.ZERO


func _on_charge_wall(normal: Vector2) -> void:
	main.camera.add_trauma(0.35)
	main.sfx.play("wall_slam", randf_range(0.9, 1.05))
	if _step.get("bounce", false) and _bounces < 2:
		_bounces += 1
		_aim = _aim.bounce(normal)
		_fire_ring(10, randf() * TAU, 0, 80.0)
		return
	_end_charge(_step)


func _end_charge(s: Dictionary) -> void:
	_sc += 1
	_bounces = 0
	if _sc >= int(s["repeat"]):
		_next_step()
	else:
		_sstate = "recover"
		_sub = 0.35


func _beam_step(s: Dictionary, to_player: Vector2) -> void:
	match _sstate:
		"start":
			_sstate = "aim"
			_sub = 0.9
			_beam_hit = false
			_aim = to_player.normalized()
			main.sfx.play("beam_charge")
		"aim":
			if _sub > 0.25:
				_aim = (target.position + Vector2(0, -5) - _eye()).normalized()
			if _sub <= 0.0:
				_sstate = "fire"
				_sub = 0.35
				main.camera.add_trauma(0.3)
				main.sfx.play("beam_fire")
		"fire":
			if not _beam_hit and target.can_be_hit():
				var p := target.position + Vector2(0, -5)
				var closest := Geometry2D.get_closest_point_to_segment(p, _eye(), _eye() + _aim * 700.0)
				if p.distance_to(closest) < 7.0:
					_beam_hit = true
					target.take_damage(damage, position)
					target.apply_slow(1.5)
			if _sub <= 0.0:
				_sc += 1
				if _sc >= int(s["repeat"]):
					_next_step()
				else:
					_sstate = "start"


func _teleport_step() -> void:
	match _sstate:
		"start":
			_sstate = "out"
			main.sfx.play("teleport")
		"out":
			_alpha -= 0.06
			if _alpha <= 0.0:
				_alpha = 0.0
				var size: Vector2 = main.room.size
				var ang := randf_range(-PI * 0.85, -PI * 0.15)
				var p: Vector2 = target.position + Vector2.from_angle(ang) * randf_range(130.0, 170.0)
				p = p.clamp(Vector2(50, 70), size - Vector2(50, 50))
				var guard := 0
				while main.room.blocked(p) and guard < 20:
					p = p.move_toward(size / 2, 8.0)
					guard += 1
				position = p
				_sstate = "in"
		"in":
			_alpha += 0.06
			if _alpha >= 1.0:
				_alpha = 1.0
				_next_step()


func _eye() -> Vector2:
	return position + Vector2(0, -16)


func _origins(heads: bool) -> Array:
	if heads:
		return [Vector2(-13, -16), Vector2(0, -20), Vector2(13, -16)]
	return [Vector2(0, -12)]


func _fire_spread(count: int, spread: float, spd: float, heads: bool) -> void:
	for o in _origins(heads):
		var from: Vector2 = position + o
		var base := (target.position + Vector2(0, -5) - from).angle()
		for i in count:
			var a := base
			if count > 1:
				a += lerpf(-spread / 2.0, spread / 2.0, float(i) / (count - 1))
			_bullet(from, Vector2.from_angle(a) * spd)
	main.sfx.play("boss_shot", randf_range(0.92, 1.05))


func _fire_ring(count: int, offset: float, gap_size: int, spd: float) -> void:
	var gap_center := randi() % count
	for i in count:
		if gap_size > 0:
			var d := absi(i - gap_center)
			if mini(d, count - d) <= gap_size / 2:
				continue
		_bullet(position + Vector2(0, -8), Vector2.from_angle(offset + TAU * i / count) * spd)
	main.sfx.play("boss_ring", randf_range(0.95, 1.05))


func _bullet(from: Vector2, vel: Vector2) -> void:
	main.spawn_enemy_bullet(from, vel, bullet_damage, data["bullet"], boss_id == "medusa")


func _boss_scale() -> float:
	return 1.0 - _spawn_t / 1.2 if _spawn_t > 0.0 else 1.0


func _draw() -> void:
	if _fx:
		_fx.queue_redraw()
	modulate.a = _alpha
	var s := _boss_scale()
	var c := color
	if is_slowed():
		c = c.lerp(Color("a8e6ff"), 0.35)
	var windup: bool = _step.get("do", "") == "charge" and _sstate == "windup"
	var shake := Vector2(randf_range(-1, 1), 0) if windup else Vector2.ZERO
	Art.soft_shadow(self, Vector2(2, 1), (body_radius + 8) * s, (body_radius * 0.45 + 3) * s)
	if sprite:
		draw_set_transform(Vector2.ZERO)
		return
	draw_set_transform(shake, 0, Vector2(s, s))
	match boss_id:
		"cerbero":
			for leg in [Vector2(-12, -6), Vector2(-5, -5), Vector2(5, -5), Vector2(12, -6)]:
				Art.limb(self, leg, leg + Vector2(0, 6), 4.0, c.darkened(0.35))
			Art.blob(self, Vector2(0, -11), Vector2(18, 10), c, 0.6, 22)
			for i in 9:
				var a := PI + PI * i / 8.0
				var p := Vector2(0, -15) + Vector2(cos(a) * 15.0, sin(a) * 6.0)
				draw_colored_polygon(PackedVector2Array([p + Vector2(-2, 1), p + Vector2(2, 1), p + Vector2(0, -4 - sin(_t * 6 + i))]), c.darkened(0.45))
			for head in [Vector2(-13, -19), Vector2(0, -24), Vector2(13, -19)]:
				Art.blob(self, head, Vector2(6, 5.4), c.lightened(0.08), 0.55, 16)
				Art.blob(self, head + Vector2(0, 3.2), Vector2(3.6, 2.6), c.darkened(0.15), 0.5, 12)
				draw_colored_polygon(PackedVector2Array([head + Vector2(-5, -2), head + Vector2(-6, -8), head + Vector2(-2, -4)]), c.darkened(0.3))
				draw_colored_polygon(PackedVector2Array([head + Vector2(5, -2), head + Vector2(6, -8), head + Vector2(2, -4)]), c.darkened(0.3))
				draw_circle(head + Vector2(0, 4.8), 1.0, Color("1a0a0a"))
		"medusa":
			for i in 10:
				var t := float(i) / 9.0
				var p := Vector2(sin(t * 5.0 + _t * 2.0) * 9.0 * (1.0 - t * 0.5), -2.0 + t * 5.0)
				Art.blob(self, p, Vector2(6.5 - t * 3.0, 3.6 - t * 1.4), c.darkened(0.1 + t * 0.2), 0.6, 12)
			Art.vgrad_poly(self, PackedVector2Array([Vector2(-7, -18), Vector2(7, -18), Vector2(9, -4), Vector2(-9, -4)]), Color("5d2e6b"), Color("2e1636"))
			Art.blob(self, Vector2(0, -16), Vector2(6, 4.5), Color("9db58a"), 0.5, 14)
			Art.limb(self, Vector2(-6, -17), Vector2(-10, -11 + sin(_t * 3.0) * 2.0), 2.4, Color("9db58a"))
			Art.limb(self, Vector2(6, -17), Vector2(10, -11 - sin(_t * 3.0) * 2.0), 2.4, Color("9db58a"))
			var head := Vector2(0, -25)
			for i in 7:
				var a := PI + PI * i / 6.0
				var mid := head + Vector2.from_angle(a) * 5.0
				var tip := head + Vector2.from_angle(a + sin(_t * 7.0 + i) * 0.4) * (10.0 + sin(_t * 5.0 + i * 1.3) * 1.5)
				Art.limb(self, head, mid, 2.0, c.lightened(0.1))
				Art.limb(self, mid, tip, 1.6, c.lightened(0.1))
				Art.sphere(self, tip, 1.5, c.lightened(0.2))
			Art.sphere(self, head, 4.6, Color("b5c99e"), 0.5)
		"talos":
			var bronze := c
			Art.limb(self, Vector2(-7, -10), Vector2(-8, 0), 6.0, bronze.darkened(0.3))
			Art.limb(self, Vector2(7, -10), Vector2(8, 0), 6.0, bronze.darkened(0.3))
			Art.blob(self, Vector2(0, -22), Vector2(15, 13), bronze, 0.85, 24)
			Art.sphere(self, Vector2(-16, -29), 6.0, bronze.lightened(0.05), 0.85)
			Art.sphere(self, Vector2(16, -29), 6.0, bronze.lightened(0.05), 0.85)
			var swing := sin(_t * 2.0) * 2.0
			Art.limb(self, Vector2(-18, -26), Vector2(-21, -12 + swing), 5.0, bronze.darkened(0.15))
			Art.limb(self, Vector2(18, -26), Vector2(21, -12 - swing), 5.0, bronze.darkened(0.15))
			Art.sphere(self, Vector2(-21, -11 + swing), 4.4, bronze.darkened(0.05), 0.8)
			Art.sphere(self, Vector2(21, -11 - swing), 4.4, bronze.darkened(0.05), 0.8)
			Art.blob(self, Vector2(0, -39), Vector2(6.5, 6.0), bronze.lightened(0.08), 0.85, 16)
			draw_colored_polygon(PackedVector2Array([Vector2(-1.5, -46), Vector2(1.5, -46), Vector2(1, -51), Vector2(-6, -48)]), Color("c0392b"))
			draw_rect(Rect2(-4.5, -40, 9, 2), Color("1a120a"))
	draw_set_transform(Vector2.ZERO)


func _draw_fx() -> void:
	var s := _boss_scale()
	_fx.modulate.a = _alpha
	var windup: bool = _step.get("do", "") == "charge" and _sstate == "windup"
	if windup:
		var line := Art.hdr(Color(1, 0.2, 0.15, 0.45), 1.2)
		_fx.draw_line(Vector2(0, -8), Vector2(0, -8) + _aim * 150.0, line, 10.0, true)
		_fx.draw_line(Vector2(0, -8), Vector2(0, -8) + _aim * 150.0, Art.hdr(Color(1, 0.4, 0.3, 0.8), 1.5), 2.0, true)
	if _step.get("do", "") == "beam":
		var from := _eye() - position
		if _sstate == "aim":
			var a := 0.6 if int(_t * 20) % 2 == 0 else 0.25
			_fx.draw_line(from, from + _aim * 700.0, Art.hdr(Color(1, 0.3, 0.3, a), 1.5), 1.2, true)
		elif _sstate == "fire":
			_fx.draw_line(from, from + _aim * 700.0, Art.hdr(Color("9be36d"), 1.6), 10.0, true)
			_fx.draw_line(from, from + _aim * 700.0, Art.hdr(Color.WHITE, 2.5), 3.0, true)
	_fx.draw_set_transform(Vector2.ZERO, 0, Vector2(s, s))
	if sprite == null:
		match boss_id:
			"cerbero":
				for head in [Vector2(-13, -19), Vector2(0, -24), Vector2(13, -19)]:
					var eye := Art.hdr(Color("ffb13b"), 2.6)
					_fx.draw_circle(head + Vector2(-2, -0.5), 0.9, eye)
					_fx.draw_circle(head + Vector2(2, -0.5), 0.9, eye)
					var firing: bool = _step.get("do", "") == "spread" or phase == 2
					Art.glow(_fx, head + Vector2(0, 4), 9.0 if firing else 5.0, Color("ff5a1f"), 1.2 if firing else 0.6)
			"medusa":
				var gaze: bool = _step.get("do", "") == "beam"
				var eye := Art.hdr(Color("ffee55"), 3.0 if gaze else 1.6)
				_fx.draw_circle(Vector2(-1.6, -25.5), 0.9, eye)
				_fx.draw_circle(Vector2(1.6, -25.5), 0.9, eye)
				if gaze:
					Art.glow(_fx, Vector2(0, -25), 18.0, Color("ffee55"), 1.2)
			"talos":
				var core := Color("ffb142") if phase == 1 else Color("ff3b1f")
				var pulse := 1.6 + 0.6 * sin(_t * 6.0)
				Art.glow(_fx, Vector2(0, -22), 12.0, core, 0.7 * pulse)
				Art.blob(_fx, Vector2(0, -22), Vector2(3.6, 3.6), Art.hdr(core, pulse), 0.1, 12)
				_fx.draw_line(Vector2(-4, -39), Vector2(4, -39), Art.hdr(Color("ff3b1f"), 2.5), 1.4, true)
				if phase == 2:
					for i in 4:
						var a := TAU * i / 4.0 + 0.4
						_fx.draw_line(Vector2(0, -22), Vector2(0, -22) + Vector2.from_angle(a) * 11.0, Art.hdr(core, 1.6), 1.0, true)
	if phase == 2:
		var aura_c := Vector2(0, -sprite.height * 0.45) if sprite else Vector2(0, -body_radius)
		var aura_r := sprite.height * 0.75 if sprite else body_radius * 2.4
		Art.glow(_fx, aura_c, aura_r, Color("ff2a2a"), 0.35 + 0.2 * sin(_t * 8.0))
	if _flash > 0.0 and sprite == null:
		Art.blob(_fx, Vector2(0, -body_radius), Vector2(body_radius + 2, body_radius + 3), Color(1.1, 1.1, 1.1, 0.35), 0.1, 16)
	if is_slowed():
		Art.glow(_fx, Vector2(0, -body_radius), body_radius + 8.0, Color("a8e6ff"), 0.4)
	_fx.draw_set_transform(Vector2.ZERO)


func _update_boss_sprite() -> void:
	if sprite == null:
		return
	sprite.scale = Vector2.ONE * sprite.base_scale * _boss_scale()
	var to_player := target.position - position if target else Vector2.DOWN
	var act: String = _step.get("do", "wait")
	var attacking := act in ["spread", "ring", "spiral", "summon", "meteors"] or (act == "beam") or (act == "charge" and _sstate == "windup")
	if act == "charge" and _sstate == "go":
		sprite.show_state("move", _aim, 2.2)
	elif attacking:
		sprite.show_state("attack", _aim if act in ["beam", "charge"] else to_player)
	else:
		sprite.show_state("move", velocity if velocity.length() > 5.0 else to_player, 1.0 if velocity.length() > 5.0 else 0.4)
	var windup: bool = act == "charge" and _sstate == "windup"
	sprite.position.x = randf_range(-1.2, 1.2) if windup else 0.0
	var tint := Color.WHITE
	if is_slowed():
		tint = Color(0.75, 0.88, 1.1)
	if _flash > 0.0:
		tint = Color(1.8, 1.8, 1.8)
	sprite.modulate = tint

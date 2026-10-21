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


func _physics_process(delta: float) -> void:
	_t += delta
	_flash -= delta
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
		"windup":
			if _sub > 0.2:
				_aim = to_player.normalized()
			if _sub <= 0.0:
				_sstate = "go"
				_sub = 0.55
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
		"aim":
			if _sub > 0.25:
				_aim = (target.position + Vector2(0, -5) - _eye()).normalized()
			if _sub <= 0.0:
				_sstate = "fire"
				_sub = 0.35
				main.camera.add_trauma(0.3)
				main.sfx.play("zap", 0.6)
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
		"out":
			_alpha -= 0.06
			if _alpha <= 0.0:
				_alpha = 0.0
				var size: Vector2 = main.room.size
				var p := Vector2(randf_range(60.0, size.x - 60.0), randf_range(80.0, size.y * 0.45))
				if p.distance_to(target.position) < 120.0:
					p.y = clampf(target.position.y - 160.0, 80.0, size.y - 80.0)
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
	main.sfx.play("shoot", 0.6)


func _fire_ring(count: int, offset: float, gap_size: int, spd: float) -> void:
	var gap_center := randi() % count
	for i in count:
		if gap_size > 0:
			var d := absi(i - gap_center)
			if mini(d, count - d) <= gap_size / 2:
				continue
		_bullet(position + Vector2(0, -8), Vector2.from_angle(offset + TAU * i / count) * spd)
	main.sfx.play("hit", 0.5)


func _bullet(from: Vector2, vel: Vector2) -> void:
	main.spawn_enemy_bullet(from, vel, bullet_damage, data["bullet"], boss_id == "medusa")


func _draw() -> void:
	var s := 1.0
	if _spawn_t > 0.0:
		s = 1.0 - _spawn_t / 1.2
	var c := Color.WHITE if _flash > 0.0 else color
	if is_slowed() and _flash <= 0.0:
		c = c.lerp(Color("a8e6ff"), 0.4)
	c.a = _alpha
	var shake := Vector2.ZERO
	var windup: bool = _step.get("do", "") == "charge" and _sstate == "windup"
	if windup:
		shake = Vector2(randf_range(-1, 1), 0).round()
		var line := Color(1, 0.2, 0.2, 0.35)
		draw_line(Vector2(0, -6), Vector2(0, -6) + _aim * 140.0, line, 6.0)
	if _step.get("do", "") == "beam":
		var from := _eye() - position
		if _sstate == "aim":
			draw_line(from, from + _aim * 700.0, Color(1, 0.3, 0.3, 0.5 if int(_t * 20) % 2 == 0 else 0.2), 1.0)
		elif _sstate == "fire":
			draw_line(from, from + _aim * 700.0, Color("9be36d"), 8.0)
			draw_line(from, from + _aim * 700.0, Color.WHITE, 3.0)
	draw_set_transform(shake, 0, Vector2(s, s))
	draw_rect(Rect2(-body_radius, 2, body_radius * 2, 4), Color(0, 0, 0, 0.35 * _alpha))
	match boss_id:
		"cerbero":
			draw_rect(Rect2(-18, -12, 36, 16), c)
			for x in [-16, -6, 4, 12]:
				draw_rect(Rect2(x, 4, 4, 4), c.darkened(0.3))
			for head in [Vector2(-13, -18), Vector2(0, -22), Vector2(13, -18)]:
				draw_rect(Rect2(head + Vector2(-5, -4), Vector2(10, 9)), c.lightened(0.1))
				draw_rect(Rect2(head + Vector2(-3, -1), Vector2(2, 2)), Color("ffdd55"))
				draw_rect(Rect2(head + Vector2(1, -1), Vector2(2, 2)), Color("ffdd55"))
		"medusa":
			draw_rect(Rect2(-9, -12, 18, 16), c)
			draw_rect(Rect2(-6, -22, 12, 10), Color("c9d6a3"))
			for i in 6:
				var a := -PI + PI * i / 5.0
				var tip := Vector2(0, -20) + Vector2.from_angle(a) * (9.0 + sin(_t * 8.0 + i) * 2.0)
				draw_line(Vector2(0, -20), tip, c.lightened(0.2), 2.0)
			var eye := Color("ffee55") if _step.get("do", "") == "beam" else Color("2d3436")
			draw_rect(Rect2(-4, -18, 2, 2), eye)
			draw_rect(Rect2(2, -18, 2, 2), eye)
		"talos":
			draw_rect(Rect2(-16, -30, 32, 30), c)
			draw_rect(Rect2(-22, -26, 6, 18), c.darkened(0.2))
			draw_rect(Rect2(16, -26, 6, 18), c.darkened(0.2))
			draw_rect(Rect2(-8, -40, 16, 11), c.darkened(0.15))
			draw_rect(Rect2(-3, -36, 6, 3), Color("ff3b3b"))
			var core := Color("ffb142") if phase == 1 else Color("ff3b3b")
			if int(_t * 6) % 2 == 0:
				core = core.lightened(0.3)
			draw_rect(Rect2(-4, -20, 8, 8), core)
	if phase == 2 and int(_t * 8) % 2 == 0:
		draw_rect(Rect2(-body_radius - 4, -body_radius * 2 - 18, body_radius * 2 + 8, body_radius * 2 + 22), Color(1, 0.2, 0.2, 0.6), false, 1.0)
	draw_set_transform(Vector2.ZERO)

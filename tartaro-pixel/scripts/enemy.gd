class_name Enemy
extends CharacterBody2D

enum Kind { SHADE, BRUTE, WISP, ARCHER, BOMBER }

static var STATS := {
	Kind.SHADE: {"hp": 3, "speed": 55.0, "damage": 8, "color": Color("8e44ad"), "radius": 5.0, "contact": 10.0, "score": 1, "xp": 1},
	Kind.BRUTE: {"hp": 7, "speed": 32.0, "damage": 12, "color": Color("d35400"), "radius": 7.0, "contact": 12.0, "score": 2, "xp": 3},
	Kind.WISP: {"hp": 1, "speed": 92.0, "damage": 5, "color": Color("48dbfb"), "radius": 4.0, "contact": 8.0, "score": 1, "xp": 1},
	Kind.ARCHER: {"hp": 3, "speed": 42.0, "damage": 7, "color": Color("dcd3b6"), "radius": 5.0, "contact": 9.0, "score": 2, "xp": 2},
	Kind.BOMBER: {"hp": 2, "speed": 68.0, "damage": 16, "color": Color("e17055"), "radius": 5.0, "contact": 0.0, "score": 1, "xp": 1},
}

var kind := Kind.SHADE
var target: Player
var main: Node
var elite := false

var max_hp := 3
var hp := 3
var speed := 55.0
var damage := 8
var color := Color("8e44ad")
var contact_radius := 10.0
var body_radius := 5.0
var knock_mult := 1.0
var score_mult := 1
var xp_value := 1

var _knock := Vector2.ZERO
var _flash := 0.0
var _spawn_t := 0.25
var _side := 1.0
var _t := 0.0

var _state := "chase"
var _state_t := 0.0
var _charge_dir := Vector2.ZERO

var _burn_dps := 0.0
var _burn_t := 0.0
var _burn_acc := 0.0
var _slow := 0.0
var _slow_t := 0.0


func setup(k: Kind, player: Player, main_ref: Node, hp_mult: float, dmg_mult: float, is_elite: bool) -> void:
	kind = k
	target = player
	main = main_ref
	elite = is_elite
	var s: Dictionary = STATS[k]
	max_hp = ceili(s["hp"] * hp_mult * (2.5 if elite else 1.0))
	hp = max_hp
	speed = s["speed"]
	damage = roundi(s["damage"] * dmg_mult)
	color = s["color"]
	body_radius = s["radius"]
	contact_radius = s["contact"]
	score_mult = s["score"] * (3 if elite else 1)
	xp_value = s["xp"] * (3 if elite else 1)
	_side = 1.0 if randf() < 0.5 else -1.0
	_state_t = randf_range(1.0, 2.0)


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 2 | 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius * (1.25 if elite else 1.0)
	shape.shape = circle
	add_child(shape)


func is_spawning() -> bool:
	return _spawn_t > 0.0


func is_slowed() -> bool:
	return _slow_t > 0.0


func apply_burn(dps: float) -> void:
	_burn_dps = maxf(_burn_dps, dps)
	_burn_t = 3.0


func apply_slow(amount: float, duration: float) -> void:
	_slow = maxf(_slow, amount)
	_slow_t = duration


func _tick_status(delta: float) -> void:
	if _slow_t > 0.0:
		_slow_t -= delta
		if _slow_t <= 0.0:
			_slow = 0.0
	if _burn_t > 0.0:
		_burn_t -= delta
		var dps := _burn_dps * (2.0 if is_slowed() and main.has_duo("inferno_gelido") else 1.0)
		_burn_acc += dps * delta
		if _burn_acc >= 1.0:
			var d := int(_burn_acc)
			_burn_acc -= d
			main.status_damage(self, d, Color("ff8c3a"))
		if _burn_t <= 0.0:
			_burn_dps = 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	_flash -= delta
	if _spawn_t > 0.0:
		_spawn_t -= delta
		queue_redraw()
		return
	_tick_status(delta)
	if hp <= 0:
		return
	if target.is_dead:
		velocity = _knock
		move_and_slide()
		return

	var to_player := target.position - position
	var move := Vector2.ZERO
	match kind:
		Kind.SHADE:
			move = to_player.normalized() * speed
		Kind.WISP:
			var wobble := to_player.orthogonal().normalized() * sin(_t * 5.0) * 0.7
			move = (to_player.normalized() + wobble).normalized() * speed
		Kind.BRUTE:
			move = _brute_move(to_player, delta)
		Kind.ARCHER:
			move = _archer_move(to_player, delta)
		Kind.BOMBER:
			move = _bomber_move(to_player, delta)
	move *= 1.0 - _slow
	if is_on_wall() and _state != "charge":
		move += to_player.orthogonal().normalized() * speed * 0.7 * _side

	velocity = move + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 900 * delta)
	move_and_slide()

	if contact_radius > 0.0 and to_player.length() < contact_radius and _state != "recover":
		target.take_damage(damage, position)
	queue_redraw()


func _brute_move(to_player: Vector2, delta: float) -> Vector2:
	_state_t -= delta
	match _state:
		"chase":
			if to_player.length() < 110.0:
				_state = "windup"
				_state_t = 0.55
			return to_player.normalized() * speed
		"windup":
			if _state_t > 0.15:
				_charge_dir = to_player.normalized()
			if _state_t <= 0.0:
				_state = "charge"
				_state_t = 0.35
			return Vector2.ZERO
		"charge":
			if _state_t <= 0.0:
				_state = "recover"
				_state_t = 0.7
			return _charge_dir * 290.0
		"recover":
			if _state_t <= 0.0:
				_state = "chase"
			return Vector2.ZERO
	return Vector2.ZERO


func _archer_move(to_player: Vector2, delta: float) -> Vector2:
	_state_t -= delta
	var d := to_player.length()
	var dir := to_player.normalized()
	if _state == "aim":
		if _state_t <= 0.0:
			main.spawn_enemy_bullet(position + Vector2(0, -6), dir * 125.0, damage, Color("9be36d"))
			_state = "chase"
			_state_t = randf_range(1.8, 2.6)
		return Vector2.ZERO
	if _state_t <= 0.0 and d < 230.0:
		_state = "aim"
		_state_t = 0.5
		return Vector2.ZERO
	if d > 150.0:
		return dir * speed
	if d < 95.0:
		return -dir * speed
	return dir.orthogonal() * speed * 0.6 * _side


func _bomber_move(to_player: Vector2, delta: float) -> Vector2:
	if _state == "fuse":
		_state_t -= delta
		if _state_t <= 0.0 and hp > 0:
			hp = 0
			main.explode(position, 36.0, damage, Color("ff9f43"), true)
			main.on_enemy_killed(self, false)
			queue_free()
		return Vector2.ZERO
	if to_player.length() < 26.0:
		_state = "fuse"
		_state_t = 0.55
	return to_player.normalized() * speed


func take_hit(amount: int, dir: Vector2, crit := false, status := false) -> void:
	if hp <= 0:
		return
	hp -= amount
	_flash = 0.08
	if dir != Vector2.ZERO:
		_knock = dir * (40.0 if _state == "charge" else 150.0) * knock_mult
	main.on_enemy_hit(self, amount, crit, status)
	if hp <= 0:
		main.on_enemy_killed(self)
		queue_free()


func _draw() -> void:
	var s := 1.25 if elite else 1.0
	if _spawn_t > 0.0:
		s *= 1.0 - _spawn_t / 0.25
	var c := color
	if is_slowed():
		c = c.lerp(Color("a8e6ff"), 0.45)
	if _flash > 0.0:
		c = Color.WHITE
	var shake := Vector2.ZERO
	if _state == "windup" or _state == "fuse" or _state == "aim":
		shake = Vector2(randf_range(-1, 1), 0).round()
		if int(_t * 16) % 2 == 0 and _flash <= 0.0:
			c = Color("ff5544") if _state != "aim" else Color("c8ff9e")
	draw_set_transform(shake, 0, Vector2(s, s))

	match kind:
		Kind.SHADE:
			draw_rect(Rect2(-5, 1, 10, 3), Color(0, 0, 0, 0.35))
			draw_rect(Rect2(-5, -10, 10, 11), c)
			draw_rect(Rect2(-4, 1, 2, 2), c)
			draw_rect(Rect2(2, 1, 2, 2), c)
			draw_rect(Rect2(-3, -7, 2, 2), Color("ff3b3b"))
			draw_rect(Rect2(1, -7, 2, 2), Color("ff3b3b"))
		Kind.BRUTE:
			draw_rect(Rect2(-7, 2, 14, 3), Color(0, 0, 0, 0.35))
			draw_rect(Rect2(-7, -12, 14, 14), c)
			draw_rect(Rect2(-8, -15, 3, 4), Color("f0e6d2"))
			draw_rect(Rect2(5, -15, 3, 4), Color("f0e6d2"))
			draw_rect(Rect2(-4, -8, 3, 2), Color("ffee55"))
			draw_rect(Rect2(1, -8, 3, 2), Color("ffee55"))
		Kind.WISP:
			var trail := c
			trail.a = 0.4
			draw_rect(Rect2(-2, -1, 4, 4), trail)
			draw_rect(Rect2(-3, -8, 6, 7), c)
			draw_rect(Rect2(-2, -6, 1, 1), Color.WHITE)
			draw_rect(Rect2(1, -6, 1, 1), Color.WHITE)
		Kind.ARCHER:
			draw_rect(Rect2(-4, 1, 8, 3), Color(0, 0, 0, 0.35))
			draw_rect(Rect2(-3, -12, 6, 5), c)
			draw_rect(Rect2(-2, -7, 4, 7), c.darkened(0.25))
			draw_rect(Rect2(-2, -10, 1, 1), Color.BLACK)
			draw_rect(Rect2(1, -10, 1, 1), Color.BLACK)
			draw_line(Vector2(5, -12), Vector2(5, -1), Color("6ab04c"), 1.0)
		Kind.BOMBER:
			draw_rect(Rect2(-5, 1, 10, 3), Color(0, 0, 0, 0.35))
			draw_circle(Vector2(0, -5), 5.0, c)
			draw_rect(Rect2(-1, -12, 2, 3), Color("2d3436"))
			if int(_t * 10) % 2 == 0:
				draw_rect(Rect2(-1, -14, 2, 2), Color("ffd84a"))

	if elite:
		draw_rect(Rect2(-body_radius - 2, -body_radius * 2 - 6, body_radius * 2 + 4, body_radius * 2 + 8), Color("ffd84a"), false, 1.0)
	if _burn_t > 0.0 and int(_t * 12) % 2 == 0:
		draw_rect(Rect2(randf_range(-4, 3), -14, 2, 2), Color("ff8c3a"))
	draw_set_transform(Vector2.ZERO)

	if hp < max_hp and hp > 0:
		var w := 12.0
		var y := -20.0 if kind == Kind.BRUTE or elite else -15.0
		draw_rect(Rect2(-w / 2, y, w, 2), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2, y, w * float(hp) / max_hp, 2), Color("ff4757"))

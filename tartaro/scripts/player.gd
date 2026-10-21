class_name Player
extends CharacterBody2D

signal died
signal hp_changed(hp: int, max_hp: int)

const SPEED := 115.0
const DASH_SPEED := 430.0
const DASH_TIME := 0.13
const DASH_COOLDOWN := 0.35
const INVULN_AFTER_HIT := 0.9

const HERO_SCALE := 1.2
const COLOR_BODY := Color("e8d9b0")
const COLOR_CLOAK := Color("c0392b")
const COLOR_DASH := Color("7fe7ff")

var controls: TouchControls
var main: Node

var max_hp := 50
var hp := 50
var facing := Vector2.DOWN
var is_dead := false
var max_dash_charges := 1
var dash_charges := 1

var _dash_timer := 0.0
var _dash_gap := 0.0
var _recharge := 0.0
var _slow_t := 0.0
var _dash_dir := Vector2.ZERO
var _trail_timer := 0.0
var _invuln := 0.0
var _attack_cd := 0.0
var _knock := Vector2.ZERO
var _walk := 0.0
var sprite: HeroSprite
var _attack_anim := 0.0
var _attack_dir := Vector2.DOWN


func _ready() -> void:
	collision_layer = 1
	collision_mask = 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5
	shape.shape = circle
	add_child(shape)
	if HeroSprite.available():
		sprite = HeroSprite.new()
		add_child(sprite)
		sprite.fit_height(34.0)


func is_dashing() -> bool:
	return _dash_timer > 0.0


func can_be_hit() -> bool:
	return not is_dead and _invuln <= 0.0 and not is_dashing()


func apply_slow(duration: float) -> void:
	_slow_t = maxf(_slow_t, duration)


func recharge_ratio() -> float:
	if dash_charges >= max_dash_charges:
		return 1.0
	return 1.0 - _recharge / (DASH_COOLDOWN * main.dash_cd_mult())


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_dash_gap -= delta
	_invuln -= delta
	_attack_cd -= delta
	_slow_t -= delta
	if dash_charges < max_dash_charges:
		_recharge -= delta
		if _recharge <= 0.0:
			dash_charges += 1
			_recharge = DASH_COOLDOWN * main.dash_cd_mult()

	var input_dir := controls.get_move_vector()
	if input_dir.length() > 0.2:
		facing = input_dir.normalized()

	if controls.consume_dash():
		_try_dash(controls.dash_direction())

	if is_dashing():
		_dash_timer -= delta
		velocity = _dash_dir * DASH_SPEED
		if _dash_timer <= 0.0:
			main.on_dash_end(position)
		_trail_timer -= delta
		if _trail_timer <= 0.0:
			_trail_timer = 0.018
			main.spawn_afterimage(position, facing, _walk)
	else:
		var slow := 0.45 if _slow_t > 0.0 else 1.0
		velocity = input_dir * SPEED * main.move_speed_mult() * slow + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 600 * delta)
	if velocity.length() > 10.0 and not is_dashing():
		_walk += velocity.length() * get_physics_process_delta_time() * 0.16
	move_and_slide()

	if not is_dashing():
		_auto_attack()
	queue_redraw()
	_update_sprite(delta)


func _update_sprite(delta: float) -> void:
	if sprite == null:
		return
	_attack_anim -= delta
	var tint := Color.WHITE
	if is_dead:
		sprite.show_state("idle", facing)
		sprite.rotation = PI * 0.5
		sprite.self_modulate = Color(0.55, 0.45, 0.45)
		return
	if is_dashing():
		sprite.show_state("dash", _dash_dir)
		tint = Color(0.75, 1.25, 1.5)
	elif _attack_anim > 0.0 and velocity.length() < 40.0:
		sprite.show_state("attack", _attack_dir)
	elif velocity.length() > 12.0:
		sprite.show_state("walk", velocity.normalized(), clampf(velocity.length() / SPEED, 0.6, 1.6))
	else:
		sprite.show_state("idle", facing)
	if _slow_t > 0.0:
		tint = Color(0.65, 0.75, 0.65)
	sprite.self_modulate = tint
	sprite.visible = not (_invuln > 0.0 and int(_invuln * 20) % 2 == 0)


func _try_dash(dir: Vector2) -> void:
	if dash_charges <= 0 or _dash_gap > 0.0 or is_dashing():
		return
	if dash_charges == max_dash_charges:
		_recharge = DASH_COOLDOWN * main.dash_cd_mult()
	dash_charges -= 1
	_dash_dir = dir if dir != Vector2.ZERO else facing
	facing = _dash_dir
	_dash_timer = DASH_TIME
	_dash_gap = DASH_TIME + 0.08
	_slow_t = 0.0
	_trail_timer = 0.0
	main.on_player_dash()


func _auto_attack() -> void:
	if _attack_cd > 0.0:
		return
	var target: Node2D = null
	var best := INF
	var reach: float = main.weapon["range"]
	var from := position + Vector2(0, -5)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_spawning() or e.hp <= 0:
			continue
		var d: float = position.distance_to(e.position)
		if d > reach:
			continue
		var score := d if main.line_clear(from, e.position + Vector2(0, -4)) else d + 1000.0
		if score < best:
			best = score
			target = e
	if target == null:
		return
	_attack_cd = main.attack_interval()
	main.fire_weapon(target)
	_attack_anim = 0.3
	_attack_dir = (target.position - position).normalized()
	if sprite:
		sprite.anim = ""


func heal(amount: int) -> void:
	if is_dead:
		return
	hp = mini(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)


func take_damage(amount: int, from_pos: Vector2) -> void:
	if is_dead or _invuln > 0.0 or is_dashing():
		return
	hp = max(hp - amount, 0)
	_invuln = INVULN_AFTER_HIT
	_knock = (position - from_pos).normalized() * 180
	hp_changed.emit(hp, max_hp)
	main.on_player_hurt()
	if hp == 0:
		is_dead = true
		if sprite:
			sprite.show_state("idle", facing)
			sprite.pause()
			sprite.rotation = PI * 0.5
			sprite.position = Vector2(-8, -2)
			sprite.self_modulate = Color(0.6, 0.5, 0.5)
			sprite.visible = true
		queue_redraw()
		died.emit()


func _draw() -> void:
	if sprite:
		Art.soft_shadow(self, Vector2(1, 0), 10, 4)
		if not is_dead:
			draw_set_transform(Vector2.ZERO, 0, Vector2(1.0, 0.45))
			draw_arc(Vector2.ZERO, 11.5, 0, TAU, 32, Color(1.0, 0.82, 0.4, 0.55), 1.2, true)
			draw_set_transform(Vector2.ZERO)
		return
	if is_dead:
		Art.soft_shadow(self, Vector2(0, 0), 9, 4)
		Art.blob(self, Vector2(0, -2), Vector2(7, 3.5), COLOR_CLOAK.darkened(0.3), 0.6)
		Art.sphere(self, Vector2(5, -3), 3.0, Color("e2b48c").darkened(0.2))
		return
	if _invuln > 0.0 and int(_invuln * 20) % 2 == 0:
		return
	var tint := COLOR_DASH if is_dashing() else Color.WHITE
	if _slow_t > 0.0:
		tint = Color(0.62, 0.7, 0.62)
	draw_set_transform(Vector2.ZERO, 0, Vector2(1.0, 0.45))
	draw_arc(Vector2.ZERO, 10.5, 0, TAU, 32, Color(1.0, 0.82, 0.4, 0.55), 1.2, true)
	draw_set_transform(Vector2.ZERO, 0, Vector2(HERO_SCALE, HERO_SCALE))
	draw_figure(self, facing, tint, 1.0, _walk)
	draw_set_transform(Vector2.ZERO)


static func _c(c: Color, tint: Color, alpha: float) -> Color:
	var out := c * tint
	out.a = alpha
	return out


static func draw_figure(ci: CanvasItem, dir: Vector2, tint: Color, alpha: float, walk := 0.0) -> void:
	var back := dir.y < -0.35
	var swing := sin(walk) * 2.0
	var bob := -absf(sin(walk)) * 0.9
	var skin := _c(Color("e0b088"), tint, alpha)
	var cloak := _c(COLOR_CLOAK, tint, alpha)
	var bronze := _c(Color("d2a24c"), tint, alpha)
	var leather := _c(Color("5b3a22"), tint, alpha)
	var hair := _c(Color("2b1a12"), tint, alpha)
	var linen := _c(Color("eadfc8"), tint, alpha)

	Art.soft_shadow(ci, Vector2(1, 0), 7.5, 3.2, alpha)
	Art.limb(ci, Vector2(-2, -5 + bob), Vector2(-2 + swing * 0.6, -0.5), 2.6, leather)
	Art.limb(ci, Vector2(2, -5 + bob), Vector2(2 - swing * 0.6, -0.5), 2.6, leather)

	var flutter := -dir * 2.5 + Vector2(sin(walk * 0.5) * 0.8, 0)
	var cape := PackedVector2Array([
		Vector2(-4.5, -13 + bob), Vector2(4.5, -13 + bob),
		Vector2(6.5 + flutter.x, -2 + flutter.y), Vector2(0 + flutter.x * 1.3, -0.5 + flutter.y),
		Vector2(-6.5 + flutter.x, -2 + flutter.y)])
	if not back:
		Art.vgrad_poly(ci, cape, cloak.darkened(0.35), cloak.darkened(0.6))

	Art.vgrad_poly(ci, PackedVector2Array([Vector2(-4.5, -7 + bob), Vector2(4.5, -7 + bob), Vector2(5.2, -3 + bob), Vector2(-5.2, -3 + bob)]), linen, linen.darkened(0.25))
	Art.blob(ci, Vector2(0, -9.5 + bob), Vector2(4.6, 4.4), bronze, 0.6, 16)
	ci.draw_line(Vector2(-3.5, -7 + bob), Vector2(3.5, -7 + bob), leather, 1.2, true)

	var side := 1.0 if dir.x >= 0.0 else -1.0
	var shoulder := Vector2(4.2 * side, -11 + bob)
	var hand := shoulder + Vector2(dir.x * 3.5 + side * 0.5, 3.5 + dir.y * 2.0)
	Art.limb(ci, Vector2(-4.2 * side, -11 + bob), Vector2(-4.6 * side, -6.5 + bob), 2.2, skin)

	var butt := hand - dir * 7.0
	var tip := hand + dir * 13.0
	ci.draw_line(butt, tip, _c(Color("7a5230"), tint, alpha), 1.4, true)
	var n := dir.orthogonal()
	ci.draw_colored_polygon(PackedVector2Array([tip + dir * 5.0, tip + n * 1.8, tip - dir * 1.0, tip - n * 1.8]), bronze.lightened(0.2))
	Art.limb(ci, shoulder, hand, 2.2, skin)

	var head := Vector2(0, -16.5 + bob)
	var ink := _c(Color("1b1410"), tint, alpha)
	Art.sphere(ci, head, 3.7, skin, 0.15)
	if back:
		Art.blob(ci, head + Vector2(0, -0.2), Vector2(3.9, 3.8), hair, 0.4, 16)
	else:
		Art.blob(ci, head + Vector2(0, -2.5), Vector2(4.0, 2.1), hair, 0.1, 16)
		Art.blob(ci, head + Vector2(-3.2, -0.6), Vector2(0.9, 1.8), hair, 0.1, 10)
		Art.blob(ci, head + Vector2(3.2, -0.6), Vector2(0.9, 1.8), hair, 0.1, 10)
		var look := Vector2(dir.x * 1.1, 0.0)
		ci.draw_line(head + look + Vector2(-2.0, 0.1), head + look + Vector2(-0.7, -0.1), ink, 0.45, true)
		ci.draw_line(head + look + Vector2(0.7, -0.1), head + look + Vector2(2.0, 0.1), ink, 0.45, true)
		ci.draw_circle(head + look + Vector2(-1.3, 0.95), 0.5, ink)
		ci.draw_circle(head + look + Vector2(1.3, 0.95), 0.5, ink)
		ci.draw_line(head + look + Vector2(-0.6, 2.2), head + look + Vector2(0.6, 2.2), _c(Color("8a4a3a"), tint, alpha), 0.4, true)
	var leaf := _c(Color("9cbf45"), tint, alpha)
	for i in 7:
		var a := PI * 1.05 + (PI * 0.9) * i / 6.0
		var p := head + Vector2(0, -0.6) + Vector2.from_angle(a) * 3.7
		var d := Vector2.from_angle(a + PI * 0.5) * 0.9
		ci.draw_colored_polygon(PackedVector2Array([p - d, p + Vector2.from_angle(a) * 0.9, p + d, p - Vector2.from_angle(a) * 0.6]), leaf)

	if back:
		Art.vgrad_poly(ci, cape, cloak, cloak.darkened(0.45))

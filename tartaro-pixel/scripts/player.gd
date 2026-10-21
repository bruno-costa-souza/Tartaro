class_name Player
extends CharacterBody2D

signal died
signal hp_changed(hp: int, max_hp: int)

const SPEED := 115.0
const DASH_SPEED := 430.0
const DASH_TIME := 0.13
const DASH_COOLDOWN := 0.35
const INVULN_AFTER_HIT := 0.9

const COLOR_BODY := Color("e8d9b0")
const COLOR_CLOAK := Color("c0392b")
const COLOR_DASH := Color("7fe7ff")

var controls: TouchControls
var main: Node

var max_hp := 50
var hp := 50
var facing := Vector2.UP
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


func _ready() -> void:
	collision_layer = 1
	collision_mask = 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5
	shape.shape = circle
	add_child(shape)


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
			main.spawn_afterimage(position, facing)
	else:
		var slow := 0.45 if _slow_t > 0.0 else 1.0
		velocity = input_dir * SPEED * main.move_speed_mult() * slow + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 600 * delta)
	move_and_slide()

	if not is_dashing():
		_auto_attack()
	queue_redraw()


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
	var best: float = main.weapon["range"]
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = position.distance_to(e.position)
		if d < best and not e.is_spawning() and e.hp > 0:
			best = d
			target = e
	if target == null:
		return
	_attack_cd = main.attack_interval()
	main.fire_weapon(target)


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
		queue_redraw()
		died.emit()


func _draw() -> void:
	if is_dead:
		draw_rect(Rect2(-6, -2, 12, 4), COLOR_CLOAK.darkened(0.4))
		return
	if _invuln > 0.0 and int(_invuln * 20) % 2 == 0:
		return
	var tint := COLOR_DASH if is_dashing() else Color.WHITE
	if _slow_t > 0.0:
		tint = Color(0.6, 0.68, 0.6)
	draw_figure(self, facing, tint, 1.0)


static func draw_figure(ci: CanvasItem, dir: Vector2, tint: Color, alpha: float) -> void:
	var cloak := COLOR_CLOAK * tint
	var body := COLOR_BODY * tint
	cloak.a = alpha
	body.a = alpha
	ci.draw_rect(Rect2(-5, 2, 10, 3), Color(0, 0, 0, 0.35 * alpha))
	ci.draw_rect(Rect2(-4, -8, 8, 10), cloak)
	ci.draw_rect(Rect2(-3, -13, 6, 5), body)
	if dir.y > -0.5:
		var ex := int(round(dir.x * 1.5))
		ci.draw_rect(Rect2(-2 + ex, -11, 1, 1), Color(0.1, 0.1, 0.1, alpha))
		ci.draw_rect(Rect2(1 + ex, -11, 1, 1), Color(0.1, 0.1, 0.1, alpha))
	var spear_from := Vector2(0, -4)
	ci.draw_line(spear_from, spear_from + dir * 10, Color(1, 0.84, 0.3, alpha), 1.0)

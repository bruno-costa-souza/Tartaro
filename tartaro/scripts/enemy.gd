class_name Enemy
extends CharacterBody2D

enum Kind { SHADE, BRUTE, WISP, ARCHER, BOMBER }

static var STATS := {
	Kind.SHADE: {"hp": 3, "speed": 55.0, "damage": 8, "color": Color("4a2a66"), "radius": 5.0, "contact": 10.0, "score": 1, "xp": 1},
	Kind.BRUTE: {"hp": 7, "speed": 32.0, "damage": 12, "color": Color("7a2418"), "radius": 7.0, "contact": 12.0, "score": 2, "xp": 3},
	Kind.WISP: {"hp": 1, "speed": 92.0, "damage": 5, "color": Color("48dbfb"), "radius": 4.0, "contact": 8.0, "score": 1, "xp": 1},
	Kind.ARCHER: {"hp": 3, "speed": 42.0, "damage": 7, "color": Color("dcd3b6"), "radius": 5.0, "contact": 9.0, "score": 2, "xp": 2},
	Kind.BOMBER: {"hp": 2, "speed": 68.0, "damage": 16, "color": Color("8a4a2a"), "radius": 5.0, "contact": 0.0, "score": 1, "xp": 1},
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
var _fx: Node2D
var sprite: CharSprite
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
	_make_fx()
	_make_sprite()


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
	_update_sprite()
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
				main.sfx.play("growl", randf_range(1.15, 1.35))
			return to_player.normalized() * speed
		"windup":
			if _state_t > 0.15:
				_charge_dir = to_player.normalized()
			if _state_t <= 0.0:
				_state = "charge"
				_state_t = 0.35
				main.sfx.play("charge", randf_range(1.15, 1.3), -3.0)
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
			main.sfx.play("enemy_shot", randf_range(0.95, 1.12))
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
		if main.room.blocked(position - dir * 28.0):
			return dir.orthogonal() * speed * _side
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
		main.sfx.play("fuse", randf_range(0.95, 1.1))
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


func _make_fx() -> void:
	_fx = Node2D.new()
	_fx.material = Art.unshaded()
	_fx.z_index = 1
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func _spawn_scale() -> float:
	var s := 1.25 if elite else 1.0
	if _spawn_t > 0.0:
		s *= 1.0 - _spawn_t / 0.25
	return s


func _telegraphing() -> bool:
	return _state == "windup" or _state == "fuse" or _state == "aim"


func _draw() -> void:
	if _fx:
		_fx.queue_redraw()
	var s := _spawn_scale()
	if sprite:
		Art.soft_shadow(self, Vector2(1, 0.5), (body_radius + 4) * s, (body_radius * 0.5 + 2) * s)
		return
	var c := color
	if is_slowed():
		c = c.lerp(Color("a8e6ff"), 0.45)
	var shake := Vector2(randf_range(-0.8, 0.8), 0) if _telegraphing() else Vector2.ZERO
	Art.soft_shadow(self, Vector2(1, 0.5), (body_radius + 3) * s, (body_radius * 0.5 + 1.5) * s)
	draw_set_transform(shake, 0, Vector2(s, s))
	match kind:
		Kind.SHADE:
			var robe := PackedVector2Array()
			robe.append(Vector2(-5.5, -9))
			robe.append(Vector2(5.5, -9))
			for i in 7:
				var x := 6.0 - i * 2.0
				robe.append(Vector2(x, 1.0 + sin(_t * 9.0 + i * 1.7) * 1.4 + (i % 2) * 1.5))
			Art.vgrad_poly(self, robe, c.darkened(0.2), Color(c.darkened(0.7), 0.4))
			Art.blob(self, Vector2(0, -10), Vector2(5.2, 5.6), c, 0.6, 14)
			Art.blob(self, Vector2(0, -9.5), Vector2(3.2, 3.0), Color("0b0610"), 0.2, 12)
		Kind.BRUTE:
			Art.blob(self, Vector2(-7, -5), Vector2(3.2, 3.6), c.darkened(0.15), 0.6, 12)
			Art.blob(self, Vector2(7, -5), Vector2(3.2, 3.6), c.darkened(0.15), 0.6, 12)
			Art.blob(self, Vector2(0, -7), Vector2(7.5, 7.0), c, 0.6, 18)
			Art.blob(self, Vector2(0, -13), Vector2(4.2, 3.6), c.lightened(0.05), 0.5, 14)
			var horn := Color("e8dcc0")
			draw_colored_polygon(PackedVector2Array([Vector2(-3, -15), Vector2(-8, -20), Vector2(-5, -14)]), horn)
			draw_colored_polygon(PackedVector2Array([Vector2(3, -15), Vector2(8, -20), Vector2(5, -14)]), horn)
			Art.blob(self, Vector2(-7.5, -1), Vector2(2.6, 2.4), c.darkened(0.3), 0.5, 10)
			Art.blob(self, Vector2(7.5, -1), Vector2(2.6, 2.4), c.darkened(0.3), 0.5, 10)
		Kind.WISP:
			pass
		Kind.ARCHER:
			var bone := c
			Art.limb(self, Vector2(-1.5, -4), Vector2(-2, 0), 1.4, bone.darkened(0.2))
			Art.limb(self, Vector2(1.5, -4), Vector2(2, 0), 1.4, bone.darkened(0.2))
			draw_line(Vector2(0, -10), Vector2(0, -3), bone.darkened(0.25), 1.4, true)
			for i in 3:
				var yy := -9.0 + i * 2.0
				draw_arc(Vector2(0, yy), 2.6 - i * 0.3, 0.2, PI - 0.2, 6, bone, 1.0, true)
			Art.sphere(self, Vector2(0, -13), 3.4, bone, 0.5)
			draw_circle(Vector2(-1.2, -13), 0.9, Color("120c08"))
			draw_circle(Vector2(1.2, -13), 0.9, Color("120c08"))
			var aim_dir := (target.position - position).normalized() if target else Vector2.DOWN
			var bow_c := Vector2(0, -8) + aim_dir * 4.0
			draw_arc(bow_c, 6.0, aim_dir.angle() - 1.1, aim_dir.angle() + 1.1, 10, Color("6b4a2a"), 1.4, true)
		Kind.BOMBER:
			var swell := 1.0 + (0.12 * sin(_t * 30.0) if _state == "fuse" else 0.0)
			Art.blob(self, Vector2(0, -5), Vector2(5.8, 5.4) * swell, c, 0.6, 16)
			Art.blob(self, Vector2(0, -10.5), Vector2(2.8, 2.4), c.darkened(0.2), 0.5, 10)
			draw_line(Vector2(0, -12), Vector2(1.5, -15), Color("2d2320"), 1.2, true)
	draw_set_transform(Vector2.ZERO)


func _draw_fx() -> void:
	var s := _spawn_scale()
	var shake := Vector2(randf_range(-0.8, 0.8), 0) if _telegraphing() else Vector2.ZERO
	_fx.draw_set_transform(shake, 0, Vector2(s, s))
	var alert := _telegraphing() and int(_t * 16) % 2 == 0
	if sprite:
		_sprite_telegraphs(alert)
	else:
		match kind:
			Kind.SHADE:
				var eye := Art.hdr(Color("ff3b3b"), 2.2)
				_fx.draw_circle(Vector2(-1.3, -10), 0.8, eye)
				_fx.draw_circle(Vector2(1.3, -10), 0.8, eye)
				Art.glow(_fx, Vector2(0, -10), 6.0, Color("ff3b3b"), 0.6)
			Kind.BRUTE:
				var eye := Art.hdr(Color("ffd84a"), 2.0)
				_fx.draw_circle(Vector2(-1.5, -13), 0.8, eye)
				_fx.draw_circle(Vector2(1.5, -13), 0.8, eye)
				if _state == "windup" or _state == "charge":
					Art.glow(_fx, Vector2(0, -7), 16.0, Color("ff3b1f"), 1.2 if alert else 0.7)
			Kind.WISP:
				var tail := -velocity.normalized() * 5.0 if velocity.length() > 1.0 else Vector2(0, 3)
				Art.glow(_fx, Vector2(0, -5), 9.0, color, 0.8)
				Art.limb(_fx, Vector2(0, -5), Vector2(0, -5) + tail, 3.0, Art.hdr(color, 0.9))
				Art.blob(_fx, Vector2(0, -5), Vector2(3.4, 3.8), Art.hdr(color, 1.5), 0.2, 12)
				_fx.draw_circle(Vector2(0, -5.5), 1.6, Art.hdr(Color.WHITE, 2.5))
			Kind.ARCHER:
				var eye := Art.hdr(Color("9be36d"), 2.4 if alert else 1.6)
				_fx.draw_circle(Vector2(-1.2, -13), 0.6, eye)
				_fx.draw_circle(Vector2(1.2, -13), 0.6, eye)
				if _state == "aim":
					var aim_dir := (target.position - position).normalized()
					Art.glow(_fx, Vector2(0, -8) + aim_dir * 7.0, 7.0, Color("9be36d"), 1.6)
			Kind.BOMBER:
				var heat := 1.0 + (0.6 * absf(sin(_t * 18.0)) if _state == "fuse" else 0.0)
				for a in [0.4, 2.0, 3.6, 5.0]:
					var p := Vector2(0, -5) + Vector2.from_angle(a + _t * 0.5) * 3.2
					_fx.draw_line(Vector2(0, -5), p, Art.hdr(Color("ff8c3a"), 1.6 * heat), 0.9, true)
				_fx.draw_circle(Vector2(1.5, -15.5), 1.2, Art.hdr(Color("ffd84a"), 3.0))
				if _state == "fuse":
					Art.glow(_fx, Vector2(0, -5), 22.0 * heat, Color("ff6a1f"), 1.0)
	if elite:
		var gold := Color("ffd84a")
		_fx.draw_set_transform(shake, 0, Vector2(s, s * 0.42))
		_fx.draw_arc(Vector2(0, 2), body_radius + 4.0, 0, TAU, 28, Color(Art.hdr(gold, 1.1), 0.75), 1.3, true)
		_fx.draw_set_transform(shake, 0, Vector2(s, s))
		Art.glow(_fx, Vector2(0, -body_radius), body_radius + 5.0, gold, 0.18)
	if _burn_t > 0.0:
		for i in 3:
			var fp := Vector2(sin(_t * 7.0 + i * 2.0) * 3.0, -body_radius * 2.0 - 2.0 - fmod(_t * 14.0 + i * 3.0, 6.0))
			_fx.draw_circle(fp, 1.0, Art.hdr(Color("ff8c3a"), 2.0))
	if is_slowed():
		Art.glow(_fx, Vector2(0, -body_radius), body_radius + 4.0, Color("a8e6ff"), 0.4)
	if _flash > 0.0 and sprite == null:
		Art.blob(_fx, Vector2(0, -body_radius), Vector2(body_radius + 1.5, body_radius + 2.0), Art.hdr(Color.WHITE, 1.6), 0.1, 14)
	_fx.draw_set_transform(Vector2.ZERO)

	if hp < max_hp and hp > 0:
		var w := 14.0
		var y := -body_radius * 2.0 - 9.0 - (3.0 if elite else 0.0)
		if sprite:
			y = -sprite.height * (1.25 if elite else 1.0) - 3.0
		_fx.draw_rect(Rect2(-w / 2 - 0.5, y - 0.5, w + 1, 3), Color(0, 0, 0, 0.7))
		_fx.draw_rect(Rect2(-w / 2, y, w * float(hp) / max_hp, 2), Color("ff4757"))


const ART := {
	Kind.SHADE: ["shade", 24.0], Kind.BRUTE: ["brute", 31.0], Kind.WISP: ["wisp", 16.0],
	Kind.ARCHER: ["archer", 27.0], Kind.BOMBER: ["bomber", 20.0],
}


func _make_sprite() -> void:
	var art: Array = ART[kind]
	if not CharSprite.available(art[0]):
		return
	sprite = CharSprite.new()
	add_child(sprite)
	sprite.setup(art[0], float(art[1]) * (1.25 if elite else 1.0))
	move_child(sprite, 0)


func _sprite_attacking() -> bool:
	var close := target != null and position.distance_to(target.position) < 28.0
	match kind:
		Kind.BRUTE:
			return _state == "windup" or _state == "charge"
		Kind.ARCHER:
			return _state == "aim"
		Kind.BOMBER:
			return _state == "fuse"
	return close


func _update_sprite() -> void:
	if sprite == null:
		return
	var s := _spawn_scale() / (1.25 if elite else 1.0)
	sprite.scale = Vector2.ONE * sprite.base_scale * s
	var to_player := (target.position - position) if target else Vector2.DOWN
	var facing := velocity if velocity.length() > 8.0 else to_player
	if _state == "charge":
		facing = _charge_dir
	if _sprite_attacking():
		sprite.show_state("attack", to_player if _state != "charge" else _charge_dir)
	else:
		sprite.show_state("move", facing, clampf(velocity.length() / maxf(speed, 1.0), 0.5, 1.6))
	sprite.position.x = randf_range(-0.8, 0.8) if _telegraphing() else 0.0
	var tint := Color.WHITE
	if is_slowed():
		tint = Color(0.7, 0.85, 1.1)
	if _flash > 0.0:
		tint = Color(2.4, 2.4, 2.4)
	sprite.modulate = tint


func _sprite_telegraphs(alert: bool) -> void:
	var h := sprite.height * (1.25 if elite else 1.0)
	match kind:
		Kind.BRUTE:
			if _state == "windup" or _state == "charge":
				Art.glow(_fx, Vector2(0, -h * 0.45), h * 0.6, Color("ff3b1f"), 1.2 if alert else 0.7)
		Kind.ARCHER:
			if _state == "aim":
				var aim_dir := (target.position - position).normalized()
				Art.glow(_fx, Vector2(0, -h * 0.5) + aim_dir * 8.0, 7.0, Color("9be36d"), 1.6)
		Kind.BOMBER:
			if _state == "fuse":
				var heat := 1.0 + 0.6 * absf(sin(_t * 18.0))
				Art.glow(_fx, Vector2(0, -h * 0.4), 22.0 * heat, Color("ff6a1f"), 1.0)
		Kind.WISP:
			Art.glow(_fx, Vector2(0, -h * 0.55), 9.0, color, 0.45)

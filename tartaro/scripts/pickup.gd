class_name Pickup
extends Node2D

enum Type { XP, COIN }

var type := Type.XP
var value := 1
var game: Node

var _vel := Vector2.ZERO
var _attracted := false
var _t := 0.0


func _ready() -> void:
	add_to_group("pickups")
	material = Art.unshaded()
	_vel = Vector2.from_angle(randf() * TAU) * randf_range(30, 80)


func attract() -> void:
	_attracted = true


func _physics_process(delta: float) -> void:
	_t += delta
	var p: Player = game.player
	if p.is_dead:
		return
	var to := p.position + Vector2(0, -5) - position
	var d := to.length()
	if not _attracted and _t > 0.3 and d < game.pickup_radius():
		_attracted = true
	if _attracted:
		_vel = _vel.move_toward(to.normalized() * 280.0, 1100.0 * delta)
		if d < 8.0:
			game.collect(self)
			queue_free()
			return
	else:
		_vel = _vel.move_toward(Vector2.ZERO, 140.0 * delta)
	position += _vel * delta
	queue_redraw()


func _draw() -> void:
	var bob := Vector2(0, sin(_t * 6.0) * 1.2)
	if type == Type.XP:
		var r := 2.2 if value <= 1 else 3.2
		var soul := Color("5ff7ff")
		Art.glow(self, bob, r * 2.6, soul, 0.6)
		Art.blob(self, bob, Vector2(r, r * 1.25), Art.hdr(soul, 1.2), 0.2, 12)
		draw_circle(bob + Vector2(-0.4, -0.6), r * 0.4, Art.hdr(Color.WHITE, 2.4))
	else:
		var spin := absf(cos(_t * 4.0)) * 0.7 + 0.3
		Art.glow(self, bob, 7.0, Color("ffd84a"), 0.35)
		Art.blob(self, bob, Vector2(3.2 * spin, 3.2), Color("e3a92b"), 0.5, 12)
		Art.blob(self, bob, Vector2(2.1 * spin, 2.1), Color("ffd84a"), 0.4, 10)
		if fmod(_t, 1.3) < 0.15:
			draw_circle(bob + Vector2(-1, -1.5), 0.8, Art.hdr(Color.WHITE, 3.0))

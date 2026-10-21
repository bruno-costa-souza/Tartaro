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
	var bob := Vector2(0, roundf(sin(_t * 6.0) * 1.0))
	if type == Type.XP:
		var s := 2.0 if value <= 1 else 3.0
		var pts := PackedVector2Array([bob + Vector2(0, -s - 1), bob + Vector2(s, 0), bob + Vector2(0, s + 1), bob + Vector2(-s, 0)])
		draw_colored_polygon(pts, Color("5ff7ff"))
		draw_rect(Rect2(bob + Vector2(-1, -1), Vector2(1, 1)), Color.WHITE)
	else:
		draw_circle(bob, 3.0, Color("b8860b"))
		draw_circle(bob, 2.0, Color("ffd84a"))
		draw_rect(Rect2(bob + Vector2(-1, -2), Vector2(1, 1)), Color.WHITE)

class_name EnemyBullet
extends Node2D

var game: Node
var vel := Vector2.ZERO
var damage := 8
var radius := 3.0
var color := Color("ff7f50")
var petrify := false

var _life := 5.0


func _physics_process(delta: float) -> void:
	_life -= delta
	position += vel * delta
	if _life <= 0.0 or game.room.blocked(position):
		queue_free()
		return
	var p: Player = game.player
	if p.can_be_hit() and position.distance_to(p.position + Vector2(0, -5)) < radius + 4.0:
		p.take_damage(damage, position)
		if petrify:
			p.apply_slow(1.2)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 1.0, color.darkened(0.55))
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, radius * 0.4, Color.WHITE)

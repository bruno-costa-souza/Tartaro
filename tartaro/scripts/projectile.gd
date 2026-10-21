class_name Projectile
extends Node2D

const LIFETIME := 0.65
const HIT_RADIUS := 10.0
const BOUNCE_RANGE := 120.0

var game: Node
var dir := Vector2.UP
var speed := 330.0
var damage := 1
var pierce := 0
var bounces := 0
var color := Color(1, 0.85, 0.3)

var _life := LIFETIME
var _hit: Array = []


func _physics_process(delta: float) -> void:
	_life -= delta
	position += dir * speed * delta
	if game.room.blocked(position):
		queue_free()
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e in _hit or e.is_spawning() or e.hp <= 0:
			continue
		if position.distance_to(e.position + Vector2(0, -4)) < HIT_RADIUS + e.body_radius - 4.0:
			_hit.append(e)
			game.damage_enemy(e, damage, dir)
			if pierce > 0:
				pierce -= 1
			elif bounces > 0:
				var next: Node2D = game.nearest_enemy(position, BOUNCE_RANGE, _hit)
				if next == null:
					queue_free()
					return
				bounces -= 1
				dir = (next.position + Vector2(0, -4) - position).normalized()
				_life = LIFETIME
			else:
				queue_free()
				return
			break
	if _life <= 0.0:
		queue_free()
	queue_redraw()


func _ready() -> void:
	material = Art.unshaded()


func _draw() -> void:
	Art.glow(self, Vector2.ZERO, 8.0, color, 0.7)
	draw_line(-dir * 11.0, Vector2.ZERO, Art.hdr(Color(color, 0.35), 1.3), 3.0, true)
	draw_line(-dir * 5.0, dir * 1.5, Art.hdr(color.lightened(0.45), 2.4), 1.6, true)

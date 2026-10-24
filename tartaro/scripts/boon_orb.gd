class_name BoonOrb
extends Node2D

signal taken

const TOUCH_RADIUS := 20.0

var god := "olimpo"
var color := Color("ffd84a")
var player: Node2D

var _t := 0.0
var _done := false
var _hum: AudioStreamPlayer2D


func _ready() -> void:
	material = Art.unshaded()
	var light := Art.make_light(color, 1.5, 130.0)
	light.position = Vector2(0, -14)
	add_child(light)

	var sparks := CPUParticles2D.new()
	sparks.material = Art.additive()
	sparks.position = Vector2(0, -6)
	sparks.amount = 18
	sparks.lifetime = 1.4
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 9.0
	sparks.direction = Vector2.UP
	sparks.spread = 25.0
	sparks.gravity = Vector2(0, -18)
	sparks.initial_velocity_min = 4.0
	sparks.initial_velocity_max = 14.0
	sparks.scale_amount_min = 0.8
	sparks.scale_amount_max = 1.6
	sparks.color = Art.hdr(color, 2.2)
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	sparks.color_ramp = ramp
	add_child(sparks)

	if Sfx.stream("orb_hum"):
		_hum = AudioStreamPlayer2D.new()
		_hum.stream = Sfx.stream("orb_hum")
		_hum.bus = "Sfx"
		_hum.volume_db = -6.0
		_hum.max_distance = 260.0
		add_child(_hum)
		_hum.play()

	scale = Vector2(0.2, 0.2)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _done or player == null:
		return
	if player.position.distance_to(position) < TOUCH_RADIUS:
		_done = true
		taken.emit()
		queue_free()


func _draw() -> void:
	var bob := Vector2(0, -16 + sin(_t * 2.4) * 2.5)
	draw_set_transform(Vector2.ZERO, 0, Vector2(1.0, 0.4))
	draw_arc(Vector2.ZERO, 14.0, 0, TAU, 40, Art.hdr(color, 1.3), 1.4, true)
	draw_arc(Vector2.ZERO, 18.0 + sin(_t * 3.0) * 2.0, 0, TAU, 40, Color(color, 0.35), 1.0, true)
	draw_set_transform(Vector2.ZERO)
	for i in 10:
		var a := _t * 0.6 + TAU * i / 10.0
		var d := Vector2.from_angle(a)
		var n := d.orthogonal()
		var len := 26.0 + 5.0 * sin(_t * 3.0 + i)
		draw_colored_polygon(PackedVector2Array([bob + n * 1.6, bob + d * len, bob - n * 1.6]), Color(color.r, color.g, color.b, 0.22))
	Art.glow(self, bob, 34.0, color, 0.9)
	draw_circle(bob, 11.0, Color(color.darkened(0.55), 0.85))
	draw_arc(bob, 11.0, 0, TAU, 40, Art.hdr(color, 1.6), 1.6, true)
	draw_circle(bob + Vector2(-3.5, -4.0), 2.6, Color(1, 1, 1, 0.35))
	if not BoonArt.draw_emblem(self, god, bob, 19.0, Color(1.25, 1.25, 1.25)):
		var emblem: String = GameData.GODS.get(god, GameData.GODS["olimpo"])["emblem"]
		UI.draw_icon(self, emblem, bob, 6.5, Art.hdr(color.lightened(0.4), 1.4))

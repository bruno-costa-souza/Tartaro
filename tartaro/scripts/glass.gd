class_name Glass
extends ColorRect

const SHADER := preload("res://shaders/glass.gdshader")

var tint := Color.WHITE
var tint_amount := 0.12
var radius := 14.0
var blur := 3.0
var refraction := 0.018
var edge_light := 1.0
var fill_parent := true

var _mat: ShaderMaterial
var _bright := 1.0
var _opacity := 1.0


static func make(t := Color.WHITE, amount := 0.12, r := 14.0) -> Glass:
	var g := Glass.new()
	g.tint = t
	g.tint_amount = amount
	g.radius = r
	return g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = fill_parent
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	apply()
	resized.connect(_sync)
	_sync()


func apply() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("tint", tint)
	_mat.set_shader_parameter("tint_amount", tint_amount)
	_mat.set_shader_parameter("radius", radius)
	_mat.set_shader_parameter("blur", blur)
	_mat.set_shader_parameter("refraction", refraction)
	_mat.set_shader_parameter("edge_light", edge_light)


func _sync() -> void:
	_mat.set_shader_parameter("size", size)


func _process(delta: float) -> void:
	var parent := get_parent() as Control
	if parent and not (parent is Container) and fill_parent:
		if position != Vector2.ZERO or size != parent.size:
			position = Vector2.ZERO
			size = parent.size
	var target_bright := 1.0
	var target_opacity := 1.0
	var btn := get_parent() as BaseButton
	if btn:
		match btn.get_draw_mode():
			BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED:
				target_bright = 1.45
			BaseButton.DRAW_DISABLED:
				target_bright = 0.7
				target_opacity = 0.55
	_bright = lerpf(_bright, target_bright, minf(delta * 18.0, 1.0))
	_opacity = lerpf(_opacity, target_opacity, minf(delta * 12.0, 1.0))
	_mat.set_shader_parameter("brightness", _bright)
	_mat.set_shader_parameter("opacity", _opacity)

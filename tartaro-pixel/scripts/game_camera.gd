class_name GameCamera
extends Camera2D

const MAX_OFFSET := 7.0

var _trauma := 0.0


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 9.0


func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _process(delta: float) -> void:
	_trauma = maxf(_trauma - delta * 2.2, 0.0)
	var s := _trauma * _trauma
	offset = (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * MAX_OFFSET * s).round()

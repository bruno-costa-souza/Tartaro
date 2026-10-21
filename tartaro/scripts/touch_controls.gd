class_name TouchControls
extends CanvasLayer

const RADIUS := 36.0
const DEADZONE := 4.0
const TAP_MS := 180
const FLICK_MIN := 12.0

var _touch_index := -1
var _origin := Vector2.ZERO
var _current := Vector2.ZERO
var _start_pos := Vector2.ZERO
var _start_ms := 0

var _dash_requested := false
var _dash_dir := Vector2.ZERO

var _canvas: Control
var _base: Glass
var _knob: Glass


func _ready() -> void:
	layer = 10
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(_canvas)
	_base = Glass.make(Color(0.8, 0.85, 1.0), 0.06, 999.0)
	_base.fill_parent = false
	_base.visible = false
	_canvas.add_child(_base)
	_knob = Glass.make(Color.WHITE, 0.25, 999.0)
	_knob.fill_parent = false
	_knob.visible = false
	_canvas.add_child(_knob)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1:
				_touch_index = event.index
				_origin = event.position
				_current = event.position
				_start_pos = event.position
				_start_ms = Time.get_ticks_msec()
			else:
				_request_dash(Vector2.ZERO)
		elif event.index == _touch_index:
			var held := Time.get_ticks_msec() - _start_ms
			if held < TAP_MS:
				var flick: Vector2 = event.position - _start_pos
				_request_dash(flick.normalized() if flick.length() > FLICK_MIN else Vector2.ZERO)
			_touch_index = -1
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_current = event.position
		var off := _current - _origin
		if off.length() > RADIUS:
			_origin = _current - off.normalized() * RADIUS
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_SHIFT:
			_request_dash(_keyboard_vector())


func _process(_delta: float) -> void:
	_on_draw()


func reset() -> void:
	_touch_index = -1
	_dash_requested = false


func get_move_vector() -> Vector2:
	if _touch_index != -1:
		var off := _current - _origin
		if off.length() < DEADZONE:
			return Vector2.ZERO
		return (off / RADIUS).limit_length(1.0)
	return _keyboard_vector()


func consume_dash() -> bool:
	var r := _dash_requested
	_dash_requested = false
	return r


func dash_direction() -> Vector2:
	return _dash_dir


func _request_dash(dir: Vector2) -> void:
	_dash_requested = true
	_dash_dir = dir


func _keyboard_vector() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1
	return v.normalized()


func _on_draw() -> void:
	var active := _touch_index != -1
	_base.visible = active
	_knob.visible = active
	if not active:
		return
	_base.position = _origin - Vector2(RADIUS, RADIUS)
	_base.size = Vector2(RADIUS, RADIUS) * 2.0
	var knob := _origin + (_current - _origin).limit_length(RADIUS)
	_knob.position = knob - Vector2(14, 14)
	_knob.size = Vector2(28, 28)

class_name TouchControls
extends CanvasLayer

## Fixed virtual joystick (its place and size come from the settings, see
## ControlsEditor). Touches that start on the stick move the hero; a quick tap
## or swipe anywhere else dashes, and so does a second finger while moving.

const RADIUS := 44.0
const KNOB := 0.46
const DEADZONE := 0.12
const GRAB := 1.7
const TAP_MS := 200
const FLICK_MIN := 12.0
const DEFAULT_POS := Vector2(0.24, 0.8)
const SIZES := [0.8, 1.0, 1.25]

var _touch_index := -1
var _current := Vector2.ZERO
var _others := {}

var _dash_requested := false
var _dash_dir := Vector2.ZERO

var _canvas: Control
var _base: Glass
var _knob: Glass
var _deco: Control
var _glow := 0.0


static func center_in(vp: Vector2) -> Vector2:
	var p: Vector2 = Save.joystick_pos
	return Vector2(vp.x * p.x, vp.y * p.y)


static func radius() -> float:
	return RADIUS * Save.joystick_scale


## Draws the stick's ring and direction marks (also used by the editor).
static func draw_stick(ci: CanvasItem, c: Vector2, r: float, active: float, knob: Vector2) -> void:
	ci.draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.22 + 0.3 * active), 1.5, true)
	ci.draw_arc(c, r * 0.62, 0, TAU, 40, Color(1, 1, 1, 0.08), 1.0, true)
	for i in 4:
		var d := Vector2.from_angle(TAU * i / 4.0 - PI / 2)
		var n := d.orthogonal()
		var tip := c + d * (r - 7.0)
		ci.draw_colored_polygon(PackedVector2Array([tip, tip - d * 6.0 + n * 5.0, tip - d * 6.0 - n * 5.0]),
			Color(1, 1, 1, 0.25 + 0.35 * active))
	if active > 0.01:
		Art.glow(ci, knob, r * 0.9, Color(1.0, 0.82, 0.45), 0.25 * active)


func _ready() -> void:
	layer = 10
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_base = Glass.make(Color(0.8, 0.85, 1.0), 0.06, 999.0)
	_base.fill_parent = false
	_canvas.add_child(_base)
	_deco = Control.new()
	_deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deco.draw.connect(func():
		var c := _center()
		draw_stick(_deco, c, radius(), _glow, _knob_pos(c)))
	_canvas.add_child(_deco)
	_knob = Glass.make(Color.WHITE, 0.25, 999.0)
	_knob.fill_parent = false
	_canvas.add_child(_knob)


func _center() -> Vector2:
	return center_in(_canvas.get_viewport_rect().size)


func _knob_pos(c: Vector2) -> Vector2:
	if _touch_index == -1:
		return c
	return c + (_current - c).limit_length(radius())


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and event.position.distance_to(_center()) <= radius() * GRAB:
				_touch_index = event.index
				_current = event.position
			elif _touch_index != -1:
				_request_dash(Vector2.ZERO)
			else:
				_others[event.index] = [event.position, Time.get_ticks_msec()]
		elif event.index == _touch_index:
			_touch_index = -1
		elif _others.has(event.index):
			var start: Array = _others[event.index]
			_others.erase(event.index)
			if Time.get_ticks_msec() - int(start[1]) < TAP_MS:
				var flick: Vector2 = event.position - start[0]
				_request_dash(flick.normalized() if flick.length() > FLICK_MIN else Vector2.ZERO)
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_current = event.position
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_SHIFT:
			_request_dash(_keyboard_vector())


func _process(delta: float) -> void:
	_glow = lerpf(_glow, 1.0 if _touch_index != -1 else 0.0, minf(delta * 14.0, 1.0))
	_on_draw()


func reset() -> void:
	_touch_index = -1
	_others.clear()
	_dash_requested = false


func get_move_vector() -> Vector2:
	if _touch_index != -1:
		var off := (_current - _center()) / radius()
		if off.length() < DEADZONE:
			return Vector2.ZERO
		return off.limit_length(1.0)
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
	var c := _center()
	var r := radius()
	var k := r * KNOB
	_base.position = c - Vector2(r, r)
	_base.size = Vector2(r, r) * 2.0
	var knob := _knob_pos(c)
	_knob.position = knob - Vector2(k, k)
	_knob.size = Vector2(k, k) * 2.0
	_canvas.modulate.a = 0.55 + 0.45 * _glow
	_canvas.visible = not ControlsEditor.editing
	_deco.queue_redraw()

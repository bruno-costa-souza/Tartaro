class_name ControlsEditor
extends Control

## Full-screen editor for the fixed joystick: touch or drag anywhere to move
## it, pick a size, then confirm. Opened from the settings sheet.

signal closed

const SIZE_NAMES := ["Pequeno", "Médio", "Grande"]

static var editing := false

var _vp := Vector2(360, 640)
var _pos := TouchControls.DEFAULT_POS
var _scale := 1.0
var _stick: Control
var _base: Glass
var _knob: Glass
var _panel: VBoxContainer
var _size_buttons: Array[Button] = []
var _t := 0.0
var _dragging := false
var _placed := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editing = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vp = get_viewport_rect().size
	_pos = Save.joystick_pos
	_scale = Save.joystick_scale

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.04, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var grid := Control.new()
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.draw.connect(func():
		var step := 30.0
		var x := step
		while x < _vp.x:
			grid.draw_line(Vector2(x, 0), Vector2(x, _vp.y), Color(1, 1, 1, 0.035), 1.0)
			x += step
		var y := step
		while y < _vp.y:
			grid.draw_line(Vector2(0, y), Vector2(_vp.x, y), Color(1, 1, 1, 0.035), 1.0)
			y += step)
	add_child(grid)

	_stick = Control.new()
	_stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick.draw.connect(_draw_stick)
	add_child(_stick)
	_base = Glass.make(Color(0.8, 0.85, 1.0), 0.1, 999.0)
	_base.fill_parent = false
	_stick.add_child(_base)
	_knob = Glass.make(Color.WHITE, 0.3, 999.0)
	_knob.fill_parent = false
	_stick.add_child(_knob)

	_panel = VBoxContainer.new()
	_panel.position = Vector2(16, 0)
	_panel.size = Vector2(_vp.x - 32, 0)
	_panel.add_theme_constant_override("separation", 8)
	add_child(_panel)
	_panel.add_child(UI.label("JOYSTICK", 22, Color("f0e2c0"), HORIZONTAL_ALIGNMENT_CENTER))
	var hint := UI.wrap_label("Toque ou arraste na tela para posicionar.\nFora do joystick, toque ou deslize para dar DASH.", 9, Color(1, 1, 1, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(hint)
	var sizes := HBoxContainer.new()
	sizes.add_theme_constant_override("separation", 8)
	for i in TouchControls.SIZES.size():
		var b := UI.button(SIZE_NAMES[i], UI.GLASS_TINT, 10)
		b.custom_minimum_size.y = 34
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			_scale = TouchControls.SIZES[i]
			_pos = _clamped(_center()) / _vp
			_refresh_sizes())
		sizes.add_child(b)
		_size_buttons.append(b)
	_panel.add_child(sizes)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var reset := UI.button("Restaurar padrão", UI.GLASS_TINT, 10)
	reset.custom_minimum_size.y = 38
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(func():
		_pos = TouchControls.DEFAULT_POS
		_scale = 1.0
		_refresh_sizes())
	row.add_child(reset)
	var done := UI.button("Pronto", Color("34c759"), 12)
	done.custom_minimum_size.y = 38
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.pressed.connect(_finish)
	row.add_child(done)
	_panel.add_child(row)
	_refresh_sizes()

	modulate.a = 0.0
	create_tween().set_ignore_time_scale(true).tween_property(self, "modulate:a", 1.0, 0.18)


func _exit_tree() -> void:
	editing = false


func _refresh_sizes() -> void:
	for i in _size_buttons.size():
		var on: bool = is_equal_approx(_scale, TouchControls.SIZES[i])
		var g: Glass = _size_buttons[i].get_child(0)
		g.tint = UI.GOLD if on else UI.GLASS_TINT
		g.tint_amount = 0.4 if on else 0.2
		g.apply()


func _radius() -> float:
	return TouchControls.RADIUS * _scale


func _center() -> Vector2:
	return Vector2(_vp.x * _pos.x, _vp.y * _pos.y)


func _clamped(p: Vector2) -> Vector2:
	var r := _radius() + 10.0
	var top := UI.safe_top(_vp.x) + r
	var bottom := _vp.y - UI.safe_bottom(_vp.x) - r
	return Vector2(clampf(p.x, r, _vp.x - r), clampf(p.y, top, bottom))


func _gui_input(event: InputEvent) -> void:
	var p := Vector2.INF
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			p = event.position
	elif event is InputEventMouseMotion and _dragging:
		p = event.position
	elif event is InputEventScreenTouch:
		_dragging = event.pressed
		if event.pressed:
			p = event.position
	elif event is InputEventScreenDrag:
		p = event.position
	if p != Vector2.INF:
		_pos = _clamped(p) / _vp
		accept_event()


func _process(delta: float) -> void:
	_t += delta
	var c := _center()
	var r := _radius()
	var k := r * TouchControls.KNOB
	_base.position = c - Vector2(r, r)
	_base.size = Vector2(r, r) * 2.0
	var wobble := Vector2(cos(_t * 2.2), sin(_t * 2.2)) * r * 0.35 * (0.0 if _dragging else 1.0)
	_knob.position = c + wobble - Vector2(k, k)
	_knob.size = Vector2(k, k) * 2.0
	_stick.queue_redraw()
	var panel_h := _panel.get_combined_minimum_size().y
	var top := UI.safe_top(_vp.x) + 14.0
	var low := _vp.y - UI.safe_bottom(_vp.x) - panel_h - 14.0
	var target := top if c.y > _vp.y * 0.5 else low
	_panel.position.y = lerpf(_panel.position.y, target, minf(delta * 10.0, 1.0)) if _placed else target
	_placed = true


func _draw_stick() -> void:
	var c := _center()
	var r := _radius()
	TouchControls.draw_stick(_stick, c, r, 1.0, c)
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	var dashes := 28
	for i in dashes:
		if i % 2 == 0:
			var a0 := TAU * i / dashes + _t * 0.4
			_stick.draw_arc(c, r * 1.7, a0, a0 + TAU / dashes, 4, Color(UI.GOLD, 0.35 + 0.35 * pulse), 1.5, true)
	var label_y := r * 1.7 + 16.0 if c.y < _vp.y * 0.72 else -r * 1.7 - 8.0
	_stick.draw_string(UI.title_font(), c + Vector2(-60, label_y), "ARRASTE", HORIZONTAL_ALIGNMENT_CENTER, 120, 10, Color(UI.GOLD, 0.8))


func _finish() -> void:
	Save.joystick_pos = _pos
	Save.joystick_scale = _scale
	Save.save_data()
	closed.emit()
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(queue_free)

class_name Room
extends Node2D

signal door_entered(reward: String)

const WALL := 16.0
const DOOR_W := 34.0
const BACK_WALL_H := 30.0

const FLOOR_SHADER := preload("res://shaders/floor.gdshader")
const HAZARD_SHADER := preload("res://shaders/hazard.gdshader")

var size := Vector2(360, 960)
var biome: Dictionary
var pillars: Array[Rect2] = []
var hazards: Array = []
var doors: Array = []
var doors_open := false
var player: Node2D

var _deco: Array = []
var _props: Array = []
var _seed := 0.0
var _entered := false
var _door_x: Array[float] = []
var _door_nodes: Array[Node2D] = []


func generate(rng: RandomNumberGenerator, biome_data: Dictionary, is_boss: bool) -> void:
	biome = biome_data
	_seed = rng.randf() * 100.0
	if is_boss:
		size = Vector2(400, 780)
		for p in [Vector2(0.25, 0.42), Vector2(0.75, 0.42), Vector2(0.25, 0.68), Vector2(0.75, 0.68)]:
			pillars.append(Rect2(Vector2(size.x * p.x - 12, size.y * p.y - 12), Vector2(24, 24)))
	else:
		size = Vector2(360 + rng.randi_range(0, 3) * 40, 720 + rng.randi_range(0, 5) * 80)
		var want := rng.randi_range(2, 6)
		var tries := 0
		while pillars.size() < want and tries < 80:
			tries += 1
			var w := rng.randi_range(2, 4) * 8.0
			var h := rng.randi_range(2, 4) * 8.0
			var r := Rect2(
				snappedf(rng.randf_range(WALL + 30, size.x - WALL - 30 - w), 8.0),
				snappedf(rng.randf_range(WALL + 90, size.y - WALL - 150 - h), 8.0), w, h)
			if _overlaps(r.grow(36)):
				continue
			pillars.append(r)
		if biome["hazard"].a > 0.0:
			var count := rng.randi_range(1, 3)
			for i in count:
				var pos := Vector2(rng.randf_range(60, size.x - 60), rng.randf_range(120, size.y - 200))
				var radius := rng.randf_range(18, 32)
				if not _overlaps(Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2).grow(10)):
					hazards.append({"pos": pos, "radius": radius})

	for i in int(size.x * size.y / 2600):
		_deco.append({
			"pos": Vector2(rng.randf_range(WALL + 6, size.x - WALL - 6), rng.randf_range(BACK_WALL_H + 6, size.y - WALL - 6)),
			"s": rng.randf_range(0.6, 1.4),
			"kind": rng.randi() % 3,
		})
	_door_x = [size.x / 3.0, size.x * 2.0 / 3.0]
	_place_props(rng, is_boss)
	_build_floor()
	_build_hazards()
	_build_collision()


func player_spawn() -> Vector2:
	return Vector2(size.x / 2, size.y - 60)


func _overlaps(r: Rect2) -> bool:
	for p in pillars:
		if p.intersects(r):
			return true
	return false


func _build_floor() -> void:
	var floor_rect := ColorRect.new()
	floor_rect.size = size
	floor_rect.show_behind_parent = true
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = FLOOR_SHADER
	mat.set_shader_parameter("color_a", biome["floor_a"])
	mat.set_shader_parameter("color_b", biome["floor_b"])
	mat.set_shader_parameter("grout", biome["grout"])
	mat.set_shader_parameter("inlay", biome["inlay"])
	mat.set_shader_parameter("room_size", size)
	mat.set_shader_parameter("seed", _seed)
	floor_rect.material = mat
	add_child(floor_rect)


func _build_hazards() -> void:
	for h in hazards:
		var r: float = h["radius"]
		var pool := ColorRect.new()
		pool.position = h["pos"] - Vector2(r, r)
		pool.size = Vector2(r, r) * 2.0
		pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = HAZARD_SHADER
		mat.set_shader_parameter("hot", biome["hazard_hot"])
		mat.set_shader_parameter("cool", biome["hazard_cool"])
		mat.set_shader_parameter("seed", randf() * 10.0)
		pool.material = mat
		add_child(pool)
		var light := Art.make_light(biome["hazard"], 0.9, r * 3.0)
		light.position = h["pos"]
		add_child(light)


func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var rects: Array[Rect2] = [
		Rect2(0, 0, size.x, WALL),
		Rect2(0, size.y - WALL, size.x, WALL),
		Rect2(0, 0, WALL, size.y),
		Rect2(size.x - WALL, 0, WALL, size.y),
	]
	rects.append_array(pillars)
	for r in rects:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		body.add_child(shape)
	add_child(body)

	for r in pillars:
		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		var g := r.grow(-2)
		poly.polygon = PackedVector2Array([g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)])
		occ.occluder = poly
		add_child(occ)


func _place_props(rng: RandomNumberGenerator, is_boss: bool) -> void:
	var want := rng.randi_range(7, 12) if not is_boss else 8
	var tries := 0
	while _props.size() < want and tries < 120:
		tries += 1
		var side := rng.randi() % 4
		var inset := rng.randf_range(WALL + 12, WALL + 34)
		var p := Vector2.ZERO
		match side:
			0:
				p = Vector2(rng.randf_range(WALL + 14, size.x - WALL - 14), BACK_WALL_H + inset - WALL + 8)
			1:
				p = Vector2(rng.randf_range(WALL + 14, size.x - WALL - 14), size.y - inset)
			2:
				p = Vector2(inset, rng.randf_range(BACK_WALL_H + 30, size.y - WALL - 20))
			3:
				p = Vector2(size.x - inset, rng.randf_range(BACK_WALL_H + 30, size.y - WALL - 20))
		var kind := Decor.pick(biome["name"], rng)
		if side == 0 and (absf(p.x - _door_x[0]) < 34 or absf(p.x - _door_x[1]) < 34):
			continue
		if p.distance_to(player_spawn()) < 70.0 or _overlaps(Rect2(p - Vector2(10, 16), Vector2(20, 18)).grow(10)):
			continue
		var clash := false
		for o in _props:
			if p.distance_to(o["pos"]) < 26.0:
				clash = true
		for h in hazards:
			if p.distance_to(h["pos"]) < h["radius"] + 14.0:
				clash = true
		if not clash:
			_props.append({"pos": p, "kind": kind})


func build_props(world: Node2D) -> void:
	for d in _props:
		var prop := Decor.new()
		prop.kind = d["kind"]
		prop.stone = biome["pillar"]
		prop.position = d["pos"]
		world.add_child(prop)
	var stone: Color = biome["pillar"]
	for r in pillars:
		var prop := Node2D.new()
		prop.position = Vector2(r.get_center().x, r.end.y)
		var rect := Rect2(r.position - prop.position, r.size)
		prop.draw.connect(_draw_pillar.bind(prop, rect, stone))
		world.add_child(prop)

	var y := 150.0
	var left := true
	while y < size.y - 100.0:
		var b := Brazier.new()
		b.position = Vector2(WALL + 7 if left else size.x - WALL - 7, y)
		b.flame = biome["torch"]
		world.add_child(b)
		y += 230.0
		left = not left


func _draw_pillar(n: Node2D, r: Rect2, stone: Color) -> void:
	var w := r.size.x
	var d := r.size.y
	Art.soft_shadow(n, Vector2(r.get_center().x + 7, r.get_center().y + 3), w * 0.9, d * 0.8, 0.9)
	var square := absf(w - d) <= 8.0
	if not square:
		var hgt := 16.0
		n.draw_rect(Rect2(r.position.x, r.position.y - hgt, w, d), stone.lightened(0.05))
		n.draw_rect(Rect2(r.position.x, r.position.y - hgt, w, 2), stone.lightened(0.25))
		Art.vgrad_poly(n, PackedVector2Array([
			Vector2(r.position.x, r.end.y - hgt), Vector2(r.end.x, r.end.y - hgt),
			Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]), stone.darkened(0.25), stone.darkened(0.6))
		for i in range(1, int(w / 10.0)):
			var x := r.position.x + i * 10.0
			n.draw_line(Vector2(x, r.end.y - hgt), Vector2(x, r.end.y), stone.darkened(0.7), 1.0)
		return
	var h := 30.0 + w * 0.9
	var cx := r.get_center().x
	var sw := w * 0.6
	var shaft_top := r.end.y - h
	n.draw_rect(Rect2(r.position.x, r.end.y - 6, w, 6), stone.darkened(0.45))
	n.draw_rect(Rect2(r.position.x, r.end.y - 9, w, 3), stone.darkened(0.1))
	Art.cylinder(n, Rect2(cx - sw / 2, shaft_top, sw, h - 9), stone)
	for i in 3:
		var fx := cx - sw / 2 + sw * (i + 1) / 4.0
		n.draw_line(Vector2(fx, shaft_top + 2), Vector2(fx, r.end.y - 10), Color(stone.darkened(0.35), 0.55), 1.0)
	n.draw_rect(Rect2(r.position.x - 1, shaft_top - 7, w + 2, 7), stone.darkened(0.15))
	n.draw_rect(Rect2(r.position.x - 1, shaft_top - 9, w + 2, 3), stone.lightened(0.25))
	n.draw_rect(Rect2(cx - sw / 2 - 2, shaft_top - 1, sw + 4, 2), stone.darkened(0.4))


func blocked(p: Vector2) -> bool:
	if p.x < WALL or p.y < WALL or p.x > size.x - WALL or p.y > size.y - WALL:
		return true
	for r in pillars:
		if r.has_point(p):
			return true
	return false


func hazard_at(p: Vector2) -> bool:
	for h in hazards:
		if p.distance_to(h["pos"]) < h["radius"] - 3.0:
			return true
	return false


func open_doors(rewards: Array) -> void:
	doors.clear()
	for i in rewards.size():
		var x: float = _door_x[i] if rewards.size() == 2 else size.x / 2
		doors.append({"x": x, "reward": rewards[i]})
		var portal := Portal.new()
		portal.position = Vector2(x, WALL + 2)
		portal.info = GameData.REWARDS[rewards[i]]
		add_child(portal)
	doors_open = true
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if not doors_open or _entered or player == null:
		return
	for d in doors:
		var p := player.position
		if absf(p.x - d["x"]) < DOOR_W / 2 + 2 and p.y < WALL + 16:
			_entered = true
			door_entered.emit(d["reward"])
			return


func _draw() -> void:
	var deco: Color = biome["deco"]
	for d in _deco:
		var p: Vector2 = d["pos"]
		var s: float = d["s"]
		match d["kind"]:
			0:
				draw_colored_polygon(Art._ellipse(p, Vector2(2.2, 1.5) * s, 10), Color(biome["floor_b"]).darkened(0.35))
				draw_colored_polygon(Art._ellipse(p - Vector2(0.3, 0.4) * s, Vector2(1.4, 0.8) * s, 8), Color(biome["floor_a"]).lightened(0.05))
			1:
				draw_colored_polygon(Art._ellipse(p, Vector2(7, 3.5) * s, 12), Color(biome["grout"], 0.25))
			2:
				for k in 5:
					var a := TAU * k / 5.0
					draw_circle(p + Vector2.from_angle(a) * 1.6 * s, 1.1 * s, Color(deco, 0.75))
				draw_circle(p, 0.8 * s, Color(deco.lightened(0.3), 0.9))

	var wall: Color = biome["wall"]
	var stone: Color = biome["pillar"]
	draw_rect(Rect2(0, 0, size.x, WALL - 4), wall.darkened(0.4))
	Art.vgrad_poly(self, PackedVector2Array([
		Vector2(0, WALL - 4), Vector2(size.x, WALL - 4), Vector2(size.x, BACK_WALL_H), Vector2(0, BACK_WALL_H)]),
		stone.darkened(0.35), stone.darkened(0.7))
	var bx := 0.0
	var row := 0
	for yy in [WALL - 4, WALL + 6, WALL + 16]:
		bx = -12.0 if row % 2 == 1 else 0.0
		while bx < size.x:
			draw_line(Vector2(bx, yy), Vector2(bx, minf(yy + 10, BACK_WALL_H)), stone.darkened(0.8), 1.0)
			bx += 24.0
		draw_line(Vector2(0, yy), Vector2(size.x, yy), stone.darkened(0.75), 1.0)
		row += 1
	Art.vgrad_poly(self, PackedVector2Array([
		Vector2(0, BACK_WALL_H), Vector2(size.x, BACK_WALL_H), Vector2(size.x, BACK_WALL_H + 14), Vector2(0, BACK_WALL_H + 14)]),
		Color(0, 0, 0, 0.45), Color(0, 0, 0, 0))

	for x in _door_x:
		var r := Rect2(x - DOOR_W / 2, 2, DOOR_W, BACK_WALL_H - 2)
		draw_rect(r.grow(3), stone.darkened(0.1))
		draw_rect(Rect2(r.position.x - 3, r.position.y - 3, r.size.x + 6, 3), stone.lightened(0.3))
		Art.vgrad_poly(self, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			Color("050308"), Color("1a1424"))
		draw_circle(Vector2(x, r.position.y + 2), DOOR_W / 2, Color("050308"))
		if not doors_open:
			for i in 4:
				var bxx := r.position.x + 5 + i * 8
				draw_line(Vector2(bxx, r.position.y), Vector2(bxx, r.end.y), Color("3a3440"), 2.0)

	draw_rect(Rect2(0, 0, WALL, size.y), wall)
	draw_rect(Rect2(size.x - WALL, 0, WALL, size.y), wall)
	draw_rect(Rect2(0, size.y - WALL, size.x, WALL), wall)
	draw_line(Vector2(WALL, BACK_WALL_H), Vector2(WALL, size.y - WALL), stone.darkened(0.2), 2.0)
	draw_line(Vector2(size.x - WALL, BACK_WALL_H), Vector2(size.x - WALL, size.y - WALL), stone.darkened(0.5), 2.0)
	draw_line(Vector2(WALL, size.y - WALL), Vector2(size.x - WALL, size.y - WALL), stone.lightened(0.05), 2.0)


class Portal extends Node2D:
	var info: Dictionary
	var _t := 0.0
	var _light: PointLight2D

	func _ready() -> void:
		material = Art.unshaded()
		z_index = 5
		_light = Art.make_light(info["color"], 1.3, 90.0)
		_light.position = Vector2(0, 10)
		add_child(_light)

	func _process(delta: float) -> void:
		_t += delta
		_light.energy = 1.2 + 0.25 * sin(_t * 4.0)
		queue_redraw()

	func _draw() -> void:
		var c: Color = info["color"]
		var pulse := 0.8 + 0.2 * sin(_t * 4.0)
		Art.glow(self, Vector2(0, 4), 30.0, c, 1.2 * pulse)
		var r := Rect2(-DOOR_W / 2 + 3, -12, DOOR_W - 6, BACK_WALL_H - 6)
		draw_rect(r, Art.hdr(c, 0.9 * pulse))
		draw_circle(Vector2(0, -12), DOOR_W / 2 - 3, Art.hdr(c, 0.9 * pulse))
		for i in 6:
			var a := _t * 1.5 + TAU * i / 6.0
			draw_circle(Vector2(cos(a) * 9.0, 2 + sin(a) * 6.0), 1.2, Art.hdr(Color.WHITE, 1.8))
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(-40, BACK_WALL_H + 10), info["name"], HORIZONTAL_ALIGNMENT_CENTER, 80, 9, 4, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(-40, BACK_WALL_H + 10), info["name"], HORIZONTAL_ALIGNMENT_CENTER, 80, 9, Art.hdr(c, 1.3))


class Brazier extends Node2D:
	var flame := Color("ff8a3d")
	var light_power := 1.0
	var _t := 0.0
	var _light: PointLight2D
	var _fire: Node2D

	func _ready() -> void:
		_t = randf() * 10.0
		_light = Art.make_light(flame, 1.3, 210.0)
		_light.position = Vector2(0, -16)
		add_child(_light)
		_fire = Node2D.new()
		_fire.material = Art.additive()
		_fire.draw.connect(_draw_fire)
		add_child(_fire)
		var embers := CPUParticles2D.new()
		embers.position = Vector2(0, -16)
		embers.material = Art.additive()
		embers.amount = 10
		embers.lifetime = 1.2
		embers.direction = Vector2.UP
		embers.spread = 20.0
		embers.gravity = Vector2(0, -20)
		embers.initial_velocity_min = 8.0
		embers.initial_velocity_max = 22.0
		embers.scale_amount_min = 0.8
		embers.scale_amount_max = 1.6
		embers.color = Art.hdr(flame, 2.0)
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		embers.color_ramp = ramp
		add_child(embers)

	func _process(delta: float) -> void:
		_t += delta
		_light.energy = (1.25 + 0.15 * sin(_t * 11.0) + 0.1 * sin(_t * 23.0)) * light_power
		_fire.queue_redraw()

	func _draw() -> void:
		Art.soft_shadow(self, Vector2(2, 1), 7, 3)
		draw_line(Vector2(-4, 0), Vector2(0, -9), Color("4a3520"), 1.5)
		draw_line(Vector2(4, 0), Vector2(0, -9), Color("4a3520"), 1.5)
		Art.blob(self, Vector2(0, -11), Vector2(7, 3.5), Color("9a6a32"), 0.7, 14)
		draw_rect(Rect2(-7, -13, 14, 2), Color("c8954a"))

	func _draw_fire() -> void:
		var f := 1.0 + 0.12 * sin(_t * 13.0)
		Art.glow(_fire, Vector2(0, -17), 22.0, flame, 0.9)
		Art.blob(_fire, Vector2(0, -17), Vector2(5.0, 6.5 * f), Art.hdr(flame, 1.4), 0.2, 12)
		Art.blob(_fire, Vector2(0, -16), Vector2(2.6, 4.0 * f), Art.hdr(flame.lightened(0.6), 2.2), 0.1, 10)

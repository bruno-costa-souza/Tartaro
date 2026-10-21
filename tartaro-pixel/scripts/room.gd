class_name Room
extends Node2D

signal door_entered(reward: String)

const WALL := 16.0
const TILE := 16.0
const DOOR_W := 34.0

var size := Vector2(360, 960)
var biome: Dictionary
var pillars: Array[Rect2] = []
var hazards: Array = []
var doors: Array = []
var doors_open := false
var player: Node2D

var _deco: Array[Vector2] = []
var _t := 0.0
var _entered := false


func generate(rng: RandomNumberGenerator, biome_data: Dictionary, is_boss: bool) -> void:
	biome = biome_data
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

	for i in int(size.x * size.y / 2400):
		_deco.append(Vector2(rng.randf_range(WALL, size.x - WALL), rng.randf_range(WALL, size.y - WALL)))
	_build_collision()


func player_spawn() -> Vector2:
	return Vector2(size.x / 2, size.y - 60)


func _overlaps(r: Rect2) -> bool:
	for p in pillars:
		if p.intersects(r):
			return true
	return false


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
		var x := size.x * (float(i + 1) / (rewards.size() + 1))
		doors.append({"x": x, "reward": rewards[i]})
	doors_open = true
	queue_redraw()


func _physics_process(delta: float) -> void:
	_t += delta
	if hazards.size() > 0 or doors_open:
		queue_redraw()
	if not doors_open or _entered or player == null:
		return
	for d in doors:
		var p := player.position
		if absf(p.x - d["x"]) < DOOR_W / 2 + 2 and p.y < WALL + 16:
			_entered = true
			door_entered.emit(d["reward"])
			return


func _draw() -> void:
	var a: Color = biome["floor_a"]
	var b: Color = biome["floor_b"]
	var y := 0.0
	while y < size.y:
		var x := 0.0
		while x < size.x:
			var odd := (int(x / TILE) + int(y / TILE)) % 2 == 1
			draw_rect(Rect2(x, y, TILE, TILE), b if odd else a)
			x += TILE
		y += TILE
	for p in _deco:
		draw_rect(Rect2(p.round(), Vector2(3, 1)), biome["deco"])

	var hz: Color = biome["hazard"]
	for h in hazards:
		var pulse := 0.5 + 0.15 * sin(_t * 3.0)
		draw_circle(h["pos"], h["radius"], Color(hz.r, hz.g, hz.b, pulse * 0.6))
		draw_circle(h["pos"], h["radius"] * 0.6, Color(hz.r, hz.g, hz.b, pulse))
		draw_arc(h["pos"], h["radius"], 0, TAU, 24, hz.lightened(0.3), 1.0)

	var pc: Color = biome["pillar"]
	for r in pillars:
		draw_rect(Rect2(r.position + Vector2(0, r.size.y), Vector2(r.size.x, 4)), Color(0, 0, 0, 0.35))
		draw_rect(r, pc)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), pc.lightened(0.25))
		draw_rect(r, pc.darkened(0.4), false, 1.0)

	var wall := Color("0c0a14")
	draw_rect(Rect2(0, 0, size.x, WALL), wall)
	draw_rect(Rect2(0, size.y - WALL, size.x, WALL), wall)
	draw_rect(Rect2(0, 0, WALL, size.y), wall)
	draw_rect(Rect2(size.x - WALL, 0, WALL, size.y), wall)
	draw_rect(Rect2(WALL, WALL, size.x - WALL * 2, size.y - WALL * 2), biome["edge"], false, 1.0)

	var font := ThemeDB.fallback_font
	for d in doors:
		var info: Dictionary = GameData.REWARDS[d["reward"]]
		var c: Color = info["color"]
		var glow := 0.7 + 0.3 * sin(_t * 4.0)
		var r := Rect2(d["x"] - DOOR_W / 2, 0, DOOR_W, WALL + 2)
		draw_rect(r.grow(2), Color(c.r, c.g, c.b, 0.3 * glow))
		draw_rect(r, c.darkened(0.5))
		draw_rect(r.grow(-3), Color(c.r, c.g, c.b, glow))
		draw_string(font, Vector2(d["x"] - 30, WALL + 16), info["name"], HORIZONTAL_ALIGNMENT_CENTER, 60, 8, c)
		draw_string(font, Vector2(d["x"] - 10, WALL + 26), "^", HORIZONTAL_ALIGNMENT_CENTER, 20, 8, Color(1, 1, 1, glow))

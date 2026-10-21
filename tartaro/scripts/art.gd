class_name Art

const LIGHT_DIR := Vector2(-0.55, -0.85)

static var _shadow_tex: GradientTexture2D
static var _light_tex: GradientTexture2D
static var _unshaded: CanvasItemMaterial
static var _add: CanvasItemMaterial


static func shadow_texture() -> Texture2D:
	if _shadow_tex == null:
		_shadow_tex = _radial([Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0)], [0.0, 0.45, 1.0], 64)
	return _shadow_tex


static func light_texture() -> Texture2D:
	if _light_tex == null:
		_light_tex = _radial([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)], [0.0, 0.25, 0.6, 1.0], 256)
	return _light_tex


static func _radial(colors: Array, offsets: Array, size: int) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t


static func unshaded() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded


static func additive() -> CanvasItemMaterial:
	if _add == null:
		_add = CanvasItemMaterial.new()
		_add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add


static func make_light(color: Color, energy: float, radius: float, shadows := false) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.color = color
	l.energy = energy
	l.texture_scale = radius / 128.0
	l.shadow_enabled = shadows
	if shadows:
		l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		l.shadow_filter_smooth = 3.0
		l.shadow_color = Color(0, 0, 0, 0.75)
	return l


static func soft_shadow(ci: CanvasItem, center: Vector2, rx: float, ry: float, alpha := 1.0) -> void:
	ci.draw_texture_rect(shadow_texture(), Rect2(center - Vector2(rx, ry), Vector2(rx, ry) * 2.0), false, Color(1, 1, 1, alpha))


static func glow(ci: CanvasItem, center: Vector2, radius: float, color: Color, intensity := 1.6) -> void:
	var c := Color(color.r * intensity, color.g * intensity, color.b * intensity, color.a)
	ci.draw_texture_rect(light_texture(), Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, c)


const INK := Color("120a12")
const SHADOW_TINT := Color("2a1642")
const RIM_LIGHT := Color(0.62, 0.78, 1.0)

static var _unit_cache := {}


static func _unit(segs: int) -> PackedVector2Array:
	if not _unit_cache.has(segs):
		var pts := PackedVector2Array()
		for i in segs:
			pts.append(Vector2.from_angle(TAU * i / segs))
		_unit_cache[segs] = pts
	return _unit_cache[segs]


static func _ellipse(center: Vector2, radii: Vector2, segs: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for d in _unit(segs):
		out.append(center + Vector2(d.x * radii.x, d.y * radii.y))
	return out


static func is_glow(c: Color) -> bool:
	return c.r > 1.0 or c.g > 1.0 or c.b > 1.0 or c.a < 0.99


static func shade_color(base: Color, amount := 0.45) -> Color:
	var s := base.darkened(amount).lerp(SHADOW_TINT, 0.22)
	s.a = base.a
	return s


static func blob(ci: CanvasItem, center: Vector2, radii: Vector2, base: Color, rim := 0.5, segs := 22) -> void:
	if is_glow(base):
		ci.draw_colored_polygon(_ellipse(center, radii, segs), base)
		return
	var u := LIGHT_DIR.normalized()
	var v := u.orthogonal()
	ci.draw_colored_polygon(_ellipse(center, radii + Vector2(0.9, 0.9), segs), INK)
	ci.draw_colored_polygon(_ellipse(center, radii, segs), base)

	var half := maxi(segs / 2, 6)
	var k := 0.2
	var crescent := PackedVector2Array()
	for i in half + 1:
		var phi := PI * 0.5 + PI * i / half
		var d := u * cos(phi) + v * sin(phi)
		crescent.append(center + Vector2(d.x * radii.x, d.y * radii.y))
	for i in range(half - 1, 0, -1):
		var phi := PI * 0.5 + PI * i / half
		var d := u * (k * cos(phi)) + v * sin(phi)
		crescent.append(center + Vector2(d.x * radii.x, d.y * radii.y))
	ci.draw_colored_polygon(crescent, shade_color(base, 0.22 + 0.4 * rim))

	var hl := base.lightened(0.12 + 0.25 * rim)
	ci.draw_colored_polygon(_ellipse(center + Vector2(u.x * radii.x, u.y * radii.y) * 0.42, radii * 0.3, 10), hl)

	if radii.x > 2.5:
		var arc := PackedVector2Array()
		for i in 7:
			var phi := PI * 0.82 + PI * 0.36 * i / 6.0
			var d := u * cos(phi) + v * sin(phi)
			arc.append(center + Vector2(d.x * radii.x, d.y * radii.y) * 0.9)
		ci.draw_polyline(arc, Color(base.lerp(RIM_LIGHT, 0.55), 0.8), 0.8, true)


static func sphere(ci: CanvasItem, center: Vector2, r: float, base: Color, rim := 0.5) -> void:
	blob(ci, center, Vector2(r, r), base, rim)


static func vgrad_poly(ci: CanvasItem, pts: PackedVector2Array, top: Color, bottom: Color, ink := true) -> void:
	var min_y := INF
	var max_y := -INF
	for p in pts:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	var h := maxf(max_y - min_y, 0.001)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, (p.y - min_y) / h))
	ci.draw_polygon(pts, cols)
	if ink and not is_glow(top) and not is_glow(bottom):
		var loop := pts.duplicate()
		loop.append(pts[0])
		ci.draw_polyline(loop, INK, 0.9, true)


static func cylinder(ci: CanvasItem, r: Rect2, base: Color) -> void:
	ci.draw_rect(r.grow(0.8), INK)
	ci.draw_rect(r, base)
	ci.draw_rect(Rect2(r.position.x + r.size.x * 0.58, r.position.y, r.size.x * 0.42, r.size.y), shade_color(base, 0.4))
	ci.draw_rect(Rect2(r.position.x + r.size.x * 0.14, r.position.y, r.size.x * 0.14, r.size.y), base.lightened(0.25))
	ci.draw_line(Vector2(r.end.x - 0.8, r.position.y), Vector2(r.end.x - 0.8, r.end.y), Color(base.lerp(RIM_LIGHT, 0.5), 0.7), 0.8)


static func limb(ci: CanvasItem, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	if not is_glow(color):
		ci.draw_line(a, b, INK, width + 1.6, true)
		ci.draw_circle(a, width * 0.5 + 0.8, INK)
		ci.draw_circle(b, width * 0.5 + 0.8, INK)
	ci.draw_line(a, b, color, width, true)
	ci.draw_circle(a, width * 0.5, color)
	ci.draw_circle(b, width * 0.5, color)


static func hdr(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)

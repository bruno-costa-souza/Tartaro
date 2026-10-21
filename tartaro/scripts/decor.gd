class_name Decor
extends Node2D

const KINDS := {
	"TÁRTARO": ["amphora_broken", "skulls", "stump", "amphora", "bones", "brazier_cold"],
	"ASFÓDELO": ["flowers", "urn", "skulls", "crystal", "stump", "flowers"],
	"ELÍSIO": ["bush", "urn_gold", "statue", "flowers_gold", "stump", "bush"],
}

var kind := "amphora"
var stone := Color("6e6584")
var _t := 0.0
var _glow: Node2D


static func pick(biome_name: String, rng: RandomNumberGenerator) -> String:
	var list: Array = KINDS.get(biome_name, KINDS["TÁRTARO"])
	return list[rng.randi() % list.size()]


func _ready() -> void:
	_t = randf() * 10.0
	if kind == "crystal":
		_glow = Node2D.new()
		_glow.material = Art.unshaded()
		_glow.draw.connect(_draw_crystal_glow)
		add_child(_glow)
		var light := Art.make_light(Color("7dffb0"), 0.8, 70.0)
		light.position = Vector2(0, -8)
		add_child(light)
	if kind.begins_with("flowers") or kind == "bush" or kind == "crystal":
		set_process(true)
	else:
		set_process(false)


func _process(delta: float) -> void:
	_t += delta
	if _glow:
		_glow.queue_redraw()
	elif int(_t * 10.0) % 3 == 0:
		queue_redraw()


func _draw() -> void:
	match kind:
		"amphora", "amphora_broken":
			_amphora(Color("b8643a"), kind == "amphora_broken")
		"urn":
			_amphora(Color("8a8a78"), false, 1.2)
		"urn_gold":
			_amphora(Color("d9a63a"), false, 1.2)
		"skulls":
			Art.soft_shadow(self, Vector2(0, 0), 9, 3)
			for p in [Vector2(-4, -2), Vector2(3, -1.5), Vector2(-0.5, -5.5)]:
				Art.sphere(self, p, 2.6, Color("e3d7bd"), 0.5)
				draw_circle(p + Vector2(-0.9, 0.3), 0.55, Art.INK)
				draw_circle(p + Vector2(0.9, 0.3), 0.55, Art.INK)
		"bones":
			Art.limb(self, Vector2(-6, -1), Vector2(5, -3), 1.4, Color("d9ccb0"))
			Art.limb(self, Vector2(-3, -4), Vector2(4, 1), 1.2, Color("cfc2a6"))
			Art.sphere(self, Vector2(6.5, -3.5), 2.2, Color("e3d7bd"), 0.5)
		"stump":
			Art.soft_shadow(self, Vector2(3, 0), 9, 3.5)
			Art.cylinder(self, Rect2(-6, -11, 12, 11), stone)
			var top := PackedVector2Array([Vector2(-6, -11), Vector2(-3, -14), Vector2(0, -12), Vector2(3, -15), Vector2(6, -11)])
			draw_colored_polygon(top, stone.lightened(0.15))
			draw_polyline(top, Art.INK, 0.9, true)
			Art.blob(self, Vector2(10, -1), Vector2(3, 2), stone.darkened(0.1), 0.5, 10)
		"brazier_cold":
			Art.soft_shadow(self, Vector2(1, 0), 7, 3)
			Art.limb(self, Vector2(-3, 0), Vector2(0, -7), 1.2, Color("4a3520"))
			Art.limb(self, Vector2(3, 0), Vector2(0, -7), 1.2, Color("4a3520"))
			Art.blob(self, Vector2(0, -9), Vector2(6, 3), Color("6a5a4a"), 0.6, 14)
			Art.blob(self, Vector2(0, -10), Vector2(4, 1.4), Color("2a2220"), 0.2, 10)
		"flowers", "flowers_gold":
			var petal := Color("eef2e2") if kind == "flowers" else Color("f2cf5a")
			for i in 5:
				var base := Vector2(-6 + i * 3.0, 0)
				var sway := sin(_t * 1.6 + i) * 1.2
				var tip := base + Vector2(sway, -7 - (i % 2) * 3.0)
				draw_line(base, tip, Color("5d7a3a"), 1.0, true)
				for k in 5:
					draw_circle(tip + Vector2.from_angle(TAU * k / 5.0) * 1.3, 0.9, petal)
				draw_circle(tip, 0.6, Color("d98a2a"))
		"crystal":
			Art.soft_shadow(self, Vector2(0, 0), 8, 3)
			for c in [[Vector2(-3, 0), 9.0, -0.25], [Vector2(2, 0), 13.0, 0.1], [Vector2(5, 0), 7.0, 0.35]]:
				var p: Vector2 = c[0]
				var h: float = c[1]
				var lean: float = c[2]
				var tip := p + Vector2(lean * h, -h)
				var pts := PackedVector2Array([p + Vector2(-2, 0), tip + Vector2(-1, 2), tip, tip + Vector2(1, 2), p + Vector2(2, 0)])
				draw_colored_polygon(pts, Color("2f8a5a"))
				draw_colored_polygon(PackedVector2Array([p + Vector2(-2, 0), tip + Vector2(-1, 2), tip, p]), Color("5fd498"))
				var loop := pts.duplicate()
				loop.append(pts[0])
				draw_polyline(loop, Art.INK, 0.9, true)
		"bush":
			Art.soft_shadow(self, Vector2(1, 0), 10, 3.5)
			var green := Color("4f7a34")
			var sway := sin(_t * 1.2) * 0.6
			Art.blob(self, Vector2(-4 + sway, -5), Vector2(5, 4.5), green.darkened(0.1), 0.6, 14)
			Art.blob(self, Vector2(4 + sway, -5), Vector2(5, 4.5), green.darkened(0.05), 0.6, 14)
			Art.blob(self, Vector2(sway, -9), Vector2(5.5, 4.5), green, 0.6, 14)
			for b in [Vector2(-5, -7), Vector2(2, -11), Vector2(5, -5), Vector2(-1, -4)]:
				draw_circle(b + Vector2(sway, 0), 1.0, Color("ffd84a"))
		"statue":
			Art.soft_shadow(self, Vector2(3, 0), 10, 3.5)
			var marble := Color("ece6d6")
			draw_rect(Rect2(-7, -8, 14, 8).grow(0.8), Art.INK)
			draw_rect(Rect2(-7, -8, 14, 8), marble.darkened(0.15))
			draw_rect(Rect2(1, -8, 6, 8), Art.shade_color(marble, 0.4))
			Art.blob(self, Vector2(0, -12), Vector2(6.5, 4), marble, 0.5, 16)
			Art.sphere(self, Vector2(0, -19), 3.8, marble, 0.5)
			draw_arc(Vector2(0, -20), 3.8, PI * 1.05, TAU * 0.97, 10, Color("8fae3c"), 1.2, true)


func _amphora(c: Color, broken: bool, girth := 1.0) -> void:
	Art.soft_shadow(self, Vector2(2, 0), 7 * girth, 3)
	Art.blob(self, Vector2(0, -6), Vector2(4.6, 6.0) * Vector2(girth, 1.0), c, 0.6, 18)
	draw_rect(Rect2(-4.2 * girth, -7.5, 8.4 * girth, 2.2), Color("1d1410"))
	for i in 4:
		draw_rect(Rect2(-3.4 * girth + i * 2.2 * girth, -7.0, 0.9, 1.1), c.lightened(0.15))
	if broken:
		var jag := PackedVector2Array([Vector2(-3.5, -10), Vector2(-1.5, -12.5), Vector2(0.5, -10.5), Vector2(2.5, -12.8), Vector2(3.6, -10)])
		draw_polyline(jag, Art.INK, 1.2, true)
		Art.blob(self, Vector2(7, -1), Vector2(2.4, 1.4), c.darkened(0.1), 0.5, 10)
	else:
		draw_rect(Rect2(-1.6, -15, 3.2, 4).grow(0.8), Art.INK)
		draw_rect(Rect2(-1.6, -15, 3.2, 4), c.darkened(0.08))
		draw_rect(Rect2(-2.6, -16, 5.2, 1.4), c.lightened(0.1))
		draw_arc(Vector2(-3.2 * girth, -10), 2.0, PI * 0.5, PI * 1.5, 8, Art.INK, 1.0, true)
		draw_arc(Vector2(3.2 * girth, -10), 2.0, -PI * 0.5, PI * 0.5, 8, Art.INK, 1.0, true)


func _draw_crystal_glow() -> void:
	var pulse := 0.8 + 0.2 * sin(_t * 2.0)
	Art.glow(_glow, Vector2(2, -7), 14.0, Color("7dffb0"), 0.6 * pulse)
	_glow.draw_circle(Vector2(3.3, -12), 0.9, Art.hdr(Color.WHITE, 2.5))

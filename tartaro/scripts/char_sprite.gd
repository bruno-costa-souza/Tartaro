class_name CharSprite
extends AnimatedSprite2D

const ANIMS := ["move", "attack"]

static var _cache := {}

var char_id := ""
var anim := ""
var dir := 0
var base_scale := 1.0
var height := 0.0


static func available(id: String) -> bool:
	return ResourceLoader.exists("res://art/%s/move.png" % id) and FileAccess.file_exists("res://art/%s/meta.json" % id)


static func _load(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/%s/meta.json" % id))
	var size := int(meta["frame_size"])
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for a in ANIMS:
		var sheet: Texture2D = load("res://art/%s/%s.png" % [id, a])
		var count := int(meta["frames"][a])
		for d in HeroSprite.DIRECTIONS:
			var key := "%s_%d" % [a, d]
			frames.add_animation(key)
			frames.set_animation_speed(key, float(meta["fps"][a]))
			frames.set_animation_loop(key, true)
			for f in count:
				var at := AtlasTexture.new()
				at.atlas = sheet
				at.region = Rect2(f * size, d * size, size, size)
				frames.add_frame(key, at)
	var entry := {"frames": frames, "meta": meta}
	_cache[id] = entry
	return entry


func setup(id: String, height_units: float) -> void:
	char_id = id
	var entry := _load(id)
	var meta: Dictionary = entry["meta"]
	sprite_frames = entry["frames"]
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	centered = true
	offset = Vector2(0, float(meta["frame_size"]) / 2.0 - float(meta["feet_y"]))
	height = height_units
	base_scale = height_units / float(meta["figure_px"])
	scale = Vector2(base_scale, base_scale)
	show_state("move", Vector2.DOWN)


func show_state(new_anim: String, facing: Vector2, speed := 1.0) -> void:
	var d := HeroSprite.dir_index(facing) if facing != Vector2.ZERO else dir
	speed_scale = speed
	if new_anim == anim and d == dir:
		return
	var keep := new_anim == anim
	var f := frame
	var p := frame_progress
	anim = new_anim
	dir = d
	play("%s_%d" % [anim, dir])
	if keep:
		set_frame_and_progress(f, p)

class_name HeroSprite
extends AnimatedSprite2D

const DIR := "res://art/hero/"

static var _meta: Dictionary
static var _frames: SpriteFrames
static var _showcase: SpriteFrames

var anim := "idle"
var dir := 0
var showcase := false
var _dirs := 16
var _figure := 108.0


static func available() -> bool:
	return ResourceLoader.exists(DIR + "walk.png") and FileAccess.file_exists(DIR + "hero.json")


static func meta() -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "hero.json"))
	return _meta


static func frames() -> SpriteFrames:
	if _frames == null:
		var m := meta()
		_frames = SpriteFrames.new()
		_frames.remove_animation("default")
		for a in m["frames"]:
			_add(_frames, a, load(DIR + a + ".png"), int(m["frame_size"]), int(m["directions"]),
				int(m["frames"][a]), float(m["fps"][a]), a != "attack")
	return _frames


static func showcase_frames() -> SpriteFrames:
	if _showcase == null:
		var s: Dictionary = meta()["showcase"]
		_showcase = SpriteFrames.new()
		_showcase.remove_animation("default")
		_add(_showcase, "idle", load(DIR + "showcase.png"), int(s["frame_size"]), int(s["directions"]),
			int(s["frames"]), float(s["fps"]), true)
	return _showcase


static func _add(sf: SpriteFrames, a: String, sheet: Texture2D, size: int, dirs: int, count: int, fps: float, loop: bool) -> void:
	for d in dirs:
		var key := "%s_%d" % [a, d]
		sf.add_animation(key)
		sf.set_animation_speed(key, fps)
		sf.set_animation_loop(key, loop)
		for f in count:
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(f * size, d * size, size, size)
			sf.add_frame(key, at)


static func dir_index(facing: Vector2, dirs := 8) -> int:
	var deg := rad_to_deg(facing.angle())
	return posmod(roundi((90.0 - deg) / (360.0 / dirs)), dirs)


func _ready() -> void:
	var m := meta()
	var info: Dictionary = m["showcase"] if showcase else m
	_dirs = int(info["directions"])
	_figure = float(info["figure_px"])
	sprite_frames = showcase_frames() if showcase else frames()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	centered = true
	offset = Vector2(0, float(info["frame_size"]) / 2.0 - float(info["feet_y"]))
	animation = "idle_0"
	play()


func fit_height(units: float) -> void:
	var s := units / _figure
	scale = Vector2(s, s)


func show_state(new_anim: String, facing: Vector2, speed_scale_hint := 1.0) -> void:
	var d := dir_index(facing, _dirs)
	if new_anim == anim and d == dir:
		speed_scale = speed_scale_hint
		return
	var keep_frame := new_anim == anim
	var f := frame
	var p := frame_progress
	anim = new_anim
	dir = d
	play("%s_%d" % [anim, dir])
	speed_scale = speed_scale_hint
	if keep_frame:
		set_frame_and_progress(f, p)


func current_texture() -> Texture2D:
	return sprite_frames.get_frame_texture(animation, frame)

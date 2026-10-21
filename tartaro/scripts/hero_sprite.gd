class_name HeroSprite
extends AnimatedSprite2D

const DIR := "res://art/hero/"
const FRAME := 192
const DIRECTIONS := 8
const FEET_Y := 147.8
const ANIMS := {"idle": 8, "walk": 8, "attack": 6, "dash": 4}
const FPS := {"idle": 8.0, "walk": 12.0, "attack": 16.0, "dash": 14.0}

static var _frames: SpriteFrames

var anim := "idle"
var dir := 0


static func available() -> bool:
	return ResourceLoader.exists(DIR + "walk.png")


static func frames() -> SpriteFrames:
	if _frames == null:
		_frames = SpriteFrames.new()
		_frames.remove_animation("default")
		for a in ANIMS:
			var sheet: Texture2D = load(DIR + a + ".png")
			for d in DIRECTIONS:
				var key := "%s_%d" % [a, d]
				_frames.add_animation(key)
				_frames.set_animation_speed(key, FPS[a])
				_frames.set_animation_loop(key, a != "attack")
				for f in int(ANIMS[a]):
					var at := AtlasTexture.new()
					at.atlas = sheet
					at.region = Rect2(f * FRAME, d * FRAME, FRAME, FRAME)
					_frames.add_frame(key, at)
	return _frames


static func dir_index(facing: Vector2) -> int:
	var deg := rad_to_deg(facing.angle())
	return posmod(roundi((90.0 - deg) / 45.0), DIRECTIONS)


func _ready() -> void:
	sprite_frames = frames()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	centered = true
	offset = Vector2(0, FRAME / 2.0 - FEET_Y)
	animation = "idle_0"
	play()


func fit_height(units: float) -> void:
	var s := units / 108.0
	scale = Vector2(s, s)


func show_state(new_anim: String, facing: Vector2, speed_scale_hint := 1.0) -> void:
	var d := dir_index(facing)
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

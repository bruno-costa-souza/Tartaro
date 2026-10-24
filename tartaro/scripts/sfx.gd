class_name Sfx
extends Node

const DIR := "res://audio/sfx/"
const VOICES := 16
const BASE_DB := -3.0
const MIN_GAP_MS := 35

## Every effect rendered by tools/audio/compose.py.
const NAMES := [
	"shoot", "arrow", "slash", "zap", "hit", "crit", "kill", "dash", "hurt", "step", "explode", "fuse",
	"spawn", "growl", "charge", "enemy_shot", "boss_intro", "boss_phase", "boss_shot", "boss_ring",
	"wall_slam", "beam_charge", "beam_fire", "teleport", "summon", "meteor", "xp", "coin", "heal",
	"levelup", "buy", "wave", "doors", "boss_death", "death", "victory", "boon_appear", "card_in",
	"boon_pick", "tick", "tap", "open", "select", "start", "orb_hum",
]

## Per-effect trim in dB, so loud or frequent sounds sit right in the mix.
const TRIM := {
	"step": -9.0, "xp": -5.0, "tick": -4.0, "hit": -2.0, "kill": -1.0, "spawn": -8.0, "charge": -6.0,
	"meteor": -6.0, "beam_charge": -5.0, "coin": -3.0, "shoot": -3.0, "arrow": -3.0, "slash": -3.0,
	"zap": -2.0, "fuse": -4.0, "enemy_shot": -4.0, "boss_shot": -3.0, "growl": -5.0, "tap": -4.0,
	"card_in": -3.0, "open": -6.0, "wave": -1.0,
}

static var _cache := {}

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}


static func load_all() -> void:
	if not _cache.is_empty():
		return
	for n in NAMES:
		for ext in [".wav", ".ogg"]:
			if ResourceLoader.exists(DIR + n + ext):
				var s: AudioStream = load(DIR + n + ext)
				if s is AudioStreamOggVorbis:
					s.loop = true
				_cache[n] = s
				break


static func stream(sound: String) -> AudioStream:
	load_all()
	return _cache.get(sound)


static func volume(sound: String) -> float:
	return BASE_DB + float(TRIM.get(sound, 0.0))


func _ready() -> void:
	load_all()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Sfx"
		add_child(p)
		_players.append(p)


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _cache.has(sound):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(sound, -1000)) < MIN_GAP_MS:
		return
	_last[sound] = now
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _cache[sound]
	p.pitch_scale = pitch
	p.volume_db = volume(sound) + volume_db
	p.play()

extends Node

const DIR := "res://audio/music/"
const VOLUME_DB := -7.0
const FADE := 1.4

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _current := ""
var _streams := {}
var _lowpass: AudioEffectLowPassFilter
var _music_bus := -1
var _duck: Tween
var _ui: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	_ui = AudioStreamPlayer.new()
	_ui.bus = "Sfx"
	add_child(_ui)


func _make_buses() -> void:
	for bus in ["Music", "Sfx"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	_music_bus = AudioServer.get_bus_index("Music")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(_music_bus, _lowpass)
	AudioServer.set_bus_effect_enabled(_music_bus, 0, false)
	AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())
	Save.apply_settings()


func play(track: String) -> void:
	if track == _current:
		return
	var stream := _stream(track)
	if stream == null:
		return
	_current = track
	var old := _players[_active]
	_active = 1 - _active
	var nxt := _players[_active]
	nxt.stream = stream
	nxt.volume_db = -40.0
	nxt.play()
	var t := create_tween().set_parallel(true)
	t.tween_property(nxt, "volume_db", VOLUME_DB, FADE)
	t.tween_property(old, "volume_db", -80.0, FADE)
	t.chain().tween_callback(old.stop)


func stop(fade := 1.2) -> void:
	_current = ""
	var p := _players[_active]
	var t := create_tween()
	t.tween_property(p, "volume_db", -80.0, fade)
	t.tween_callback(p.stop)


## Muffles and lowers the music while a menu is open over the game.
func duck(on: bool) -> void:
	if _duck:
		_duck.kill()
	if on:
		AudioServer.set_bus_effect_enabled(_music_bus, 0, true)
	_duck = create_tween().set_parallel(true)
	_duck.tween_property(_lowpass, "cutoff_hz", 1300.0 if on else 20000.0, 0.4)
	_duck.tween_method(func(v: float): AudioServer.set_bus_volume_db(_music_bus, v),
		AudioServer.get_bus_volume_db(_music_bus), -4.0 if on else 0.0, 0.4)
	if not on:
		_duck.chain().tween_callback(func(): AudioServer.set_bus_effect_enabled(_music_bus, 0, false))


## Interface sounds that must survive scene changes (taps, tab switches).
func ui(sound := "tap", pitch := 1.0) -> void:
	var s := Sfx.stream(sound)
	if s == null:
		return
	_ui.stream = s
	_ui.pitch_scale = pitch
	_ui.volume_db = Sfx.volume(sound)
	_ui.play()


func _stream(track: String) -> AudioStream:
	if not _streams.has(track):
		var path := DIR + track + ".ogg"
		if not ResourceLoader.exists(path):
			return null
		var s: AudioStreamOggVorbis = load(path)
		s.loop = true
		_streams[track] = s
	return _streams[track]

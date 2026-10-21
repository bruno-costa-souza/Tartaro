class_name Sfx
extends Node

const RATE := 22050
const VOICES := 10

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	_streams["shoot"] = _synth(900, 620, 0.045, 0.05, false)
	_streams["hit"] = _synth(320, 140, 0.06, 0.14, false)
	_streams["kill"] = _synth(520, 1100, 0.09, 0.13, false)
	_streams["dash"] = _synth(0, 0, 0.12, 0.10, true)
	_streams["hurt"] = _synth(220, 55, 0.28, 0.25, false)
	_streams["wave"] = _synth(440, 880, 0.3, 0.10, false)
	_streams["arrow"] = _synth(1300, 800, 0.04, 0.05, false)
	_streams["slash"] = _synth(0, 0, 0.07, 0.12, true)
	_streams["zap"] = _synth(1800, 200, 0.1, 0.07, false)
	_streams["xp"] = _synth(1200, 1500, 0.035, 0.05, false)
	_streams["coin"] = _synth(1600, 2100, 0.07, 0.07, false)
	_streams["levelup"] = _synth(440, 1320, 0.45, 0.12, false)
	_streams["buy"] = _synth(700, 1400, 0.15, 0.1, false)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sound: String, pitch := 1.0) -> void:
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.play()


func _synth(f_start: float, f_end: float, dur: float, vol: float, noise: bool) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var env := (1.0 - t) * (1.0 - t)
		var s := 0.0
		if noise:
			s = randf_range(-1.0, 1.0)
		else:
			phase += lerpf(f_start, f_end, t) / RATE
			s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

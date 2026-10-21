class_name Sfx
extends Node

const RATE := 22050
const VOICES := 12

static var _cache := {}

var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	if _cache.is_empty():
		_build()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
		add_child(p)
		_players.append(p)


func play(sound: String, pitch := 1.0) -> void:
	if not _cache.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _cache[sound]
	p.pitch_scale = pitch
	p.play()


static func _build() -> void:
	_cache["shoot"] = _render(0.09, func(t: float, d: float, st: Dictionary) -> float:
		return _noise_lp(st, 0.35) * _env(t, d, 0.004, 6.0) * 0.45 + sin(TAU * lerpf(220.0, 120.0, t / d) * t) * _env(t, d, 0.002, 18.0) * 0.25)
	_cache["arrow"] = _render(0.16, func(t: float, d: float, st: Dictionary) -> float:
		var vib := 1.0 + 0.02 * sin(TAU * 40.0 * t)
		return sin(TAU * 620.0 * vib * t) * _env(t, d, 0.001, 9.0) * 0.3 + _noise_lp(st, 0.6) * _env(t, d, 0.001, 40.0) * 0.3)
	_cache["slash"] = _render(0.16, func(t: float, d: float, st: Dictionary) -> float:
		return _noise_lp(st, lerpf(0.15, 0.6, t / d)) * sin(PI * t / d) * 0.7)
	_cache["zap"] = _render(0.14, func(t: float, d: float, st: Dictionary) -> float:
		var crackle := (1.0 if randf() < 0.3 else 0.0) * randf_range(-1.0, 1.0)
		return (crackle * 0.5 + sin(TAU * 1600.0 * t) * 0.15) * _env(t, d, 0.001, 7.0))
	_cache["hit"] = _render(0.12, func(t: float, d: float, st: Dictionary) -> float:
		return sin(TAU * lerpf(160.0, 55.0, t / d) * t) * _env(t, d, 0.001, 9.0) * 0.6 + _noise_lp(st, 0.5) * _env(t, d, 0.001, 45.0) * 0.4)
	_cache["kill"] = _render(0.22, func(t: float, d: float, st: Dictionary) -> float:
		var body := sin(TAU * lerpf(300.0, 70.0, t / d) * t) * _env(t, d, 0.001, 10.0) * 0.45
		var crunch := _noise_lp(st, 0.45) * _env(t, d, 0.001, 22.0) * 0.45
		var chime := sin(TAU * 1320.0 * t) * _env(t, d, 0.004, 14.0) * 0.12
		return body + crunch + chime)
	_cache["dash"] = _render(0.22, func(t: float, d: float, st: Dictionary) -> float:
		return _noise_lp(st, lerpf(0.08, 0.35, sin(PI * t / d))) * sin(PI * t / d) * 0.8)
	_cache["hurt"] = _render(0.3, func(t: float, d: float, st: Dictionary) -> float:
		var thud := sin(TAU * lerpf(120.0, 45.0, t / d) * t) * _env(t, d, 0.002, 7.0) * 0.7
		return thud + _noise_lp(st, 0.25) * _env(t, d, 0.001, 12.0) * 0.4)
	_cache["wave"] = _render(1.6, func(t: float, d: float, st: Dictionary) -> float:
		var g := sin(TAU * 196.0 * t) * 0.35 + sin(TAU * 311.0 * t) * 0.22 + sin(TAU * 523.0 * t) * 0.12 + sin(TAU * 98.0 * t) * 0.25
		return g * _env(t, d, 0.005, 2.6) * 0.55)
	_cache["xp"] = _render(0.08, func(t: float, d: float, st: Dictionary) -> float:
		return (sin(TAU * 1500.0 * t) + sin(TAU * 2250.0 * t) * 0.5) * _env(t, d, 0.002, 30.0) * 0.18)
	_cache["coin"] = _render(0.35, func(t: float, d: float, st: Dictionary) -> float:
		return (sin(TAU * 1850.0 * t) * 0.5 + sin(TAU * 2790.0 * t) * 0.3 + sin(TAU * 4150.0 * t) * 0.15) * _env(t, d, 0.001, 11.0) * 0.3)
	_cache["levelup"] = _render(0.9, func(t: float, d: float, st: Dictionary) -> float:
		var notes := [523.25, 659.25, 783.99, 1046.5]
		var s := 0.0
		for i in notes.size():
			var start: float = i * 0.09
			if t >= start:
				var lt: float = t - start
				s += (sin(TAU * notes[i] * lt) + sin(TAU * notes[i] * 2.0 * lt) * 0.25) * exp(-lt * 3.2) * 0.16
		return s)
	_cache["buy"] = _render(0.5, func(t: float, d: float, st: Dictionary) -> float:
		var s := (sin(TAU * 1850.0 * t) * 0.4 + sin(TAU * 2790.0 * t) * 0.2) * _env(t, d, 0.001, 9.0)
		if t > 0.08:
			s += sin(TAU * 1318.5 * (t - 0.08)) * exp(-(t - 0.08) * 6.0) * 0.35
		return s * 0.4)

	_build_asmr()

static func _env(t: float, d: float, attack: float, decay: float) -> float:
	var a := clampf(t / attack, 0.0, 1.0)
	return a * exp(-t * decay) * clampf((d - t) / 0.01, 0.0, 1.0)


static func _noise_lp(st: Dictionary, k: float) -> float:
	var y: float = st.get("lp", 0.0)
	y += (randf_range(-1.0, 1.0) - y) * k
	st["lp"] = y
	return y * 1.6


static func _render(duration: float, voice: Callable) -> AudioStreamWAV:
	var n := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var st := {}
	for i in n:
		var t := float(i) / RATE
		var s: float = voice.call(t, duration, st)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


static func _build_asmr() -> void:
	_cache["boon_appear"] = _render(1.6, func(t: float, d: float, st: Dictionary) -> float:
		var air := _noise_lp(st, 0.5) * sin(PI * minf(t / 1.4, 1.0)) * 0.12
		var s := 0.0
		for k in 7:
			var start := 0.08 * k
			if t >= start:
				var lt := t - start
				var f := 1760.0 * pow(1.12246, k)
				s += (sin(TAU * f * lt) + 0.3 * sin(TAU * f * 2.76 * lt)) * exp(-lt * 4.0) * 0.07
		return air + s)
	_cache["card_in"] = _render(0.22, func(t: float, d: float, st: Dictionary) -> float:
		return _noise_lp(st, lerpf(0.6, 0.15, t / d)) * sin(PI * t / d) * 0.22)
	_cache["boon_pick"] = _render(1.4, func(t: float, d: float, st: Dictionary) -> float:
		var s := 0.0
		for f in [1046.5, 1318.5, 1568.0, 2093.0]:
			s += (sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.76 * t)) * exp(-t * 2.6) * 0.09
		s += sin(TAU * lerpf(110.0, 70.0, minf(t / 0.3, 1.0)) * t) * exp(-t * 7.0) * 0.35
		if randf() < 0.012 * exp(-t * 2.0):
			s += randf_range(-0.5, 0.5)
		return s)
	_cache["tick"] = _render(0.03, func(t: float, d: float, st: Dictionary) -> float:
		return (_noise_lp(st, 0.9) * 0.3 + sin(TAU * 2600.0 * t) * 0.15) * exp(-t * 160.0))
	var hum := _render(2.0, func(t: float, d: float, st: Dictionary) -> float:
		return (sin(TAU * 220.0 * t) * 0.5 + sin(TAU * 330.0 * t) * 0.3 + sin(TAU * 440.5 * t) * 0.15) * (0.75 + 0.25 * sin(TAU * 1.0 * t)) * 0.12)
	hum.loop_mode = AudioStreamWAV.LOOP_FORWARD
	hum.loop_end = int(RATE * 2.0)
	_cache["orb_hum"] = hum

extends Node

const RATE := 22050
const VOICE_DIR := "res://audio/voices/"

const STINGERS := {
	"zeus": {"notes": [293.7, 440.0, 587.3], "inst": "brass", "gap": 0.11, "layer": "thunder"},
	"poseidon": {"notes": [261.6, 329.6, 392.0, 523.3], "inst": "harp", "gap": 0.07, "layer": "wave"},
	"ares": {"notes": [73.4, 110.0, 146.8], "inst": "brass", "gap": 0.14, "layer": "drums"},
	"apolo": {"notes": [392.0, 493.9, 587.3, 784.0], "inst": "harp", "gap": 0.08, "layer": ""},
	"hermes": {"notes": [659.3, 784.0, 880.0, 987.8, 1318.5], "inst": "pluck", "gap": 0.045, "layer": "whoosh"},
	"artemis": {"notes": [440.0, 523.3, 659.3], "inst": "flute", "gap": 0.13, "layer": ""},
	"hefesto": {"notes": [130.8, 196.0], "inst": "anvil", "gap": 0.22, "layer": ""},
	"atena": {"notes": [349.2, 523.3, 698.5], "inst": "horn", "gap": 0.12, "layer": ""},
	"dionisio": {"notes": [523.3, 659.3, 784.0, 659.3], "inst": "bell", "gap": 0.09, "layer": ""},
	"demeter": {"notes": [587.3, 698.5, 880.0], "inst": "reed", "gap": 0.12, "layer": ""},
	"hestia": {"notes": [261.6, 392.0], "inst": "pad", "gap": 0.18, "layer": "fire"},
	"boreas": {"notes": [1046.5, 1318.5, 1568.0, 1975.5], "inst": "bell", "gap": 0.06, "layer": "wind"},
	"selene": {"notes": [659.3, 987.8, 1318.5], "inst": "celesta", "gap": 0.12, "layer": ""},
	"hecate": {"notes": [220.0, 261.6, 329.6], "inst": "choir", "gap": 0.16, "layer": ""},
	"eolo": {"notes": [523.3, 698.5, 880.0], "inst": "pluck", "gap": 0.06, "layer": "whoosh"},
	"nemesis": {"notes": [246.9, 349.2, 246.9], "inst": "strings", "gap": 0.15, "layer": ""},
	"iris": {"notes": [1046.5, 1318.5, 1568.0, 1975.5], "inst": "celesta", "gap": 0.07, "layer": ""},
	"tique": {"notes": [784.0, 1174.7, 1568.0], "inst": "bell", "gap": 0.08, "layer": "coins"},
	"olimpo": {"notes": [261.6, 329.6, 392.0, 523.3], "inst": "choir", "gap": 0.1, "layer": ""},
}

const LINES := {
	"zeus": ["Pelo trovão do Olimpo!", "Mostre a eles quem manda, mortal."],
	"poseidon": ["As marés estão a seu favor!", "Que o oceano te carregue!"],
	"ares": ["Sangue e glória! Lute!", "Que a guerra te sorria."],
	"apolo": ["A luz guia seus golpes.", "Que ritmo esplêndido!"],
	"hermes": ["Rápido, rápido, sem tempo!", "Ninguém te alcança agora!"],
	"artemis": ["Mire bem, caçador.", "A floresta te observa."],
	"hefesto": ["Forjado no fogo. Use bem.", "Bom metal, bom golpe."],
	"atena": ["A sabedoria te protege.", "Com escudo e razão, siga."],
	"dionisio": ["Saúde! Beba à vitória!", "Que festa é essa luta!"],
	"demeter": ["A colheita é farta para você.", "Floresça, criança."],
	"hestia": ["Que a chama te aqueça.", "O fogo do lar te guarda."],
	"boreas": ["Sinta o vento do norte!", "Gelo nas veias deles."],
	"selene": ["A lua brilha por você.", "Sob minha luz, siga."],
	"hecate": ["As sombras te obedecem.", "Magia antiga, mortal."],
	"eolo": ["Os ventos estão contigo!", "Voe mais rápido!"],
	"nemesis": ["A vingança é sua.", "Ninguém fica impune."],
	"iris": ["Um arco-íris de golpes!", "Cores para a batalha."],
	"tique": ["A sorte te sorriu hoje.", "Jogue os dados, mortal."],
	"olimpo": ["O Olimpo te abençoa.", "Escolha, herói."],
}

var _voice: AudioStreamPlayer
var _sting: AudioStreamPlayer
var _pitch: AudioEffectPitchShift
var _cache := {}
var _last := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_voice_bus()
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	_voice.volume_db = -2.0
	add_child(_voice)
	_sting = AudioStreamPlayer.new()
	_sting.volume_db = -3.0
	add_child(_sting)


func _make_voice_bus() -> void:
	if AudioServer.get_bus_index("Voice") != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, "Voice")
	AudioServer.set_bus_send(i, "Master")
	_pitch = AudioEffectPitchShift.new()
	_pitch.pitch_scale = 0.9
	AudioServer.add_bus_effect(i, _pitch)
	var chorus := AudioEffectChorus.new()
	chorus.voice_count = 2
	chorus.wet = 0.25
	AudioServer.add_bus_effect(i, chorus)
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.85
	reverb.damping = 0.35
	reverb.wet = 0.32
	reverb.dry = 0.9
	reverb.predelay_msec = 40.0
	AudioServer.add_bus_effect(i, reverb)


func next_line(god: String) -> int:
	var n := int(_last.get(god, randi() % 2))
	_last[god] = (n + 1) % 2
	return n


func line_text(god: String, n: int) -> String:
	var lines: Array = LINES.get(god, LINES["olimpo"])
	return lines[n % lines.size()]


func speak(god: String, n := -1) -> void:
	if n < 0:
		n = next_line(god)
	var path := "%s%s_%d.wav" % [VOICE_DIR, god, n]
	if not ResourceLoader.exists(path):
		path = "%s%s_0.wav" % [VOICE_DIR, god]
	if not ResourceLoader.exists(path):
		return
	if _pitch:
		_pitch.pitch_scale = float(GameData.GODS.get(god, {}).get("voice", 0.9))
	_voice.stream = load(path)
	_voice.play()


func stinger(god: String, volume_db := -6.0) -> void:
	if not STINGERS.has(god):
		god = "olimpo"
	if not _cache.has(god):
		_cache[god] = _render(STINGERS[god])
	_sting.stream = _cache[god]
	_sting.volume_db = volume_db
	_sting.play()


func _render(spec: Dictionary) -> AudioStreamWAV:
	var dur := 1.6
	var n := int(RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var notes: Array = spec["notes"]
	for k in notes.size():
		var start := int(RATE * spec["gap"] * k)
		var f: float = notes[k]
		for i in range(start, n):
			var t := float(i - start) / RATE
			buf[i] += _inst(spec["inst"], f, t) * (0.9 if k == notes.size() - 1 else 0.7)
	_layer(buf, spec["layer"])
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var fade := clampf(float(n - i) / (RATE * 0.15), 0.0, 1.0)
		data.encode_s16(i * 2, int(buf[i] / peak * 0.85 * fade * 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


func _inst(kind: String, f: float, t: float) -> float:
	var s := 0.0
	match kind:
		"brass":
			var a := minf(t / 0.04, 1.0) * exp(-t * 1.8)
			for h in range(1, 7):
				s += sin(TAU * f * h * t) / h
			return s * a * 0.35
		"harp", "pluck":
			var dec := 3.5 if kind == "harp" else 7.0
			for h in range(1, 5):
				s += sin(TAU * f * h * t) * exp(-t * dec * h) / h
			return s * minf(t / 0.003, 1.0) * 0.5
		"flute":
			var vib := 1.0 + 0.006 * sin(TAU * 5.5 * t)
			s = sin(TAU * f * vib * t) + 0.12 * sin(TAU * f * 2.0 * t) + randf_range(-0.05, 0.05)
			return s * minf(t / 0.06, 1.0) * exp(-t * 1.6) * 0.5
		"anvil":
			for r in [1.0, 2.76, 5.4, 8.93]:
				s += sin(TAU * f * 2.0 * r * t) * exp(-t * (3.0 + r))
			return s * 0.35
		"horn":
			for h in range(1, 5):
				s += sin(TAU * f * h * t) / (h * h)
			return s * minf(t / 0.08, 1.0) * exp(-t * 1.4) * 0.6
		"bell", "celesta":
			var parts := [1.0, 2.0, 2.76, 4.07] if kind == "bell" else [1.0, 2.0, 3.0]
			for i in parts.size():
				s += sin(TAU * f * parts[i] * t) * exp(-t * (2.2 + i * 1.5)) / (i + 1)
			return s * 0.5
		"reed":
			for h in [1, 3, 5, 7]:
				s += sin(TAU * f * h * t) / h
			return s * minf(t / 0.04, 1.0) * exp(-t * 2.0) * 0.45
		"pad", "choir", "strings":
			for d in [-0.006, 0.0, 0.007]:
				var ff: float = f * (1.0 + d)
				s += sin(TAU * ff * t) + 0.35 * sin(TAU * ff * 2.0 * t) + 0.15 * sin(TAU * ff * 3.0 * t)
			var trem := 1.0 + (0.25 * sin(TAU * 9.0 * t) if kind == "strings" else 0.0)
			return s * trem * minf(t / 0.15, 1.0) * exp(-t * 1.3) * 0.22
	return 0.0


func _layer(buf: PackedFloat32Array, kind: String) -> void:
	var n := buf.size()
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		match kind:
			"thunder":
				lp += (randf_range(-1, 1) - lp) * 0.03
				buf[i] += lp * 3.0 * exp(-t * 2.2) * minf(t / 0.05, 1.0)
			"wave", "wind", "whoosh":
				var k := 0.08 if kind == "wave" else 0.25
				lp += (randf_range(-1, 1) - lp) * k
				var env := sin(PI * minf(t / (1.2 if kind != "whoosh" else 0.4), 1.0))
				buf[i] += lp * env * (0.9 if kind == "wave" else 0.5)
			"drums":
				for hit in [0.0, 0.14, 0.28]:
					var ht: float = t - hit
					if ht >= 0.0:
						buf[i] += sin(TAU * lerpf(110.0, 45.0, minf(ht / 0.2, 1.0)) * ht) * exp(-ht * 9.0) * 0.8
			"fire":
				if randf() < 0.004:
					buf[i] += randf_range(-0.8, 0.8)
				lp += (randf_range(-1, 1) - lp) * 0.05
				buf[i] += lp * 0.3 * exp(-t * 1.0)
			"coins":
				for c in [0.3, 0.42, 0.5]:
					var ct: float = t - c
					if ct >= 0.0:
						buf[i] += sin(TAU * 2400.0 * ct) * exp(-ct * 18.0) * 0.25

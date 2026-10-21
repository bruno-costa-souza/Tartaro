extends Node

const RATE := 11025
const LOOP := 8.0

const TRACKS := {
	"menu": {"notes": [73.42, 110.0, 146.83, 174.61], "drums": false, "air": 0.05},
	"tartaro": {"notes": [73.42, 110.0, 146.83, 174.61], "drums": false, "air": 0.06},
	"asfodelo": {"notes": [82.41, 123.47, 164.81, 196.0], "drums": false, "air": 0.08},
	"elisio": {"notes": [98.0, 146.83, 196.0, 246.94], "drums": false, "air": 0.04},
	"boss": {"notes": [73.42, 110.0, 138.59, 207.65], "drums": true, "air": 0.05},
}

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _current := ""
var _streams := {}
var _mutex := Mutex.new()
var _pending := ""
var _task := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	_task = WorkerThreadPool.add_task(_render_all)


func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func play(track: String) -> void:
	if track == _current:
		return
	_mutex.lock()
	var stream: AudioStream = _streams.get(track)
	_mutex.unlock()
	if stream == null:
		_pending = track
		return
	_current = track
	_pending = ""
	var old := _players[_active]
	_active = 1 - _active
	var nxt := _players[_active]
	nxt.stream = stream
	nxt.volume_db = -40.0
	nxt.play()
	var t := create_tween().set_parallel(true)
	t.tween_property(nxt, "volume_db", -9.0, 1.6)
	t.tween_property(old, "volume_db", -80.0, 1.6)
	t.chain().tween_callback(old.stop)


func _process(_delta: float) -> void:
	if _pending != "":
		play(_pending)


func _render_all() -> void:
	for id in ["menu", "tartaro", "boss", "asfodelo", "elisio"]:
		var s := _render(TRACKS[id])
		_mutex.lock()
		_streams[id] = s
		_mutex.unlock()


func _render(spec: Dictionary) -> AudioStreamWAV:
	var n := int(RATE * LOOP)
	var data := PackedByteArray()
	data.resize(n * 2)
	var notes: Array = []
	for f in spec["notes"]:
		notes.append(roundf(f * LOOP) / LOOP)
	var drums: bool = spec["drums"]
	var air: float = spec["air"]
	var lp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for k in notes.size():
			var f: float = notes[k]
			var swell := 0.55 + 0.45 * sin(TAU * t * (k + 1) / LOOP + k)
			s += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t) + 0.12 * sin(TAU * f * 3.0 * t)) * swell * 0.11
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.04
		s += lp * air * (0.6 + 0.4 * sin(TAU * t * 2.0 / LOOP))
		if drums:
			var beat := fmod(t, 0.5)
			s += sin(TAU * lerpf(90.0, 40.0, minf(beat / 0.25, 1.0)) * beat) * exp(-beat * 9.0) * 0.45
			var off := fmod(t + 0.25, 1.0)
			s += rng.randf_range(-1.0, 1.0) * exp(-off * 40.0) * 0.08
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

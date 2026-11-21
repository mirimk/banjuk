extends Node
## 사운드 (Autoload: Sound)
## 효과음/배경음을 코드로 합성한 임시 사운드. 실제 에셋이 생기면 _make_* 대신 파일을 불러오면 된다.
## 음량/음소거는 Master 버스에 적용되고 user://settings.json 에 저장된다.

const RATE := 22050
const SETTINGS_PATH := "user://settings.json"
const STEP := 0.26

## [기준음 Hz, 16스텝 음정(반음, null=쉼표)]
const PAT := {
	"title": [262.0, [0, 4, 7, 12, null, 7, 4, null, 5, 9, 12, 9, 7, null, 4, 2]],
	"kitchen": [294.0, [0, null, 7, null, 4, null, 7, 9, 7, null, 4, null, 2, null, 4, null]],
	"bakery": [349.0, [0, 4, 7, 4, 9, 7, 4, null, 2, 5, 9, 5, 7, null, null, null]],
	"home": [220.0, [0, null, null, 3, null, null, 7, null, 5, null, null, 3, null, null, 2, null]],
	"ending": [196.0, [0, null, 3, null, 7, null, 10, null, 8, null, 7, null, 3, null, null, null]],
}

var volume := 0.6
var muted := false

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _bgm: AudioStreamPlayer
var _bgm_kind := ""
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_bgm = AudioStreamPlayer.new()
	_bgm.volume_db = -7.0
	add_child(_bgm)
	_load_settings()
	apply()


func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus, muted or volume <= 0.001)


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	apply()
	_save_settings()


func set_muted(m: bool) -> void:
	muted = m
	apply()
	_save_settings()


func sfx(sound_name: String) -> void:
	if not _cache.has(sound_name):
		_cache[sound_name] = _make_sfx(sound_name)
	var st = _cache[sound_name]
	if st == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = st
	p.play()


func bgm(kind: String) -> void:
	if kind == _bgm_kind:
		return
	_bgm_kind = kind
	if kind == "" or not PAT.has(kind):
		_bgm.stop()
		return
	var key := "bgm_" + kind
	if not _cache.has(key):
		_cache[key] = _make_bgm(kind)
	_bgm.stream = _cache[key]
	_bgm.play()


# ---------------------------------------------------------------- 합성

func _make_sfx(sound_name: String) -> AudioStreamWAV:
	var notes: Array = []  # [주파수, 길이, 파형, 음량, 지연]
	match sound_name:
		"click": notes = [[700.0, 0.06, "square", 0.12, 0.0]]
		"good": notes = [[660.0, 0.12, "tri", 0.45, 0.0], [990.0, 0.18, "tri", 0.45, 0.08]]
		"great": notes = [[660.0, 0.1, "tri", 0.45, 0.0], [880.0, 0.1, "tri", 0.45, 0.07], [1320.0, 0.25, "tri", 0.45, 0.14]]
		"bad": notes = [[180.0, 0.25, "saw", 0.25, 0.0]]
		"cash": notes = [[1300.0, 0.08, "square", 0.15, 0.0], [1750.0, 0.22, "tri", 0.4, 0.07]]
		"bell": notes = [[880.0, 0.5, "sine", 0.5, 0.0], [1320.0, 0.6, "sine", 0.3, 0.12]]
		"door": notes = [[520.0, 0.15, "sine", 0.4, 0.0], [780.0, 0.3, "sine", 0.4, 0.1]]
		"ding": notes = [[1568.0, 0.6, "sine", 0.35, 0.0]]
		"knead": notes = [[140.0, 0.12, "sine", 0.7, 0.0]]
	if notes.is_empty():
		return null
	var total := 0.0
	for n in notes:
		total = maxf(total, float(n[1]) + float(n[4]))
	var buf := PackedFloat32Array()
	buf.resize(int((total + 0.05) * RATE))
	for n in notes:
		buf = _add_tone(buf, n[0], n[1], n[2], n[3], n[4], false)
	return _to_wav(buf, false)


func _make_bgm(kind: String) -> AudioStreamWAV:
	var base: float = PAT[kind][0]
	var seq: Array = PAT[kind][1]
	var buf := PackedFloat32Array()
	buf.resize(int(seq.size() * STEP * RATE))
	for i in seq.size():
		if seq[i] != null:
			buf = _add_tone(buf, base * pow(2.0, float(seq[i]) / 12.0), 0.32, "tri", 0.22, i * STEP, true)
		if i % 8 == 0:
			buf = _add_tone(buf, base / 2.0, 0.6, "sine", 0.25, i * STEP, true)
	return _to_wav(buf, true)


func _add_tone(buf: PackedFloat32Array, f: float, dur: float, wave: String, vol: float, delay: float, wrap: bool) -> PackedFloat32Array:
	var start := int(delay * RATE)
	var length := int(dur * RATE)
	var n := buf.size()
	for i in length:
		var idx := start + i
		if idx >= n:
			if not wrap:
				break
			idx = idx % n
		var t := float(i) / RATE
		var ph := t * f
		var v := 0.0
		if wave == "sine":
			v = sin(TAU * ph)
		elif wave == "square":
			v = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
		elif wave == "saw":
			v = 2.0 * (ph - floor(ph + 0.5))
		else:
			v = 2.0 * absf(2.0 * (ph - floor(ph + 0.5))) - 1.0
		var env := minf(1.0, t / 0.012) * exp(-4.0 * t / dur)
		buf[idx] += v * env * vol
	return buf


func _to_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


# ---------------------------------------------------------------- 설정 저장

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		volume = clampf(float(d.get("volume", 0.6)), 0.0, 1.0)
		muted = bool(d.get("muted", false))


## 설정(음량·음소거)을 지금 저장한다. 게임 종료 직전에 호출.
func save_now() -> void:
	_save_settings()


func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"volume": volume, "muted": muted}))

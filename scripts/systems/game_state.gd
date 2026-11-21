extends Node
## 전역 게임 상태 (Autoload: GameState)
## - s: 저장 대상이 되는 전체 게임 상태 (Dictionary → JSON 으로 그대로 저장)
## - 화면 전환(페이드), 저장/불러오기, 공용 UI(설정·확인 창·알림) 연결

const D = preload("res://scripts/systems/game_data.gd")
const OverlayUI = preload("res://scripts/systems/overlay_ui.gd")

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2
const STORY_PATH := "res://data/dialogues/story.json"
const SCENES := {
	"title": "res://scenes/main/title.tscn",
	"game": "res://scenes/main/game.tscn",
	"settle": "res://scenes/main/day_end.tscn",
	"home": "res://scenes/main/day_end.tscn",
	"ending": "res://scenes/main/ending.tscn",
}

var s: Dictionary = {}
## 현재 화면: title / game / settle / home / ending / quit
var screen := "title"
## 화면 전환 중 (게임 시간 정지, 입력 무시)
var busy := false
var overlay: OverlayUI
var stories: Dictionary = {}


func _ready() -> void:
	_setup_input()
	overlay = OverlayUI.new()
	add_child(overlay)
	_load_stories()


# ---------------------------------------------------------------- 상태

func new_state() -> Dictionary:
	var st := {
		"v": SAVE_VERSION, "day": 1, "screen": "game",
		"money": D.START_MONEY, "stamina": 100.0, "damage": 0.0, "mood": 60.0,
		"total": 0, "flags": {}, "affinity": {"boss": 0, "crew": 0}, "story": null, "cid": 0,
		"peaks": [], "moods": [],
	}
	st.merge(day_reset(), true)
	return st


func day_reset() -> Dictionary:
	return {
		"phase_idx": 0, "minute": 300.0, "time_up": false, "location": "kitchen", "speed": 1,
		"proofer": _nulls(D.PROOF_SLOTS), "shaper": _nulls(D.SHAPE_SLOTS), "oven": _nulls(D.OVEN_SLOTS),
		"rack": _nulls(D.RACK_SLOTS), "shelf": [],
		"customers": [], "spawn_timer": 3.0, "secret_done": false, "last_profile": -1, "night": "",
		"delivery": null, "deliv_left": 0, "deliv_timer": 0.0,
		"today": {"made": 0, "sold": 0, "revenue": 0, "tips": 0, "missed": 0, "lost": 0, "discarded": 0,
			"wrong": 0, "fast_tips": 0, "soldout": 0, "soldout_cost": 0, "late": 0, "late_cost": 0, "eaten": 0, "eat_cost": 0, "deliv": 0, "deliv_rev": 0, "deliv_fee": 0, "deliv_fail": 0},
	}


static func _nulls(n: int) -> Array:
	var a := []
	a.resize(n)
	return a


func add_stat(key: String, delta: float) -> void:
	s[key] = clampf(float(s[key]) + delta, 0.0, 100.0)


func cond(c: String) -> bool:
	match c:
		"dmgHi":
			return float(s.damage) >= 30.0
		"dmgLo":
			return float(s.damage) < 30.0
		"dmgMid":
			return float(s.damage) >= 15.0
		"secret1", "secret2", "levain", "levain_door", "roster", "asked", "kept_levain", "gave_levain", "fed_levain":
			return s.flags.get(c, false)
		"noLevainDoor":
			return not s.flags.get("levain_door", false)
		"crewClose":
			return int(s.affinity.get("crew", 0)) >= 2
		"bossClose":
			return int(s.affinity.get("boss", 0)) >= 2
	if c.begins_with("!"):
		return not cond(c.substr(1))
	return true


func start_new_game() -> void:
	s = new_state()
	s.story = {"key": "morning1", "idx": 0, "ret": null}
	await change_scene("game", "1일차", "새벽 05:00 · 주방")


## 퇴근 후 잠들기 → 다음 날 또는 엔딩
func next_day() -> void:
	if int(s.day) >= D.LAST_DAY:
		await change_scene("ending", "…", "")
		_write_save()
		return
	s.day = int(s.day) + 1
	s.merge(day_reset(), true)
	s.story = {"key": "morning%d" % int(s.day), "idx": 0, "ret": null}
	await change_scene("game", "%d일차" % int(s.day), "새벽 05:00 · 주방")


func quit_to_title() -> void:
	get_tree().paused = false
	await change_scene("title")
	s = {}


## 저장 후 게임(프로그램) 종료. 진행 중인 게임이 없으면 설정만 저장하고 종료한다.
func save_and_quit() -> void:
	var ok := true
	if can_save():
		ok = _write_save()
	if not ok:
		toast("저장에 실패했어요")
		return
	Sound.save_now()
	get_tree().paused = false
	busy = true
	await overlay.fade_in("저장 완료", "게임을 종료합니다")
	await get_tree().create_timer(0.4).timeout
	get_tree().quit()


# ---------------------------------------------------------------- 저장 / 불러오기

func can_save() -> bool:
	return not s.is_empty() and screen in ["game", "settle", "home"] and not busy


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	if not can_save():
		return false
	var ok := _write_save()
	toast("저장했어요" if ok else "저장에 실패했어요")
	return ok


func _write_save() -> bool:
	s.screen = screen
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(s, "\t"))
	return true


func load_game() -> bool:
	if not has_save():
		toast("저장된 게임이 없어요")
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f else null
	if not (d is Dictionary):
		toast("저장 파일을 읽을 수 없어요")
		return false
	s = new_state()
	s.merge(d, true)
	if int(d.get("v", 1)) < SAVE_VERSION:
		_migrate()
	_normalize()
	var target: String = s.get("screen", "game")
	if not SCENES.has(target):
		target = "game"
	await change_scene(target, "%d일차" % int(s.day), "이어하기 · %s" % D.fmt_time(float(s.minute)))
	return true


## v1(2일차 프로토타입) 저장 파일: 능력치·날짜만 살리고 하루 상태는 그날 아침부터 다시 시작한다.
func _migrate() -> void:
	var t: Dictionary = day_reset()
	var today: Dictionary = t.today
	for k in s.get("today", {}):
		today[k] = s.today[k]
	s.merge(t, true)
	s.today = today
	s.v = SAVE_VERSION
	if s.screen == "game":
		s.story = {"key": "morning%d" % int(s.day), "idx": 0, "ret": null}


## JSON 은 숫자를 모두 실수로 읽으므로 정수여야 하는 값들을 되돌린다.
func _normalize() -> void:
	for k in ["day", "phase_idx", "speed", "cid", "last_profile", "money", "total", "deliv_left"]:
		s[k] = int(s[k])
	for k in s.today:
		s.today[k] = int(s.today[k])
	for c in s.customers:
		c.p = int(c.p)
		c.wrong = int(c.get("wrong", 0))
	# 알 수 없는 빵(이전 버전)은 진열대에서 뺀다
	s.shelf = s.shelf.filter(func(b) -> bool: return b is Dictionary and D.BREADS.has(b.get("type", "")))
	# 칸 수가 바뀐 이전 저장 파일: 모자라면 빈칸 추가, 넘치면 잘라냄
	var sizes := {"proofer": D.PROOF_SLOTS, "shaper": D.SHAPE_SLOTS, "oven": D.OVEN_SLOTS, "rack": D.RACK_SLOTS}
	for key in sizes:
		s[key].resize(int(sizes[key]))
	for key in ["proofer", "shaper", "oven", "rack"]:
		for i in s[key].size():
			var it = s[key][i]
			if it is Dictionary and not D.BREADS.has(it.get("type", "")):
				s[key][i] = null
	var st = s.story
	while st is Dictionary:
		st.idx = int(st.idx)
		st = st.get("ret")


# ---------------------------------------------------------------- 화면 전환

func change_scene(target: String, title: String = "", sub: String = "") -> void:
	busy = true
	await overlay.fade_in(title, sub)
	screen = target
	if not s.is_empty() and target != "title":
		s.screen = target
	get_tree().change_scene_to_file(SCENES[target])
	await get_tree().process_frame
	if title != "":
		await get_tree().create_timer(0.7).timeout
	await overlay.fade_out()
	busy = false


## 같은 씬 안에서 페이드 + 큰 글자 안내. mid 는 화면이 가려진 동안 실행된다.
func transition(title: String, sub: String, mid: Callable) -> void:
	busy = true
	await overlay.fade_in(title, sub)
	if mid.is_valid():
		mid.call()
	await get_tree().create_timer(0.7).timeout
	await overlay.fade_out()
	busy = false


func toast(msg: String) -> void:
	overlay.toast(msg)


func ask(msg: String, on_yes: Callable) -> void:
	overlay.ask(msg, on_yes)


func _load_stories() -> void:
	var f := FileAccess.open(STORY_PATH, FileAccess.READ)
	if f == null:
		push_error("story.json 을 열 수 없습니다")
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		stories = d


# ---------------------------------------------------------------- 입력

func _setup_input() -> void:
	_add_action("interact", [KEY_SPACE, KEY_ENTER, KEY_E])


func _add_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

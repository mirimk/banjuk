extends Node
## 전역 게임 상태 (Autoload: GameState)
## 능력치, 하루 기록, 씬 전환(페이드)을 관리한다.

signal stats_changed

const STAT_MAX := 100

var day: int = 1
var money: int = 0
var stamina: int = 100      # 체력: 업무 수행 능력
var memory: int = 100       # 기억: 자아 유지 정도
var body: int = 100         # 신체: 주인공의 온전함
var contamination: int = 0  # 반죽 오염도
var hand_stain: float = 0.0 # 손에 묻은 반죽 (외형 연출용, 0~1)

## 오늘 하루 기록. 하루 종료 화면에서 사용.
var today: Dictionary = {}

var _fade: ColorRect


func _ready() -> void:
	_setup_input()
	_setup_fade()
	new_game()


func new_game() -> void:
	day = 1
	money = 0
	stamina = 100
	memory = 100
	body = 100
	contamination = 0
	hand_stain = 0.0
	start_day()


func start_day() -> void:
	today = {
		"bread_quality": 0,
		"bread_grade": "",
		"effort": 0.0,
		"wage": 0,
		"start": snapshot(),
	}
	stats_changed.emit()


func snapshot() -> Dictionary:
	return {
		"money": money,
		"stamina": stamina,
		"memory": memory,
		"body": body,
		"contamination": contamination,
	}


## 반죽 미니게임 결과 반영.
## quality: 0~100, effort: '온 힘을 다해' 누른 시간 비율 0~1
## 핵심 규칙: 더 좋은 빵을 원할수록(힘을 줄수록) 더 많은 것을 내어준다.
func apply_bread_result(quality: int, effort: float) -> void:
	quality = clampi(quality, 0, 100)
	effort = clampf(effort, 0.0, 1.0)
	today["bread_quality"] = quality
	today["bread_grade"] = grade_name(quality)
	today["effort"] = effort
	today["wage"] = 50 + int(quality / 2.0)

	stamina = clampi(stamina - (12 + int(effort * 25.0)), 0, STAT_MAX)
	contamination = clampi(contamination + 2 + int(quality / 10.0) + int(effort * 15.0), 0, STAT_MAX)
	body = clampi(body - int(effort * 8.0), 0, STAT_MAX)
	hand_stain = clampf(0.25 + effort * 0.75, 0.0, 1.0)
	stats_changed.emit()


func pay_wage() -> int:
	var wage: int = today.get("wage", 0)
	money += wage
	stats_changed.emit()
	return wage


## 체력이 낮을수록 반죽이 힘들어진다 (0.6 ~ 1.0)
func stamina_factor() -> float:
	return 0.6 + 0.4 * float(stamina) / float(STAT_MAX)


static func grade_name(quality: int) -> String:
	if quality >= 85:
		return "완벽"
	if quality >= 60:
		return "좋음"
	if quality >= 30:
		return "보통"
	return "엉망"


# ---------------------------------------------------------------- 씬 전환

func change_scene(path: String) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.4)
	await tw.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	tw = create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.4)
	await tw.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _setup_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


# ---------------------------------------------------------------- 입력

func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("interact", [KEY_E, KEY_SPACE, KEY_ENTER])
	_add_action("knead_left", [KEY_A, KEY_LEFT])
	_add_action("knead_right", [KEY_D, KEY_RIGHT])
	_add_action("knead_power", [KEY_SPACE])


func _add_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

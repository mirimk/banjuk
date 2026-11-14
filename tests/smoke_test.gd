extends SceneTree
## 자동 스모크 테스트: 타이틀 → 빵집 1일 차 전체 진행 → 마감 화면 도달 여부 확인.
## 실행: godot --headless --fixed-fps 60 --path . -s res://tests/smoke_test.gd

const PHASE_TARGETS := {1: 470.0, 2: 337.0, 3: 136.0, 4: 470.0, 5: 40.0}

var frame := 0
var alt := false
var started := false


func _initialize() -> void:
	change_scene_to_file("res://scenes/main/title.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if frame > 30000:
		print("SMOKE FAIL: timeout, scene=", current_scene.name if current_scene else "null")
		quit(1)
		return false
	var scene := current_scene
	if scene == null:
		return false
	var gs := root.get_node("GameState")
	if scene.name == "Title" and frame > 30 and not started:
		started = true
		print("SMOKE: title ok -> start")
		scene.call("_on_start")
	elif scene.name == "Bakery":
		_drive(scene)
	elif scene.name == "DayEnd" and frame % 60 == 0:
		print("SMOKE OK: day end reached. money=%d stamina=%d body=%d contamination=%d quality=%d" % [
			gs.money, gs.stamina, gs.body, gs.contamination, gs.today["bread_quality"]])
		quit(0)
	return false


func _drive(scene: Node) -> void:
	var mg := scene.get_node_or_null("KneadMinigame")
	if mg != null:
		if frame % 4 == 0:
			_tap("knead_left" if alt else "knead_right")
			alt = not alt
		if frame % 120 < 40:
			Input.action_press("knead_power")
		else:
			Input.action_release("knead_power")
		return
	Input.action_release("knead_power")
	var phase: int = scene.get("phase")
	var target := -1.0
	if phase == 1 and not scene.get("crew_met"):
		target = 250.0
	elif PHASE_TARGETS.has(phase):
		target = PHASE_TARGETS[phase]
	if target >= 0.0:
		scene.get("player").position.x = target
	if frame % 8 == 0:
		_tap("interact")


func _tap(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)

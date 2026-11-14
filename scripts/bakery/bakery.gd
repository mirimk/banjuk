extends Node2D
## 빵집 메인 씬: 하루(1턴) 진행.
## 흐름: 인트로 → 사장에게 업무 받기 → 반죽 미니게임 → 손님 응대 → 사장에게 보고(일당) → 퇴근

const UIUtil = preload("res://scripts/systems/ui_util.gd")
const BreadCharacter = preload("res://scripts/characters/bread_character.gd")
const DialogueBox = preload("res://scripts/dialogue/dialogue_box.gd")
const KneadScene = preload("res://scenes/minigames/knead_minigame.tscn")

enum Phase { INTRO, TALK_BOSS, KNEAD, SERVE, REPORT, DONE }

const GOALS := {
	Phase.INTRO: "",
	Phase.TALK_BOSS: "할 일: 사장님께 인사하기 (오른쪽 오븐 앞)",
	Phase.KNEAD: "할 일: 반죽대에서 반죽하기",
	Phase.SERVE: "할 일: 계산대에서 손님에게 빵 건네기",
	Phase.REPORT: "할 일: 사장님께 보고하기",
	Phase.DONE: "할 일: 출입문으로 퇴근하기",
}

const FLOOR_Y := 300.0
const PLAYER_SPEED := 90.0
const INTERACT_RANGE := 26.0

const X_DOOR := 40.0
const X_CUSTOMER := 92.0
const X_COUNTER := 136.0
const X_CREW := 250.0
const X_BENCH := 337.0
const X_BOSS := 470.0
const X_OVEN := 547.0

var phase: int = Phase.INTRO
var busy := false
var crew_met := false

var lines: Dictionary = {}
var interactables: Array = []

var player: BreadCharacter
var boss: BreadCharacter
var crew: BreadCharacter
var customer: BreadCharacter
var dialogue: DialogueBox
var hud_status: Label
var hud_goal: Label
var prompt: Label

var _t := 0.0


func _ready() -> void:
	GameState.start_day()
	lines = _load_lines("res://data/dialogues/day%d.json" % GameState.day)
	_build_world()
	_build_hud()
	dialogue = DialogueBox.new()
	add_child(dialogue)
	GameState.stats_changed.connect(_refresh_hud)
	_refresh_hud()
	_set_phase(Phase.INTRO)
	_run_intro()


# ================================================================ 구성

func _build_world() -> void:
	var sign_label := UIUtil.label("발효빵 전문점 〈반죽〉", 12, Color(0.98, 0.88, 0.62))
	sign_label.position = Vector2(300, 55)
	sign_label.size = Vector2(160, 22)
	sign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sign_label)

	crew = _spawn("crew", X_CREW)
	boss = _spawn("boss", X_BOSS)
	boss.scale.x = -1.0
	customer = _spawn("child", -30.0)
	customer.visible = false
	player = _spawn("banjuk", 75.0)
	player.stain = GameState.hand_stain

	interactables = [
		{"id": "door", "x": X_DOOR, "name": "출입문"},
		{"id": "counter", "x": X_COUNTER, "name": "계산대"},
		{"id": "crew", "x": X_CREW, "name": "크루"},
		{"id": "bench", "x": X_BENCH, "name": "반죽대"},
		{"id": "boss", "x": X_BOSS, "name": "사장"},
		{"id": "oven", "x": X_OVEN, "name": "오븐"},
	]


func _spawn(kind: String, x: float) -> BreadCharacter:
	var c: BreadCharacter = BreadCharacter.new()
	c.kind = kind
	c.position = Vector2(x, FLOOR_Y)
	add_child(c)
	return c


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 5
	add_child(hud)

	var bar := Panel.new()
	bar.position = Vector2(0, 0)
	bar.size = Vector2(640, 38)
	bar.add_theme_stylebox_override("panel", UIUtil.panel_style(Color(0.12, 0.08, 0.06, 0.85), Color(0.12, 0.08, 0.06, 0.0), 0))
	hud.add_child(bar)

	hud_status = UIUtil.label("", 11, Color(0.98, 0.92, 0.80))
	hud_status.position = Vector2(8, 3)
	hud.add_child(hud_status)

	hud_goal = UIUtil.label("", 11, Color(1.0, 0.80, 0.45))
	hud_goal.position = Vector2(8, 19)
	hud.add_child(hud_goal)

	var keys := UIUtil.label("←→ / A D : 이동     E / Space : 상호작용", 9, Color(0.85, 0.75, 0.62))
	keys.position = Vector2(8, 340)
	hud.add_child(keys)

	prompt = UIUtil.label("", 10, Color(1, 1, 1))
	prompt.size = Vector2(76, 16)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_stylebox_override("normal", UIUtil.panel_style(Color(0, 0, 0, 0.6), Color(1, 1, 1, 0.0), 0))
	prompt.visible = false
	add_child(prompt)


func _refresh_hud() -> void:
	hud_status.text = "%d일 차    돈 %d원    체력 %d    기억 %d    신체 %d    반죽 오염도 %d" % [
		GameState.day, GameState.money, GameState.stamina,
		GameState.memory, GameState.body, GameState.contamination]


func _set_phase(p: int) -> void:
	phase = p
	hud_goal.text = GOALS.get(p, "")


func _load_lines(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("대사 파일을 열 수 없음: " + path)
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		return data
	push_error("대사 파일 형식 오류: " + path)
	return {}


func _line(key: String) -> Array:
	return lines.get(key, [{"speaker": "", "text": "(대사 없음: %s)" % key}])


# ================================================================ 루프

func _process(delta: float) -> void:
	_t += delta
	var can_move := not busy and not dialogue.active
	var dir := 0.0
	if can_move:
		dir = Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		player.position.x = clampf(player.position.x + dir * PLAYER_SPEED * delta, 20.0, 620.0)
		player.scale.x = signf(dir)
	player.walking = dir != 0.0
	crew.scale.x = 1.0 if player.position.x > crew.position.x else -1.0
	_update_prompt(can_move)
	queue_redraw()  # 오븐 불빛 깜빡임


func _nearest():
	var best = null
	var best_d := INTERACT_RANGE
	for it in interactables:
		var d := absf(float(it["x"]) - player.position.x)
		if d <= best_d:
			best_d = d
			best = it
	return best


func _update_prompt(can_move: bool) -> void:
	var it = _nearest() if can_move else null
	if it == null:
		prompt.visible = false
		return
	prompt.visible = true
	prompt.text = "[E] " + str(it["name"])
	prompt.position = Vector2(player.position.x - 38.0, FLOOR_Y - 52.0)


func _unhandled_input(event: InputEvent) -> void:
	if busy or dialogue.active:
		return
	if event.is_action_pressed("interact"):
		var it = _nearest()
		if it != null:
			get_viewport().set_input_as_handled()
			_interact(str(it["id"]))


func _interact(id: String) -> void:
	busy = true
	match id:
		"boss":
			await _talk_boss()
		"crew":
			await _talk_crew()
		"bench":
			await _use_bench()
		"counter":
			await _use_counter()
		"oven":
			await dialogue.play(_line("oven"))
		"door":
			if phase == Phase.DONE:
				await _go_home()
				return  # 씬 전환 중이므로 busy 유지
			await dialogue.play(_line("door_locked"))
	busy = false


# ================================================================ 이벤트

func _run_intro() -> void:
	busy = true
	await get_tree().create_timer(0.7).timeout
	await dialogue.play(_line("intro"))
	_set_phase(Phase.TALK_BOSS)
	busy = false


func _talk_boss() -> void:
	match phase:
		Phase.TALK_BOSS:
			await dialogue.play(_line("boss_task"))
			_set_phase(Phase.KNEAD)
		Phase.KNEAD:
			await dialogue.play(_line("boss_knead_hint"))
		Phase.SERVE:
			await dialogue.play(_line("boss_serve_hint"))
		Phase.REPORT:
			var good: bool = int(GameState.today["bread_quality"]) >= 60
			await dialogue.play(_line("boss_report_good" if good else "boss_report_ok"))
			var wage: int = GameState.pay_wage()
			await dialogue.play([{"speaker": "", "text": "첫 일당 %d원을 받았다." % wage}])
			_set_phase(Phase.DONE)
			await dialogue.play(_line("boss_goodbye"))
		_:
			await dialogue.play(_line("boss_goodbye"))


func _talk_crew() -> void:
	if not crew_met:
		crew_met = true
		await dialogue.play(_line("crew_intro"))
		return
	match phase:
		Phase.TALK_BOSS, Phase.KNEAD:
			await dialogue.play(_line("crew_knead"))
		Phase.SERVE, Phase.REPORT:
			var hard: bool = float(GameState.today["effort"]) >= 0.3
			await dialogue.play(_line("crew_after_hard" if hard else "crew_after"))
		_:
			await dialogue.play(_line("crew_done"))


func _use_bench() -> void:
	if phase != Phase.KNEAD:
		await dialogue.play(_line("bench_idle"))
		return
	await dialogue.play(_line("bench_before"))

	var game = KneadScene.instantiate()
	add_child(game)
	var result: Dictionary = await game.finished
	GameState.apply_bread_result(int(result["quality"]), float(result["effort"]))
	player.stain = GameState.hand_stain

	var high: bool = int(result["quality"]) >= 60
	await dialogue.play(_line("knead_done_high" if high else "knead_done_low"))
	if float(result["effort"]) >= 0.3:
		await dialogue.play(_line("knead_effort"))

	_set_phase(Phase.SERVE)
	await _customer_arrives()


func _customer_arrives() -> void:
	customer.visible = true
	customer.position.x = -20.0
	customer.scale.x = 1.0
	customer.walking = true
	var tw := create_tween()
	tw.tween_property(customer, "position:x", X_CUSTOMER, 1.6)
	await tw.finished
	customer.walking = false
	await dialogue.play(_line("customer_enter"))


func _use_counter() -> void:
	if phase != Phase.SERVE:
		await dialogue.play(_line("counter_idle"))
		return
	var high: bool = int(GameState.today["bread_quality"]) >= 60
	await dialogue.play(_line("customer_high" if high else "customer_low"))
	customer.scale.x = -1.0
	customer.walking = true
	var tw := create_tween()
	tw.tween_property(customer, "position:x", -30.0, 1.4)
	await tw.finished
	customer.visible = false
	customer.walking = false
	_set_phase(Phase.REPORT)


func _go_home() -> void:
	await dialogue.play(_line("day_end"))
	GameState.change_scene("res://scenes/main/day_end.tscn")


# ================================================================ 배경 (임시 도형)

func _draw() -> void:
	var wood := Color(0.55, 0.36, 0.22)
	var dark_wood := Color(0.40, 0.25, 0.15)
	# 벽
	draw_rect(Rect2(0, 0, 640, 300), Color(0.95, 0.86, 0.70))
	for x in range(0, 640, 40):
		draw_line(Vector2(x, 38), Vector2(x, 226), Color(0.92, 0.82, 0.65), 1.0)
	draw_rect(Rect2(0, 228, 640, 72), Color(0.72, 0.52, 0.36))
	draw_rect(Rect2(0, 226, 640, 4), dark_wood)
	# 바닥
	draw_rect(Rect2(0, 300, 640, 60), Color(0.50, 0.34, 0.22))
	for x in range(0, 640, 32):
		draw_line(Vector2(x, 300), Vector2(x, 360), Color(0.42, 0.28, 0.18), 1.0)
	draw_line(Vector2(0, 330), Vector2(640, 330), Color(0.42, 0.28, 0.18), 1.0)

	# 간판
	draw_rect(Rect2(296, 50, 168, 30), dark_wood)
	draw_rect(Rect2(299, 53, 162, 24), Color(0.30, 0.18, 0.10))

	# 창문
	draw_rect(Rect2(165, 80, 92, 72), wood)
	draw_rect(Rect2(170, 85, 82, 62), Color(0.72, 0.86, 0.95))
	draw_line(Vector2(211, 85), Vector2(211, 147), wood, 3.0)
	draw_line(Vector2(170, 116), Vector2(252, 116), wood, 3.0)

	# 출입문
	draw_rect(Rect2(16, 194, 48, 106), dark_wood)
	draw_rect(Rect2(22, 200, 36, 40), Color(0.62, 0.78, 0.86))
	draw_rect(Rect2(22, 246, 36, 48), Color(0.35, 0.22, 0.13))
	draw_circle(Vector2(54, 262), 2.5, Color(0.95, 0.80, 0.35))

	# 계산대
	draw_rect(Rect2(110, 254, 54, 46), Color(0.60, 0.40, 0.25))
	draw_rect(Rect2(106, 248, 62, 8), Color(0.82, 0.66, 0.46))
	draw_rect(Rect2(140, 234, 20, 14), Color(0.45, 0.45, 0.48))
	draw_rect(Rect2(143, 237, 14, 5), Color(0.55, 0.85, 0.60))

	# 진열대 + 빵
	for y in [168.0, 200.0]:
		draw_rect(Rect2(212, y, 82, 6), wood)
		for i in 4:
			UIUtil.ellipse(self, Vector2(224 + i * 19, y - 5), Vector2(8, 5), Color(0.86, 0.58, 0.28))

	# 반죽대 + 반죽 볼
	draw_rect(Rect2(305, 270, 6, 30), dark_wood)
	draw_rect(Rect2(363, 270, 6, 30), dark_wood)
	draw_rect(Rect2(300, 264, 74, 7), Color(0.80, 0.68, 0.52))
	UIUtil.ellipse(self, Vector2(337, 258), Vector2(20, 8), Color(0.75, 0.75, 0.78))
	var breathe := 1.0 + sin(_t * 1.3) * 0.06
	UIUtil.ellipse(self, Vector2(337, 253), Vector2(15 * breathe, 7 * breathe), Color(0.94, 0.90, 0.80))

	# 오븐
	draw_rect(Rect2(532, 38, 30, 124), Color(0.45, 0.24, 0.18))
	draw_rect(Rect2(500, 160, 96, 140), Color(0.58, 0.30, 0.22))
	for row in 9:
		var y := 166.0 + row * 15.0
		draw_line(Vector2(500, y), Vector2(596, y), Color(0.45, 0.22, 0.16), 1.0)
	draw_rect(Rect2(514, 218, 68, 48), Color(0.20, 0.12, 0.10))
	var flicker := 0.85 + sin(_t * 7.0) * 0.08 + sin(_t * 13.0) * 0.05
	draw_rect(Rect2(519, 223, 58, 38), Color(0.98 * flicker, 0.55 * flicker, 0.18))

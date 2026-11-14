extends CanvasLayer
## 반죽하기 미니게임
## - ←/→ (A/D) 를 번갈아 눌러 반죽 게이지를 채운다. 같은 키 연타는 헛손질.
## - Space 를 누르고 있으면 '온 힘을 다해' 반죽: 게이지가 빨리 차지만
##   반죽이 속삭이고, 끝나면 체력·신체·오염도 대가가 커진다. (더 좋은 빵 = 더 큰 희생)

signal finished(result: Dictionary)

const UIUtil = preload("res://scripts/systems/ui_util.gd")
const DURATION := 10.0
const GAIN := 1.4
const POWER_GAIN := 2.3
const WHISPERS := ["조금만 더.", "더 세게.", "네 손, 따뜻하구나.", "조금만 나눠 줘.", "완벽해질 수 있어.", "인정받고 싶지?"]

enum State { READY, PLAY, RESULT }

var state: int = State.READY
var progress := 0.0
var time_left := DURATION
var power_time := 0.0
var last_side := ""
var squish := 0.0
var fumble := 0.0

var _ready_t := 1.6
var _whisper_t := 0.0
var _t := 0.0
var _canvas: Control
var _time_label: Label
var _center_label: Label
var _whisper_label: Label
var _help_label: Label


func _ready() -> void:
	layer = 20
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_draw)
	add_child(_canvas)

	var title := UIUtil.label("반죽하기", 18, Color(0.98, 0.88, 0.66))
	title.position = Vector2(0, 18)
	title.size = Vector2(640, 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	_time_label = UIUtil.label("", 12, Color(0.95, 0.90, 0.80))
	_time_label.position = Vector2(0, 46)
	_time_label.size = Vector2(640, 18)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_time_label)

	_whisper_label = UIUtil.label("", 14, Color(0.85, 0.35, 0.35))
	_whisper_label.position = Vector2(0, 76)
	_whisper_label.size = Vector2(640, 22)
	_whisper_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_whisper_label)

	_center_label = UIUtil.label("", 22, Color(1, 1, 1))
	_center_label.position = Vector2(0, 150)
	_center_label.size = Vector2(640, 34)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_center_label)

	_help_label = UIUtil.label("← → (A / D) 번갈아 누르기 : 반죽\nSpace 누르고 있기 : 온 힘을 다해 반죽", 11, Color(0.75, 0.68, 0.60))
	_help_label.position = Vector2(0, 300)
	_help_label.size = Vector2(640, 40)
	_help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_help_label)


func _process(delta: float) -> void:
	_t += delta
	squish = move_toward(squish, 0.0, delta * 6.0)
	fumble = move_toward(fumble, 0.0, delta * 4.0)
	match state:
		State.READY:
			_ready_t -= delta
			_center_label.text = "준비…" if _ready_t > 0.5 else "시작!"
			if _ready_t <= 0.0:
				_center_label.text = ""
				state = State.PLAY
		State.PLAY:
			time_left -= delta
			if Input.is_action_pressed("knead_power"):
				power_time += delta
				_whisper_t -= delta
				if _whisper_t <= 0.0:
					_whisper_label.text = WHISPERS.pick_random()
					_whisper_t = 1.3
			else:
				_whisper_t = 0.0
				_whisper_label.text = ""
			if time_left <= 0.0:
				time_left = 0.0
				_finish()
	_time_label.text = "남은 시간 %.1f초" % time_left
	_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if state != State.PLAY:
		return
	var side := ""
	if event.is_action_pressed("knead_left"):
		side = "left"
	elif event.is_action_pressed("knead_right"):
		side = "right"
	if side == "":
		return
	get_viewport().set_input_as_handled()
	if side == last_side:
		fumble = 1.0  # 같은 손으로 연타 = 헛손질
		return
	last_side = side
	var gain := POWER_GAIN if Input.is_action_pressed("knead_power") else GAIN
	progress = minf(progress + gain * GameState.stamina_factor(), 100.0)
	squish = 1.0


func _finish() -> void:
	state = State.RESULT
	_whisper_label.text = ""
	var quality := roundi(progress)
	var effort := clampf(power_time / DURATION, 0.0, 1.0)
	_center_label.text = "빵 품질 %d  ·  %s" % [quality, GameState.grade_name(quality)]
	await get_tree().create_timer(1.8).timeout
	finished.emit({"quality": quality, "effort": effort})
	queue_free()


func _on_draw() -> void:
	var c := Vector2(320, 205)
	var shake := Vector2(sin(_t * 60.0) * 3.0 * fumble, 0)
	var p := progress / 100.0
	var effort := clampf(power_time / DURATION, 0.0, 1.0)

	# 반죽: 거친 색 → 매끈한 색, 힘을 줄수록 살색/붉은 기가 돈다
	var col := Color(0.86, 0.82, 0.72).lerp(Color(0.99, 0.94, 0.80), p)
	col = col.lerp(Color(0.95, 0.70, 0.65), effort * 0.8)
	var r := Vector2(70.0 * (1.0 + squish * 0.12), 38.0 * (1.0 - squish * 0.12))
	UIUtil.ellipse(_canvas, c + Vector2(0, 30) + shake, Vector2(110, 18), Color(0.25, 0.16, 0.10))  # 작업대 그림자
	UIUtil.ellipse(_canvas, c + shake, r, col, 32)
	# 거친 반죽 알갱이 (반죽이 진행될수록 사라짐)
	for i in 8:
		var a := float(i) * 0.785
		var dot := c + shake + Vector2(cos(a) * 40.0, sin(a) * 18.0)
		UIUtil.ellipse(_canvas, dot, Vector2(4, 2), Color(0.80, 0.75, 0.64, 1.0 - p))

	# 손 (누르는 쪽 손이 반죽을 누른다)
	var bun := Color(0.95, 0.77, 0.48)
	var left_down := 8.0 if last_side == "left" else 0.0
	var right_down := 8.0 if last_side == "right" else 0.0
	var lh := c + Vector2(-38, -30 + left_down * squish) + shake
	var rh := c + Vector2(38, -30 + right_down * squish) + shake
	if effort > 0.0:
		# 손과 반죽 사이에 늘어지는 반죽 가닥
		_canvas.draw_line(lh, c + Vector2(-30, -10), col, 1.0 + effort * 4.0)
		_canvas.draw_line(rh, c + Vector2(30, -10), col, 1.0 + effort * 4.0)
	UIUtil.ellipse(_canvas, lh, Vector2(14, 11), bun)
	UIUtil.ellipse(_canvas, rh, Vector2(14, 11), bun)

	# 게이지
	var bar := Rect2(170, 270, 300, 14)
	_canvas.draw_rect(bar.grow(2), Color(0.95, 0.84, 0.62))
	_canvas.draw_rect(bar, Color(0.18, 0.12, 0.08))
	_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * p, bar.size.y)), Color(0.95, 0.72, 0.30).lerp(Color(0.85, 0.30, 0.30), effort))
	for th in [30.0, 60.0, 85.0]:
		var x: float = bar.position.x + bar.size.x * th / 100.0
		_canvas.draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(1, 1, 1, 0.5), 1.0)

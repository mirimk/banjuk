extends Control
## 반죽 미니게임: 빨간 막대가 초록 구간에 왔을 때 3번 누른다 (클릭 또는 Space).
## 체력이 낮으면 초록 구간이 좁아지고, 반죽 손상이 높으면 막대가 빨라진다.

signal finished(type: String, score: float)

const D = preload("res://scripts/systems/game_data.gd")
const UIUtil = preload("res://scripts/systems/ui_util.gd")
const Art = preload("res://scripts/systems/art.gd")

const PANEL := Rect2(150, 64, 340, 214)
const BAR := Rect2(172, 176, 296, 18)

var type := "toast"
var pos := 0.0
var dir := 1.0
var speed := 0.85
var w := 0.18
var zc := 0.5
var hits: Array[float] = []
var done := false
var score := 0.0
var feedback := ""
var _end_t := 0.0
var _squish := 0.0
var _btn: Button


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_btn = UIUtil.button("반죽! (Space)", 14)
	_btn.position = Vector2(PANEL.position.x + 100, PANEL.end.y - 38)
	_btn.size = Vector2(140, 28)
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.button_down.connect(hit)
	add_child(_btn)


func start(bread_type: String, stamina: float, damage: float) -> void:
	type = bread_type
	pos = 0.0
	dir = 1.0
	w = 0.12 if stamina < 30.0 else 0.18
	speed = 0.85 + damage / 100.0 * 0.7
	zc = randf_range(0.25, 0.75)
	hits.clear()
	done = false
	feedback = ""
	_squish = 0.0
	_btn.disabled = false
	show()


static func word(s: float) -> String:
	if s >= 90.0:
		return "완벽!"
	if s >= 70.0:
		return "좋아요"
	if s >= 45.0:
		return "그럭저럭"
	return "아쉬워요"


func tick(dt: float) -> void:
	_squish = maxf(0.0, _squish - dt * 4.0)
	if done:
		_end_t -= dt
		if _end_t <= 0.0:
			hide()
			finished.emit(type, score)
		return
	pos += dir * speed * dt
	if pos > 1.0:
		pos = 1.0
		dir = -1.0
	elif pos < 0.0:
		pos = 0.0
		dir = 1.0
	queue_redraw()


func hit() -> void:
	if done or not visible:
		return
	var d := absf(pos - zc)
	var half := w / 2.0
	var s := 100.0 - (d / half) * 25.0 if d <= half else maxf(0.0, 60.0 - (d - half) * 300.0)
	hits.append(s)
	feedback = word(s)
	_squish = 1.0
	Sound.sfx("knead")
	if s >= 75.0:
		Sound.sfx("good")
	elif s < 45.0:
		Sound.sfx("bad")
	if hits.size() >= 3:
		done = true
		_end_t = 1.0
		score = (hits[0] + hits[1] + hits[2]) / 3.0
		feedback = "반죽 완성! 점수 %d — %s" % [int(score), word(score)]
		_btn.disabled = true
	else:
		zc = randf_range(0.2, 0.8)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.08, 0.05, 0.02, 0.55))
	UIUtil.rounded(self, PANEL, Color(1.0, 0.97, 0.92), Color(0.54, 0.35, 0.17), 10, 2)
	UIUtil.text(self, "%s 반죽하기" % D.BREADS[type].name, PANEL.position + Vector2(0, 26), 16, Color(0.35, 0.23, 0.12), HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x)
	Art.bread(self, type, PANEL.position + Vector2(PANEL.size.x - 34, 20), 1.4)
	var sq := sin(_squish * PI) * 0.25
	UIUtil.ellipse(self, PANEL.position + Vector2(PANEL.size.x / 2, 62), Vector2(52 * (1.0 + sq), 24 * (1.0 - sq)), Color(0.97, 0.91, 0.81))
	UIUtil.ellipse(self, PANEL.position + Vector2(PANEL.size.x / 2, 86), Vector2(56, 5), Color(0.79, 0.65, 0.49, 0.5))
	# 타이밍 막대
	UIUtil.rounded(self, BAR, Color(0.90, 0.83, 0.73), Color(0, 0, 0, 0), 9)
	var zr := Rect2(BAR.position.x + BAR.size.x * (zc - w / 2.0), BAR.position.y, BAR.size.x * w, BAR.size.y)
	draw_rect(zr, Color(0.50, 0.81, 0.53))
	draw_rect(Rect2(zr.get_center().x - 1, BAR.position.y, 2, BAR.size.y), Color(0.24, 0.56, 0.28))
	var mx := BAR.position.x + BAR.size.x * pos
	draw_rect(Rect2(mx - 3, BAR.position.y - 3, 6, BAR.size.y + 6), Color.WHITE)
	draw_rect(Rect2(mx - 2, BAR.position.y - 2, 4, BAR.size.y + 4), Color(0.75, 0.22, 0.17))
	# 3회 점수
	for i in 3:
		var r := Rect2(PANEL.position.x + 110 + i * 42, BAR.end.y + 6, 36, 16)
		var on := i < hits.size()
		UIUtil.rounded(self, r, Color(0.35, 0.64, 0.41) if on else Color(0.90, 0.83, 0.73), Color(0, 0, 0, 0), 4)
		UIUtil.text(self, str(int(hits[i])) if on else "·", r.position + Vector2(0, 12), 10, Color.WHITE if on else Color(0.5, 0.4, 0.3), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var fb := feedback if feedback != "" else "빨간 막대가 초록 구간에 왔을 때 누르세요!"
	UIUtil.text(self, fb, Vector2(PANEL.position.x, BAR.position.y - 8), 11, Color(0.35, 0.23, 0.12), HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x)


func _gui_input(event: InputEvent) -> void:
	# 패널 아무 곳이나 눌러도 반죽 (모바일 대비)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and PANEL.has_point(event.position):
		hit()

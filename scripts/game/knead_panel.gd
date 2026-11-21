extends Control
## 반죽 미니게임. 빵마다 방식이 다르다 (game_data BREADS[type].knead).
## - timing: 빨간 막대가 초록 구간에 왔을 때 3번 누른다 (탭 / 클릭 / Space)
## - rub: 반죽을 손가락(마우스)으로 좌우로 문질러 시간 안에 게이지를 채운다 (드래그 / ← → 번갈아 누르기)
## 체력이 낮으면 어려워지고(구간이 좁아지거나 더 많이 문질러야 함), 반죽 손상이 높으면 막대가 빨라지고 반죽이 끈적해진다.

signal finished(type: String, score: float)

const D = preload("res://scripts/systems/game_data.gd")
const UIUtil = preload("res://scripts/systems/ui_util.gd")
const Art = preload("res://scripts/systems/art.gd")

const PANEL := Rect2(150, 56, 340, 230)
const BAR := Rect2(172, 182, 296, 18)
const RUB_AREA := Rect2(170, 88, 300, 72)
const RUB_TIME := 5.0
const RUB_PERFECT := 2.6     # 이 시간 안에 채우면 만점

var type := "cream"
var mode := "timing"
# timing
var pos := 0.0
var dir := 1.0
var speed := 0.85
var w := 0.18
var zc := 0.5
var hits: Array[float] = []
# rub
var fill := 0.0
var need := 1800.0           # 채우는 데 필요한 문지른 거리(px)
var elapsed := 0.0
var _dragging := false
var _last_key := 0
var _dough_off := 0.0

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
	_btn.position = Vector2(PANEL.position.x + 100, PANEL.end.y - 36)
	_btn.size = Vector2(140, 28)
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.button_down.connect(hit)
	add_child(_btn)


func start(bread_type: String, stamina: float, damage: float) -> void:
	type = bread_type
	mode = D.BREADS[type].get("knead", "timing")
	done = false
	feedback = ""
	_squish = 0.0
	score = 0.0
	# timing
	pos = 0.0
	dir = 1.0
	var skill := D.mood_skill(float(GameState.s.get("mood", 60.0)))   # 기분이 낮으면 판정이 좁아짐
	w = (0.12 if stamina < 30.0 else 0.18) * skill
	speed = 0.85 + damage / 100.0 * 0.7 + (D.tier_of(type) - 1) * 0.12
	zc = randf_range(0.25, 0.75)
	hits.clear()
	# rub
	fill = 0.0
	elapsed = 0.0
	_dragging = false
	_last_key = 0
	_dough_off = 0.0
	need = 1700.0 / skill * (1.0 + damage / 100.0 * 0.5) * (1.3 if stamina < 30.0 else 1.0) * (1.0 + (D.tier_of(type) - 1) * 0.12)
	_btn.visible = mode == "timing"
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
	_dough_off = lerpf(_dough_off, 0.0, minf(1.0, dt * 6.0))
	if done:
		_end_t -= dt
		if _end_t <= 0.0:
			hide()
			finished.emit(type, score)
		return
	if mode == "timing":
		pos += dir * speed * dt
		if pos > 1.0:
			pos = 1.0
			dir = -1.0
		elif pos < 0.0:
			pos = 0.0
			dir = 1.0
	else:
		elapsed += dt
		if elapsed >= RUB_TIME:
			_finish_rub(false)
	queue_redraw()


## timing: 누르기 (rub 모드에서는 무시)
func hit() -> void:
	if done or not visible or mode != "timing":
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
		score = (hits[0] + hits[1] + hits[2]) / 3.0
		_done_with("반죽 완성! 점수 %d — %s" % [int(score), word(score)])
	else:
		zc = randf_range(0.2, 0.8)
	queue_redraw()


## rub: 문지른 거리만큼 게이지를 채운다
func rub(amount: float, dx: float = 0.0) -> void:
	if done or not visible or mode != "rub":
		return
	var before := int(fill * 8.0)
	fill = minf(1.0, fill + amount / need)
	_dough_off = clampf(_dough_off + dx * 0.15, -14.0, 14.0)
	if int(fill * 8.0) > before:
		Sound.sfx("knead")
		_squish = 1.0
	if fill >= 1.0:
		_finish_rub(true)


## 키보드: ← → 를 번갈아 누르면 문지르기
func key_rub(k: int) -> void:
	if mode != "rub" or done:
		return
	if k != _last_key:
		rub(80.0, 30.0 * k)
	_last_key = k


func _finish_rub(filled: bool) -> void:
	if filled:
		score = clampf(100.0 - maxf(0.0, elapsed - RUB_PERFECT) * 10.0, 0.0, 100.0)
	else:
		score = fill * 70.0
	if score >= 75.0:
		Sound.sfx("good")
	elif score < 45.0:
		Sound.sfx("bad")
	_done_with(("반죽 완성! " if filled else "시간 끝! ") + "점수 %d — %s" % [int(score), word(score)])


func _done_with(msg: String) -> void:
	done = true
	_end_t = 1.0
	feedback = msg
	_btn.disabled = true
	_dragging = false


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.08, 0.05, 0.02, 0.55))
	UIUtil.rounded(self, PANEL, Color(1.0, 0.97, 0.92), Color(0.54, 0.35, 0.17), 10, 2)
	var how := "타이밍 맞춰 누르기" if mode == "timing" else "문질러 치대기"
	UIUtil.text(self, "%s 반죽하기 · %s" % [D.BREADS[type].name, how], PANEL.position + Vector2(0, 24), 14, Color(0.35, 0.23, 0.12), HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x)
	Art.bread(self, type, PANEL.position + Vector2(PANEL.size.x - 26, 20), 1.1)
	var sq := sin(_squish * PI) * 0.25
	var dough_c := Color(0.97, 0.91, 0.81) if type != "wholewheat" else Color(0.84, 0.72, 0.56)
	if mode == "timing":
		UIUtil.ellipse(self, PANEL.position + Vector2(PANEL.size.x / 2, 66), Vector2(52 * (1.0 + sq), 24 * (1.0 - sq)), dough_c)
		UIUtil.ellipse(self, PANEL.position + Vector2(PANEL.size.x / 2, 90), Vector2(56, 5), Color(0.79, 0.65, 0.49, 0.5))
		_draw_timing()
	else:
		_draw_rub(dough_c, sq)
	var fb := feedback
	if fb == "":
		fb = "빨간 막대가 초록 구간에 왔을 때 누르세요!" if mode == "timing" else "반죽을 좌우로 문지르세요! (드래그 / ← →)"
	UIUtil.text(self, fb, Vector2(PANEL.position.x, BAR.position.y - 8), 11, Color(0.35, 0.23, 0.12), HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x)


func _draw_timing() -> void:
	UIUtil.rounded(self, BAR, Color(0.90, 0.83, 0.73), Color(0, 0, 0, 0), 9)
	var zr := Rect2(BAR.position.x + BAR.size.x * (zc - w / 2.0), BAR.position.y, BAR.size.x * w, BAR.size.y)
	draw_rect(zr, Color(0.50, 0.81, 0.53))
	draw_rect(Rect2(zr.get_center().x - 1, BAR.position.y, 2, BAR.size.y), Color(0.24, 0.56, 0.28))
	var mx := BAR.position.x + BAR.size.x * pos
	draw_rect(Rect2(mx - 3, BAR.position.y - 3, 6, BAR.size.y + 6), Color.WHITE)
	draw_rect(Rect2(mx - 2, BAR.position.y - 2, 4, BAR.size.y + 4), Color(0.75, 0.22, 0.17))
	for i in 3:
		var r := Rect2(PANEL.position.x + 110 + i * 42, BAR.end.y + 6, 36, 16)
		var on := i < hits.size()
		UIUtil.rounded(self, r, Color(0.35, 0.64, 0.41) if on else Color(0.90, 0.83, 0.73), Color(0, 0, 0, 0), 4)
		UIUtil.text(self, str(int(hits[i])) if on else "·", r.position + Vector2(0, 12), 10, Color.WHITE if on else Color(0.5, 0.4, 0.3), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_rub(dough_c: Color, sq: float) -> void:
	UIUtil.rounded(self, RUB_AREA, Color(0.93, 0.86, 0.74), Color(0.80, 0.68, 0.52), 8, 1)
	# 밀가루 자국
	for k in 7:
		draw_circle(RUB_AREA.position + Vector2(20 + k * 42, 62 - (k % 3) * 6), 1.5, Color(1, 1, 1, 0.6))
	var c := RUB_AREA.get_center() + Vector2(_dough_off, 2)
	var stretch := absf(_dough_off) / 14.0
	UIUtil.ellipse(self, c, Vector2(48 * (1.0 + sq * 0.6 + stretch * 0.25), 20 * (1.0 - sq * 0.4)), dough_c)
	UIUtil.ellipse(self, c + Vector2(-10, -8), Vector2(16, 5), Color(1, 1, 1, 0.45))
	# 좌우 화살표 안내
	var a := 0.4 + 0.3 * sin(elapsed * 8.0)
	UIUtil.text(self, "◀", RUB_AREA.position + Vector2(10, 42), 16, Color(0.54, 0.35, 0.17, a))
	UIUtil.text(self, "▶", RUB_AREA.position + Vector2(RUB_AREA.size.x - 26, 42), 16, Color(0.54, 0.35, 0.17, a))
	# 게이지 + 남은 시간
	UIUtil.rounded(self, BAR, Color(0.90, 0.83, 0.73), Color(0, 0, 0, 0), 9)
	draw_rect(Rect2(BAR.position, Vector2(BAR.size.x * fill, BAR.size.y)), Color(0.50, 0.81, 0.53))
	UIUtil.text(self, "%d%%" % int(fill * 100.0), BAR.position + Vector2(0, 14), 11, Color(0.2, 0.35, 0.2), HORIZONTAL_ALIGNMENT_CENTER, BAR.size.x)
	var left := maxf(0.0, RUB_TIME - elapsed)
	var tr := Rect2(BAR.position.x, BAR.end.y + 8, BAR.size.x, 6)
	draw_rect(tr, Color(0.90, 0.83, 0.73))
	draw_rect(Rect2(tr.position, Vector2(tr.size.x * left / RUB_TIME, tr.size.y)), Color(0.9, 0.3, 0.2).lerp(Color(0.95, 0.7, 0.3), left / RUB_TIME))
	UIUtil.text(self, "남은 시간 %.1f초" % left, tr.position + Vector2(0, 20), 9, Color(0.45, 0.32, 0.2), HORIZONTAL_ALIGNMENT_CENTER, tr.size.x)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and PANEL.has_point(event.position):
			if mode == "timing":
				hit()   # 패널 아무 곳이나 눌러도 반죽 (모바일 대비)
			else:
				_dragging = true
		elif not event.pressed:
			_dragging = false
	elif event is InputEventMouseMotion and mode == "rub" and (_dragging or (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0):
		var rel: Vector2 = event.relative
		rub(absf(rel.x) + absf(rel.y) * 0.4, rel.x)

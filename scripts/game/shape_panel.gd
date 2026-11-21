extends Control
## 성형 미니게임: 점선으로 그려진 모양을 손가락(마우스)으로 따라 그린다. 모바일 터치 대응.
## 점선을 많이 덮을수록, 선 밖으로 덜 벗어날수록 점수가 높다.
## 체력이 낮으면 판정 폭이 좁아지고, 반죽 손상이 높으면 손이 떨린다(선이 흔들림).

signal finished(slot: int, score: float)

const D = preload("res://scripts/systems/game_data.gd")
const UIUtil = preload("res://scripts/systems/ui_util.gd")
const Art = preload("res://scripts/systems/art.gd")

const PANEL := Rect2(140, 50, 360, 252)
const AREA := Rect2(170, 92, 300, 136)
const TIME := 7.0
const STEP := 7.0

const HOW := {
	"zigzag": "가위집을 지그재그로 내요",
	"oval": "속을 넣고 타원으로 오므려요",
	"square": "네모난 틀 모양을 잡아요",
	"fold": "반죽을 세 번 접어요",
	"slash": "칼집(쿠프)을 3번 내요",
	"circle": "동그랗게 둥글려요",
}

var slot := 0
var type := "sausage"
var shape := "zigzag"
var guide: Array[Vector2] = []
var covered: Array[bool] = []
var trail: Array = []          # 그린 선들 (PackedVector2Array 배열)
var radius := 13.0
var shake := 0.0
var elapsed := 0.0
var off_samples := 0
var on_samples := 0
var done := false
var score := 0.0
var feedback := ""
var _end_t := 0.0
var _drawing := false
var _btn_done: Button
var _btn_cancel: Button


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_done = UIUtil.button("다 됐어요", 12)
	_btn_done.position = Vector2(PANEL.position.x + 186, PANEL.end.y - 32)
	_btn_done.size = Vector2(90, 24)
	_btn_done.focus_mode = Control.FOCUS_NONE
	_btn_done.pressed.connect(func() -> void: _finish("성형 끝!"))
	add_child(_btn_done)
	_btn_cancel = UIUtil.button("취소", 12)
	_btn_cancel.position = Vector2(PANEL.position.x + 84, PANEL.end.y - 32)
	_btn_cancel.size = Vector2(90, 24)
	_btn_cancel.focus_mode = Control.FOCUS_NONE
	_btn_cancel.pressed.connect(func() -> void:
		if done:
			return
		hide()
		finished.emit(slot, -1.0))
	add_child(_btn_cancel)


func start(slot_idx: int, bread_type: String, stamina: float, damage: float) -> void:
	slot = slot_idx
	type = bread_type
	shape = D.BREADS[type].get("shape", "circle")
	radius = (10.0 if stamina < 30.0 else 13.0) * D.mood_skill(float(GameState.s.get("mood", 60.0)))   # 기분이 낮으면 판정이 좁아짐
	shake = damage / 100.0 * 7.0
	elapsed = 0.0
	off_samples = 0
	on_samples = 0
	done = false
	score = 0.0
	feedback = ""
	trail.clear()
	_drawing = false
	_build_guide()
	_btn_done.disabled = false
	_btn_cancel.disabled = false
	show()


## 모양별 점선 경로 (여러 획 가능)
func _strokes() -> Array:
	var c := AREA.get_center()
	var out := []
	match shape:
		"zigzag":
			var pts := PackedVector2Array()
			for k in 9:
				pts.append(Vector2(AREA.position.x + 30 + k * 30, c.y + (-24.0 if k % 2 == 0 else 24.0)))
			out.append(pts)
		"oval":
			out.append(_ellipse_pts(c, Vector2(100, 42)))
		"circle":
			out.append(_ellipse_pts(c, Vector2(52, 52)))
		"square":
			out.append(PackedVector2Array([c + Vector2(-80, -44), c + Vector2(80, -44), c + Vector2(80, 44), c + Vector2(-80, 44), c + Vector2(-80, -44)]))
		"fold":
			out.append(PackedVector2Array([c + Vector2(-100, -40), c + Vector2(100, -40), c + Vector2(100, 0), c + Vector2(-100, 0), c + Vector2(-100, 40), c + Vector2(100, 40)]))
		"slash":
			for k in 3:
				var x := c.x - 80 + k * 80
				out.append(PackedVector2Array([Vector2(x - 26, c.y + 30), Vector2(x + 26, c.y - 30)]))
	return out


static func _ellipse_pts(c: Vector2, r: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * float(i) / 40.0 - PI / 2.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


func _build_guide() -> void:
	guide.clear()
	covered.clear()
	for stroke in _strokes():
		for i in range(stroke.size() - 1):
			var a: Vector2 = stroke[i]
			var b: Vector2 = stroke[i + 1]
			var n := maxi(1, int(a.distance_to(b) / STEP))
			for k in n:
				guide.append(a.lerp(b, float(k) / n))
		guide.append(stroke[stroke.size() - 1])
	covered.resize(guide.size())
	covered.fill(false)


func coverage() -> float:
	if guide.is_empty():
		return 0.0
	return float(covered.count(true)) / guide.size()


func tick(dt: float) -> void:
	if done:
		_end_t -= dt
		if _end_t <= 0.0:
			hide()
			finished.emit(slot, score)
		return
	elapsed += dt
	if elapsed >= TIME:
		_finish("시간 끝!")
	queue_redraw()


## 그리기 점 하나 추가 (손 떨림 반영) → 근처 점선을 덮는다
func trace(p: Vector2) -> void:
	if done or not visible:
		return
	if shake > 0.0:
		p += Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	if trail.is_empty() or not _drawing:
		trail.append(PackedVector2Array([p]))
		_drawing = true
	else:
		var last: PackedVector2Array = trail[trail.size() - 1]
		last.append(p)
		trail[trail.size() - 1] = last
	var best := INF
	for i in guide.size():
		var d := guide[i].distance_to(p)
		best = minf(best, d)
		if d <= radius:
			covered[i] = true
	if best > radius * 1.7:
		off_samples += 1
	else:
		on_samples += 1
	if coverage() >= 0.97:
		_finish("완벽하게 따라 그렸어요!")


func _finish(msg: String) -> void:
	if done:
		return
	var off_ratio := float(off_samples) / maxf(1.0, off_samples + on_samples)
	score = clampf(coverage() * 105.0 - off_ratio * 45.0, 0.0, 100.0)
	done = true
	_end_t = 1.0
	_drawing = false
	_btn_done.disabled = true
	_btn_cancel.disabled = true
	feedback = "%s 점수 %d" % [msg, int(score)]
	Sound.sfx("good" if score >= 70.0 else ("click" if score >= 45.0 else "bad"))


## 테스트용: 점선 전체를 따라 그린다
func debug_trace_all() -> void:
	_drawing = false
	for g in guide:
		trace(g)
		_drawing = true


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.08, 0.05, 0.02, 0.55))
	UIUtil.rounded(self, PANEL, Color(1.0, 0.97, 0.92), Color(0.54, 0.35, 0.17), 10, 2)
	UIUtil.text(self, "%s 성형하기" % D.BREADS[type].name, PANEL.position + Vector2(0, 22), 14, Color(0.35, 0.23, 0.12), HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x)
	UIUtil.text(self, HOW.get(shape, "") + " — 점선을 따라 그리세요", PANEL.position + Vector2(0, 36), 9, Color(0.54, 0.35, 0.17), HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x)
	Art.bread(self, type, PANEL.position + Vector2(PANEL.size.x - 26, 22), 1.0)
	# 작업판 + 반죽
	UIUtil.rounded(self, AREA, Color(0.93, 0.86, 0.74), Color(0.80, 0.68, 0.52), 8, 1)
	var dough_c := Color(0.97, 0.91, 0.81) if type != "wholewheat" else Color(0.84, 0.72, 0.56)
	var c := AREA.get_center()
	match shape:
		"circle":
			UIUtil.ellipse(self, c, Vector2(62, 58), dough_c)
		"oval":
			UIUtil.ellipse(self, c, Vector2(116, 52), dough_c)
		_:
			UIUtil.rounded(self, Rect2(c - Vector2(124, 56), Vector2(248, 112)), dough_c, Color(0, 0, 0, 0), 24)
	# 점선 (덮은 곳은 초록)
	for i in guide.size():
		draw_circle(guide[i], 2.6 if covered[i] else 2.0, Color(0.30, 0.68, 0.36) if covered[i] else Color(0.55, 0.42, 0.30, 0.7))
	# 그린 선
	for line in trail:
		if line.size() >= 2:
			draw_polyline(line, Color(0.62, 0.36, 0.16, 0.85), 3.0, true)
	# 진행도 / 시간
	var bar := Rect2(AREA.position.x, AREA.end.y + 8, AREA.size.x, 8)
	UIUtil.rounded(self, bar, Color(0.90, 0.83, 0.73), Color(0, 0, 0, 0), 4)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * coverage(), bar.size.y)), Color(0.50, 0.81, 0.53))
	var left := maxf(0.0, TIME - elapsed)
	draw_rect(Rect2(bar.position + Vector2(0, 11), Vector2(bar.size.x * left / TIME, 3)), Color(0.9, 0.45, 0.2))
	var fb := feedback if feedback != "" else "따라 그린 정도 %d%% · 남은 시간 %.1f초" % [int(coverage() * 100.0), left]
	UIUtil.text(self, fb, Vector2(PANEL.position.x, bar.end.y + 16), 10, Color(0.35, 0.23, 0.12), HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x)


func _gui_input(event: InputEvent) -> void:
	if done:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and AREA.grow(10).has_point(event.position):
			_drawing = false
			trace(event.position)
		elif not event.pressed:
			_drawing = false
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and AREA.grow(10).has_point(event.position):
		trace(event.position)

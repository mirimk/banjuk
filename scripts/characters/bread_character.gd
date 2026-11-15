extends Node2D
## 임시 캐릭터: 도형으로 그린 빵 캐릭터들.
## 원점(0,0)은 발밑 중앙. 좌우 반전은 scale.x 로 한다.

const UIUtil = preload("res://scripts/systems/ui_util.gd")

## "banjuk"(주인공) / "boss"(사장) / "crew"(크루) / "child"(꼬마 손님)
@export var kind: String = "banjuk"
var walking := false
var stain := 0.0  # 손에 묻은 반죽 0~1
## 반죽 손상 0~100: 높을수록 몸이 반죽처럼 허옇게 질척해지고 손에 반죽이 들러붙는다
var damage := 0.0

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var bob := 0.0
	if walking:
		bob = -absf(sin(_t * 12.0)) * 2.0
	else:
		bob = sin(_t * 2.0) * 0.6
	match kind:
		"banjuk":
			_draw_banjuk(bob)
		"boss":
			_draw_boss(bob)
		"crew":
			_draw_crew(bob)
		"child":
			_draw_child(bob)


func _draw_banjuk(bob: float) -> void:
	var t := clampf(damage / 100.0, 0.0, 1.0)
	var dough_col := Color(0.93, 0.90, 0.82)
	var crust := Color(0.80, 0.52, 0.26).lerp(dough_col.darkened(0.1), t * 0.7)
	var bun := Color(0.95, 0.77, 0.48).lerp(dough_col, t * 0.8)
	var st := maxf(stain, t)
	var o := Vector2(0, bob)
	# 발
	draw_rect(Rect2(Vector2(-8, -3) + o, Vector2(5, 3)), Color(0.45, 0.28, 0.15))
	draw_rect(Rect2(Vector2(3, -3) + o, Vector2(5, 3)), Color(0.45, 0.28, 0.15))
	# 몸통
	UIUtil.ellipse(self, Vector2(0, -14) + o, Vector2(15, 12), bun)
	UIUtil.ellipse(self, Vector2(0, -19) + o, Vector2(13, 7), crust)
	# 팔(손)
	UIUtil.ellipse(self, Vector2(-15, -10) + o, Vector2(3.5, 3.5), bun)
	UIUtil.ellipse(self, Vector2(15, -10) + o, Vector2(3.5, 3.5), bun)
	# 손에 붙은 반죽
	if st > 0.05:
		var dough := Color(0.88, 0.85, 0.76)
		UIUtil.ellipse(self, Vector2(16, -9) + o, Vector2(2.5 + st * 2.0, 2.0 + st * 2.5), dough)
		draw_line(Vector2(16, -7) + o, Vector2(16.5, -4 + st * 3.0) + o, dough, 1.5)
		if st > 0.5:
			UIUtil.ellipse(self, Vector2(-16, -9) + o, Vector2(1.5 + st * 1.5, 1.5 + st * 2.0), dough)
			draw_line(Vector2(-16, -7) + o, Vector2(-16.5, -5 + st * 2.0) + o, dough, 1.2)
	# 얼굴
	draw_circle(Vector2(-5, -13) + o, 1.6, Color(0.15, 0.08, 0.05))
	draw_circle(Vector2(5, -13) + o, 1.6, Color(0.15, 0.08, 0.05))
	UIUtil.ellipse(self, Vector2(-9, -9) + o, Vector2(2.5, 1.4), Color(0.98, 0.58, 0.55))
	UIUtil.ellipse(self, Vector2(9, -9) + o, Vector2(2.5, 1.4), Color(0.98, 0.58, 0.55))
	draw_line(Vector2(-1.5, -10) + o, Vector2(1.5, -10) + o, Color(0.3, 0.15, 0.08), 1.0)


func _draw_boss(bob: float) -> void:
	var white := Color(0.97, 0.96, 0.92)
	var skin := Color(0.96, 0.82, 0.68)
	var o := Vector2(0, bob * 0.5)
	# 다리
	draw_rect(Rect2(Vector2(-8, -10) + o, Vector2(6, 10)), Color(0.25, 0.22, 0.22))
	draw_rect(Rect2(Vector2(2, -10) + o, Vector2(6, 10)), Color(0.25, 0.22, 0.22))
	# 몸 + 앞치마
	draw_rect(Rect2(Vector2(-12, -38) + o, Vector2(24, 30)), Color(0.85, 0.82, 0.76))
	draw_rect(Rect2(Vector2(-9, -32) + o, Vector2(18, 26)), white)
	draw_rect(Rect2(Vector2(-6, -24) + o, Vector2(12, 6)), Color(0.88, 0.86, 0.80))
	# 팔
	draw_rect(Rect2(Vector2(-16, -36) + o, Vector2(5, 18)), Color(0.85, 0.82, 0.76))
	draw_rect(Rect2(Vector2(11, -36) + o, Vector2(5, 18)), Color(0.85, 0.82, 0.76))
	# 머리
	draw_circle(Vector2(0, -45) + o, 8.0, skin)
	# 감은 눈(웃는 눈)
	draw_line(Vector2(-5, -46) + o, Vector2(-2, -47) + o, Color(0.2, 0.12, 0.08), 1.2)
	draw_line(Vector2(2, -47) + o, Vector2(5, -46) + o, Color(0.2, 0.12, 0.08), 1.2)
	# 콧수염
	UIUtil.ellipse(self, Vector2(-3, -41) + o, Vector2(3.5, 1.6), Color(0.75, 0.75, 0.75))
	UIUtil.ellipse(self, Vector2(3, -41) + o, Vector2(3.5, 1.6), Color(0.75, 0.75, 0.75))
	# 제빵사 모자
	draw_rect(Rect2(Vector2(-8, -60) + o, Vector2(16, 8)), white)
	draw_circle(Vector2(-6, -62) + o, 5.0, white)
	draw_circle(Vector2(0, -65) + o, 6.0, white)
	draw_circle(Vector2(6, -62) + o, 5.0, white)


func _draw_crew(bob: float) -> void:
	var gold := Color(0.86, 0.58, 0.24)
	var dark := Color(0.62, 0.38, 0.14)
	var o := Vector2(0, bob)
	draw_rect(Rect2(Vector2(-7, -3) + o, Vector2(4, 3)), Color(0.40, 0.25, 0.12))
	draw_rect(Rect2(Vector2(3, -3) + o, Vector2(4, 3)), Color(0.40, 0.25, 0.12))
	# 크루아상 마디 (오른쪽 끝 마디만 색이 바래 있다... 이미 흡수된 흔적)
	var xs := [-16.0, -8.0, 0.0, 8.0, 16.0]
	for i in xs.size():
		var x: float = xs[i]
		var t := absf(x) / 16.0
		var y := -16.0 + t * t * 7.0
		var r := Vector2(6.5 - t * 2.0, 10.0 - t * 4.0)
		var col := gold
		if i == xs.size() - 1:
			col = Color(0.80, 0.74, 0.62)
		UIUtil.ellipse(self, Vector2(x, y) + o, r, col)
		if i > 0:
			draw_line(Vector2(x - 4, y - r.y * 0.8) + o, Vector2(x - 4, y + r.y * 0.8) + o, dark, 1.0)
	# 반쯤 감긴 눈
	draw_line(Vector2(-6, -18) + o, Vector2(-2, -18) + o, Color(0.2, 0.1, 0.05), 1.2)
	draw_line(Vector2(2, -18) + o, Vector2(6, -18) + o, Color(0.2, 0.1, 0.05), 1.2)
	draw_circle(Vector2(-4, -16.8) + o, 1.0, Color(0.2, 0.1, 0.05))
	draw_circle(Vector2(4, -16.8) + o, 1.0, Color(0.2, 0.1, 0.05))
	draw_line(Vector2(-2, -12) + o, Vector2(2, -12.5) + o, Color(0.35, 0.18, 0.08), 1.0)


func _draw_child(bob: float) -> void:
	var bun := Color(0.99, 0.88, 0.66)
	var o := Vector2(0, bob)
	draw_rect(Rect2(Vector2(-5, -2) + o, Vector2(3, 2)), Color(0.6, 0.3, 0.3))
	draw_rect(Rect2(Vector2(2, -2) + o, Vector2(3, 2)), Color(0.6, 0.3, 0.3))
	UIUtil.ellipse(self, Vector2(0, -10) + o, Vector2(10, 9), bun)
	# 리본
	UIUtil.ellipse(self, Vector2(-4, -19) + o, Vector2(4, 2.5), Color(0.95, 0.45, 0.60))
	UIUtil.ellipse(self, Vector2(4, -19) + o, Vector2(4, 2.5), Color(0.95, 0.45, 0.60))
	draw_circle(Vector2(0, -19) + o, 1.5, Color(0.80, 0.30, 0.45))
	draw_circle(Vector2(-3.5, -10) + o, 1.4, Color(0.15, 0.08, 0.05))
	draw_circle(Vector2(3.5, -10) + o, 1.4, Color(0.15, 0.08, 0.05))
	draw_arc(Vector2(0, -8) + o, 2.0, 0.2, PI - 0.2, 6, Color(0.4, 0.15, 0.1), 1.0)

extends RefCounted
## 임시 도형 아트: 빵, 손님, 비밀 손님. 픽셀아트 에셋이 들어오면 스프라이트로 교체한다.

const UIUtil = preload("res://scripts/systems/ui_util.gd")

const BREAD_COLORS := {
	"toast": Color(0.86, 0.60, 0.30),
	"croissant": Color(0.88, 0.60, 0.25),
	"baguette": Color(0.83, 0.59, 0.31),
	"bagel": Color(0.78, 0.52, 0.26),
}


## 빵 하나. col 을 주면 그 색으로(오븐 굽기 색), alpha 로 투명도.
static func bread(ci: CanvasItem, type: String, center: Vector2, sc: float = 1.0, col: Color = Color(0, 0, 0, 0), alpha: float = 1.0) -> void:
	var c: Color = col if col.a > 0.0 else BREAD_COLORS.get(type, Color(0.85, 0.6, 0.3))
	c.a = alpha
	var dark := c.darkened(0.25)
	var light := c.lightened(0.35)
	ci.draw_set_transform(center, 0.0, Vector2(sc, sc))
	match type:
		"toast":
			ci.draw_rect(Rect2(-9, -5, 18, 10), c)
			UIUtil.ellipse(ci, Vector2(0, -5), Vector2(9.5, 5), c)
			UIUtil.ellipse(ci, Vector2(0, -6), Vector2(6.5, 2.5), light)
			ci.draw_rect(Rect2(-9, 3, 18, 2), dark)
		"croissant":
			var xs := [-10.0, -5.0, 0.0, 5.0, 10.0]
			for i in xs.size():
				var x: float = xs[i]
				var t := absf(x) / 10.0
				UIUtil.ellipse(ci, Vector2(x, t * t * 5.0 - 1.0), Vector2(4.4 - t * 1.4, 6.0 - t * 2.5), c if i % 2 == 0 else dark.lerp(c, 0.5))
		"baguette":
			ci.draw_set_transform(center, -0.25, Vector2(sc, sc))
			UIUtil.ellipse(ci, Vector2.ZERO, Vector2(15, 4.5), c)
			for k in 3:
				var x := -7.0 + k * 7.0
				ci.draw_line(Vector2(x - 2, -2), Vector2(x + 2, 1), light, 1.2)
		"bagel":
			ci.draw_arc(Vector2.ZERO, 5.5, 0.0, TAU, 24, c, 5.0)
			ci.draw_arc(Vector2(0, -0.5), 5.5, PI * 1.15, PI * 1.85, 10, light, 1.2)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 손님 한 명. feet = 발밑 중앙. p = GameData.PROFILES 의 항목.
static func person(ci: CanvasItem, feet: Vector2, p: Dictionary, sc: float = 1.0, alpha: float = 1.0) -> void:
	ci.draw_set_transform(feet, 0.0, Vector2(sc, sc))
	var h: float = p.get("h", 1.0)
	var skin: Color = p.get("skin", Color(0.9, 0.75, 0.6))
	var hair: Color = p.get("hair", Color.BLACK)
	var cloth: Color = p.get("cloth", Color.GRAY)
	var acc: String = p.get("acc", "")
	var style: String = p.get("style", "short")
	skin.a = alpha
	hair.a = alpha
	cloth.a = alpha
	var ink := Color(0.15, 0.08, 0.05, alpha)
	var seated := acc == "wheelchair"
	var leg := 0.0 if seated else 12.0 * h
	var base := -9.0 if seated else 0.0
	var body_h := 14.0 * h
	var top := base - leg - body_h

	if seated:
		var metal := Color(0.45, 0.45, 0.50, alpha)
		ci.draw_arc(Vector2(1, -7), 7.0, 0.0, TAU, 20, metal, 2.0)
		ci.draw_circle(Vector2(1, -7), 1.5, metal)
		ci.draw_line(Vector2(-7, top + 2), Vector2(-7, base + 1), metal, 2.0)
		ci.draw_rect(Rect2(-8, base - 1, 16, 2), metal)
		ci.draw_rect(Rect2(-3, base - 3, 12, 3.5), cloth.darkened(0.4))
		ci.draw_rect(Rect2(7, base - 3, 3, 9), cloth.darkened(0.4))
	else:
		var pants := cloth.darkened(0.4)
		ci.draw_rect(Rect2(-5, -leg, 4, leg), pants)
		ci.draw_rect(Rect2(1, -leg, 4, leg), pants)
	# 몸 / 팔 / 손
	ci.draw_rect(Rect2(-7, top, 14, body_h), cloth)
	ci.draw_rect(Rect2(-9.5, top + 1, 2.5, body_h * 0.8), cloth.darkened(0.12))
	ci.draw_rect(Rect2(7, top + 1, 2.5, body_h * 0.8), cloth.darkened(0.12))
	ci.draw_circle(Vector2(-8.2, top + body_h * 0.85), 1.6, skin)
	ci.draw_circle(Vector2(8.2, top + body_h * 0.85), 1.6, skin)
	if acc == "tie":
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-1.2, top), Vector2(1.2, top), Vector2(0.8, top + 8), Vector2(0, top + 9.5), Vector2(-0.8, top + 8)]), Color(0.75, 0.15, 0.2, alpha))
	if acc == "cane":
		ci.draw_line(Vector2(9, top + body_h * 0.85), Vector2(11, 0), Color(0.4, 0.25, 0.12, alpha), 1.5)

	var head := Vector2(0, top - 6.5)
	# 머리 뒤쪽 머리카락
	if style == "long":
		UIUtil.ellipse(ci, head + Vector2(0, 3), Vector2(7, 8.5), hair)
	elif style == "pigtails":
		ci.draw_circle(head + Vector2(-7.5, 1), 3.0, hair)
		ci.draw_circle(head + Vector2(7.5, 1), 3.0, hair)
	elif style == "bun":
		ci.draw_circle(head + Vector2(0, -7.5), 3.2, hair)
	if acc == "hijab":
		UIUtil.ellipse(ci, head + Vector2(0, 2), Vector2(8, 9.5), Color(0.22, 0.55, 0.55, alpha))
		ci.draw_circle(head + Vector2(0, 0.5), 5.0, skin)
	else:
		ci.draw_circle(head, 6.0, skin)
		match style:
			"short", "long", "pigtails", "bun":
				UIUtil.ellipse(ci, head + Vector2(0, -3.6), Vector2(6.3, 3.0), hair)
			"bob":
				UIUtil.ellipse(ci, head + Vector2(0, -3.2), Vector2(6.9, 4.0), hair)
				ci.draw_rect(Rect2(-6.9, head.y - 3, 2.2, 7), hair)
				ci.draw_rect(Rect2(4.7, head.y - 3, 2.2, 7), hair)
			"curly":
				for k in 5:
					ci.draw_circle(head + Vector2(-6 + k * 3, -4.5 + absf(k - 2) * 0.8), 2.4, hair)
			"bald":
				UIUtil.ellipse(ci, head + Vector2(-5.6, -0.5), Vector2(1.4, 2.4), hair)
				UIUtil.ellipse(ci, head + Vector2(5.6, -0.5), Vector2(1.4, 2.4), hair)
	# 모자류
	if acc == "turban":
		UIUtil.ellipse(ci, head + Vector2(0, -4.5), Vector2(7.2, 4.5), Color(0.92, 0.55, 0.15, alpha))
	elif acc == "cap":
		UIUtil.ellipse(ci, head + Vector2(0, -4.0), Vector2(6.3, 3.2), Color(0.25, 0.35, 0.65, alpha))
		ci.draw_rect(Rect2(0, head.y - 4.2, 8, 1.6), Color(0.2, 0.28, 0.55, alpha))
	elif acc == "hat":
		ci.draw_rect(Rect2(-8.5, head.y - 4.5, 17, 1.8), Color(0.85, 0.75, 0.50, alpha))
		ci.draw_rect(Rect2(-5, head.y - 9, 10, 4.8), Color(0.85, 0.75, 0.50, alpha))
		ci.draw_rect(Rect2(-5, head.y - 6, 10, 1.4), Color(0.6, 0.25, 0.2, alpha))
	# 얼굴
	ci.draw_circle(head + Vector2(-2.2, 0.3), 0.9, ink)
	ci.draw_circle(head + Vector2(2.2, 0.3), 0.9, ink)
	ci.draw_line(head + Vector2(-1.2, 3.0), head + Vector2(1.2, 3.0), ink, 0.8)
	if p.get("beard", false):
		UIUtil.ellipse(ci, head + Vector2(0, 3.6), Vector2(4.6, 2.8), hair)
	if p.get("glasses", false):
		ci.draw_arc(head + Vector2(-2.3, 0.3), 1.9, 0.0, TAU, 12, ink, 0.6)
		ci.draw_arc(head + Vector2(2.3, 0.3), 1.9, 0.0, TAU, 12, ink, 0.6)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 비밀스러운 손님: 검은 외투와 챙 넓은 모자, 얼굴이 보이지 않는다.
static func secret_guest(ci: CanvasItem, feet: Vector2, sc: float = 1.0, alpha: float = 1.0, t: float = 0.0) -> void:
	ci.draw_set_transform(feet, 0.0, Vector2(sc, sc))
	var glow := 0.18 + 0.08 * sin(t * 2.0)
	UIUtil.ellipse(ci, Vector2(0, -24), Vector2(18, 28), Color(0.42, 0.25, 0.71, glow * alpha))
	var coat := Color(0.10, 0.08, 0.12, alpha)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-6, -36), Vector2(6, -36), Vector2(10, 0), Vector2(-10, 0)]), coat)
	ci.draw_line(Vector2(0, -34), Vector2(0, -2), Color(0.25, 0.2, 0.3, alpha), 0.8)
	ci.draw_circle(Vector2(0, -41), 5.5, Color(0.18, 0.15, 0.2, alpha))
	ci.draw_rect(Rect2(-10, -46, 20, 2), coat)
	ci.draw_rect(Rect2(-5.5, -52, 11, 6.5), coat)
	var eye := Color(0.85, 0.75, 1.0, (0.55 + 0.3 * sin(t * 3.0)) * alpha)
	ci.draw_circle(Vector2(-2, -41), 0.9, eye)
	ci.draw_circle(Vector2(2, -41), 0.9, eye)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 오븐 굽기 진행도(0~1.45)에 따른 빵 색
static func oven_color(b: float) -> Color:
	var stops := [
		[0.0, Color(0.96, 0.89, 0.75)],
		[0.6, Color(0.93, 0.78, 0.50)],
		[0.95, Color(0.84, 0.55, 0.24)],
		[1.15, Color(0.55, 0.29, 0.12)],
		[1.45, Color(0.15, 0.10, 0.07)],
	]
	for i in range(1, stops.size()):
		if b <= stops[i][0]:
			var a0: float = stops[i - 1][0]
			var a1: float = stops[i][0]
			var c0: Color = stops[i - 1][1]
			var c1: Color = stops[i][1]
			return c0.lerp(c1, (b - a0) / (a1 - a0))
	return stops[stops.size() - 1][1]

extends RefCounted
## 임시 도형 아트: 빵, 손님, 비밀 손님. 픽셀아트 에셋이 들어오면 스프라이트로 교체한다.

const UIUtil = preload("res://scripts/systems/ui_util.gd")

const BREAD_COLORS := {
	"cream": Color(0.92, 0.70, 0.38),
	"redbean": Color(0.62, 0.36, 0.18),
	"choco": Color(0.86, 0.60, 0.30),
	"soboro": Color(0.88, 0.64, 0.32),
	"sausage": Color(0.88, 0.62, 0.32),
	"croquette": Color(0.76, 0.48, 0.20),
	"sandwich": Color(0.95, 0.84, 0.62),
	"ciabatta": Color(0.86, 0.70, 0.48),
	"baguette": Color(0.83, 0.59, 0.31),
	"wholewheat": Color(0.55, 0.36, 0.20),
}


## 빵 하나. col 을 주면 그 색으로(오븐 굽기 색), alpha 로 투명도. 크기는 대략 가로 30 · 세로 16 (sc=1)
static func bread(ci: CanvasItem, type: String, center: Vector2, sc: float = 1.0, col: Color = Color(0, 0, 0, 0), alpha: float = 1.0) -> void:
	var baked := col.a <= 0.0
	var c: Color = col if not baked else BREAD_COLORS.get(type, Color(0.85, 0.6, 0.3))
	c.a = alpha
	var dark := c.darkened(0.25)
	var light := c.lightened(0.35)
	var white := Color(1.0, 0.98, 0.94, alpha)
	ci.draw_set_transform(center, 0.0, Vector2(sc, sc))
	match type:
		"cream":
			# 반달 모양 + 가운데 크림
			ci.draw_colored_polygon(_half_disc(Vector2(0, 3), Vector2(12, 9)), c)
			ci.draw_rect(Rect2(-12, 3, 24, 2), dark)
			UIUtil.ellipse(ci, Vector2(0, -2), Vector2(7, 2.2), light)
			if baked:
				ci.draw_line(Vector2(-9, 3), Vector2(9, 3), Color(1.0, 0.95, 0.70, alpha), 2.0)
		"redbean":
			UIUtil.ellipse(ci, Vector2(0, 0), Vector2(10, 7), c)
			UIUtil.ellipse(ci, Vector2(-2, -3), Vector2(5, 2), light)
			ci.draw_circle(Vector2(0, -1), 1.6, Color(0.25, 0.12, 0.08, alpha))
			for d in [Vector2(-4, -2), Vector2(3, -3), Vector2(5, 0), Vector2(-5, 1)]:
				ci.draw_circle(d, 0.6, Color(0.95, 0.92, 0.85, alpha))
		"choco":
			# 소라 모양 콘 + 입구의 초코
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-13, 0), Vector2(8, -7), Vector2(8, 7)]), c)
			for k in 4:
				var x := -9.0 + k * 4.5
				ci.draw_line(Vector2(x, -1.0 - k * 1.3), Vector2(x + 2.5, 1.0 + k * 1.5), dark, 1.2)
			UIUtil.ellipse(ci, Vector2(8, 0), Vector2(3, 7), dark)
			UIUtil.ellipse(ci, Vector2(8.5, 0), Vector2(2.2, 5.5), Color(0.30, 0.16, 0.08, alpha))
		"soboro":
			UIUtil.ellipse(ci, Vector2(0, 1), Vector2(11, 7), dark)
			var bumps := [Vector2(-7, -1), Vector2(-3, -4), Vector2(2, -4), Vector2(6, -2), Vector2(-5, 2), Vector2(0, 0), Vector2(5, 2), Vector2(8, 1), Vector2(-8, 3), Vector2(2, 4)]
			for i in bumps.size():
				ci.draw_circle(bumps[i], 2.2, light if i % 2 == 0 else c.lightened(0.15))
		"sausage":
			UIUtil.ellipse(ci, Vector2(0, 0), Vector2(14, 6), c)
			if baked:
				for k in 4:
					UIUtil.ellipse(ci, Vector2(-9 + k * 6, -1 + (k % 2) * 1.5), Vector2(2.6, 2.0), Color(0.80, 0.35, 0.28, alpha))
				var z := PackedVector2Array()
				for k in 9:
					z.append(Vector2(-11 + k * 2.75, -2.5 + (k % 2) * 2.5))
				ci.draw_polyline(z, Color(0.95, 0.80, 0.20, alpha), 0.9)
			else:
				for k in 4:
					ci.draw_line(Vector2(-9 + k * 6, -4), Vector2(-7 + k * 6, 3), dark, 1.2)
		"croquette":
			UIUtil.ellipse(ci, Vector2(0, 0), Vector2(12, 7), c)
			for d in [Vector2(-7, -2), Vector2(-3, -4), Vector2(1, -2), Vector2(5, -4), Vector2(8, 0), Vector2(-5, 2), Vector2(0, 3), Vector2(4, 2), Vector2(-9, 1)]:
				ci.draw_rect(Rect2(d, Vector2(1.6, 1.4)), light)
			for d in [Vector2(-5, -1), Vector2(3, 0), Vector2(-1, -4), Vector2(7, 3)]:
				ci.draw_rect(Rect2(d, Vector2(1.4, 1.2)), dark)
		"sandwich":
			# 삼각 샌드위치: 빵 - 상추 - 햄 - 치즈 - 빵
			var tri := func(off: float, w: float, h: float) -> PackedVector2Array:
				return PackedVector2Array([Vector2(-w, off), Vector2(w, off), Vector2(0, off - h)])
			if baked:
				ci.draw_colored_polygon(tri.call(6.0, 12.0, 13.0), Color(0.80, 0.62, 0.38, alpha))
				ci.draw_colored_polygon(tri.call(4.5, 12.5, 12.0), Color(0.40, 0.70, 0.30, alpha))
				ci.draw_colored_polygon(tri.call(3.0, 12.0, 11.0), Color(0.92, 0.55, 0.55, alpha))
				ci.draw_colored_polygon(tri.call(1.5, 11.5, 10.0), Color(0.98, 0.82, 0.30, alpha))
				ci.draw_colored_polygon(tri.call(0.0, 11.0, 10.0), c)
				ci.draw_colored_polygon(tri.call(-1.0, 9.5, 8.0), white.lerp(c, 0.4))
			else:
				ci.draw_rect(Rect2(-11, -6, 22, 12), c)
				ci.draw_rect(Rect2(-11, -6, 22, 2), dark)
		"ciabatta":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-13, 4), Vector2(-12, -3), Vector2(-6, -6), Vector2(6, -5), Vector2(13, -2), Vector2(12, 5), Vector2(0, 6)]), c)
			ci.draw_line(Vector2(-12, 4.5), Vector2(12, 5), dark, 1.5)
			for d in [Vector2(-8, -3), Vector2(-3, -1), Vector2(2, -4), Vector2(7, -1), Vector2(-5, 2), Vector2(4, 2), Vector2(9, 2), Vector2(0, 0)]:
				ci.draw_circle(d, 0.9, Color(1, 1, 1, 0.75 * alpha))
		"baguette":
			ci.draw_set_transform(center, -0.25, Vector2(sc, sc))
			UIUtil.ellipse(ci, Vector2.ZERO, Vector2(15, 4.5), c)
			for k in 3:
				var x := -7.0 + k * 7.0
				ci.draw_line(Vector2(x - 2, -2), Vector2(x + 2, 1), light, 1.2)
		"wholewheat":
			UIUtil.ellipse(ci, Vector2(0, 0), Vector2(10, 8), c)
			ci.draw_line(Vector2(-5, -4), Vector2(5, 3), light, 1.6)
			ci.draw_line(Vector2(5, -4), Vector2(-5, 3), light, 1.6)
			for d in [Vector2(-7, 0), Vector2(6, 1), Vector2(0, -6), Vector2(-2, 5), Vector2(3, -2), Vector2(-4, -3)]:
				ci.draw_rect(Rect2(d, Vector2(1.2, 0.8)), Color(0.85, 0.72, 0.50, alpha))
		_:
			UIUtil.ellipse(ci, Vector2.ZERO, Vector2(10, 6), c)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 반죽 덩어리 (아직 굽기 전). shaped 면 빵 모양을 따라간다.
static func dough(ci: CanvasItem, type: String, center: Vector2, sc: float, rise: float, shaped: bool) -> void:
	var col := Color(0.97, 0.91, 0.81)
	if type == "wholewheat":
		col = Color(0.84, 0.72, 0.56)
	if shaped:
		bread(ci, type, center, sc * (0.85 + rise * 0.2), col)
		return
	var sz := 0.8 + minf(rise, 1.1) * 0.6
	var flat := rise > 1.25
	UIUtil.ellipse(ci, center, Vector2(11.0 * sz * sc, 7.0 * sz * sc * (0.6 if flat else 1.0)), col)
	UIUtil.ellipse(ci, center + Vector2(-3, -3) * sc, Vector2(4.0 * sz * sc, 1.8 * sz * sc), Color(1, 1, 1, 0.5))


static func _half_disc(center: Vector2, r: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


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
	elif acc == "helmet":
		UIUtil.ellipse(ci, head + Vector2(0, -2.5), Vector2(7.4, 5.6), Color(0.95, 0.35, 0.25, alpha))
		ci.draw_rect(Rect2(-6.5, head.y - 1.0, 13, 2.2), Color(0.25, 0.30, 0.40, alpha))
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

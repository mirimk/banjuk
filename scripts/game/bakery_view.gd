extends Control
## 빵집 화면: 3단 진열대(단계별 선반), 카운터, 손님 줄, 배달 주문표.
## 진열대는 빵 종류마다 그림 하나 + 개수로 표시한다. 탭하면 카운터 손님(또는 배달 주문)에게 건넨다.

signal hit(what: String, idx: int)

const D = preload("res://scripts/systems/game_data.gd")
const UIUtil = preload("res://scripts/systems/ui_util.gd")
const Art = preload("res://scripts/systems/art.gd")

const SHELF := Rect2(10, 42, 292, 248)
const ROW_H := 74.0
const COUNTER := Rect2(310, 236, 330, 90)
const AT_FEET := Vector2(418, 262)
const BUBBLE := Rect2(310, 36, 222, 84)
const SLIP := Rect2(538, 36, 98, 182)
const RIDER_PROFILE := {"skin": Color(0.90, 0.72, 0.56), "hair": Color(0.1, 0.08, 0.06), "style": "short", "h": 1.0, "cloth": Color(0.20, 0.55, 0.75), "acc": "helmet"}

var S: Dictionary
var sorry_btn: Button
var deliv_btn: Button
var _t := 0.0


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	sorry_btn = UIUtil.button("죄송해요, 지금 없어요", 10)
	sorry_btn.position = Vector2(470, 292)
	sorry_btn.focus_mode = Control.FOCUS_NONE
	sorry_btn.pressed.connect(func() -> void: hit.emit("sorry", 0))
	add_child(sorry_btn)
	deliv_btn = UIUtil.button("주문 거절", 9)
	var sb := UIUtil.panel_style(Color(0.30, 0.20, 0.14), Color(0.55, 0.40, 0.28), 1)
	sb.set_content_margin_all(2)
	deliv_btn.add_theme_stylebox_override("normal", sb)
	deliv_btn.position = Vector2(SLIP.position.x + 14, SLIP.end.y - 30)
	deliv_btn.size = Vector2(70, 18)
	deliv_btn.focus_mode = Control.FOCUS_NONE
	deliv_btn.pressed.connect(func() -> void: hit.emit("deliv_cancel", 0))
	add_child(deliv_btn)


static func row_types(tier: int) -> Array:
	return D.BREAD_ORDER.filter(func(t: String) -> bool: return D.tier_of(t) == tier)


static func row_rect(tier: int) -> Rect2:
	return Rect2(SHELF.position.x + 6, SHELF.position.y + 20 + (tier - 1) * (ROW_H + 2), SHELF.size.x - 12, ROW_H)


static func cell(type: String) -> Rect2:
	var tier := D.tier_of(type)
	var types := row_types(tier)
	var rr := row_rect(tier)
	var w := rr.size.x / types.size()
	var i := types.find(type)
	return Rect2(rr.position.x + i * w, rr.position.y, w, rr.size.y - 6)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	for i in D.BREAD_ORDER.size():
		var t: String = D.BREAD_ORDER[i]
		if cell(t).has_point(event.position) and D.tier_unlocked(D.tier_of(t), int(S.day)) and count(t) > 0:
			hit.emit("give", i)
			return


func count(type: String) -> int:
	var n := 0
	for b in S.shelf:
		if b.type == type:
			n += 1
	return n


func best_grade(type: String) -> String:
	var best := -1
	var g := ""
	for b in S.shelf:
		if b.type == type and int(b.q) > best:
			best = int(b.q)
			g = b.g
	return g


func _active() -> Array:
	return S.customers.filter(func(c: Dictionary) -> bool: return c.state != "leaving")


func _draw() -> void:
	if S.is_empty():
		return
	# 벽 / 줄무늬 / 창문 / 문 / 바닥
	draw_rect(Rect2(0, 0, 640, 245), Color(0.96, 0.86, 0.71))
	for x in range(0, 640, 30):
		draw_rect(Rect2(x, 32, 15, 213), Color(1, 1, 1, 0.22))
	draw_rect(Rect2(0, 245, 640, 115), Color(0.66, 0.44, 0.26))
	for x in range(0, 640, 40):
		draw_line(Vector2(x, 245), Vector2(x - 20, 360), Color(0.58, 0.38, 0.22), 1.0)
	UIUtil.rounded(self, Rect2(330, 128, 150, 70), Color(0.62, 0.84, 0.95), Color(1.0, 0.95, 0.87), 4, 6)
	draw_rect(Rect2(336, 178, 138, 14), Color(0.78, 0.75, 0.70))
	draw_circle(Vector2(356, 170), 10.0, Color(0.35, 0.62, 0.32))
	draw_circle(Vector2(456, 168), 12.0, Color(0.30, 0.58, 0.30))
	UIUtil.rounded(self, Rect2(560, 60, 66, 186), Color(0.48, 0.29, 0.14), Color(0.35, 0.20, 0.09), 30, 4)
	draw_circle(Vector2(612, 156), 3.5, Color(1.0, 0.83, 0.42))
	UIUtil.rounded(self, Rect2(570, 210, 46, 16), Color(1.0, 0.95, 0.87), Color(0.35, 0.20, 0.09), 3, 1)
	UIUtil.text(self, "OPEN", Vector2(570, 222), 9, Color(0.48, 0.29, 0.14), HORIZONTAL_ALIGNMENT_CENTER, 46)

	_draw_shelf()

	# 손님 (줄 선 순서대로, 맨 앞이 카운터)
	var act := _active()
	for i in range(mini(act.size(), 4) - 1, -1, -1):
		var c: Dictionary = act[i]
		var feet := AT_FEET if i == 0 else Vector2(486 + (i - 1) * 30, 248)
		var sc := 2.4 if i == 0 else 1.5
		_draw_customer(c, feet, sc, 1.0 if i == 0 else 0.92)
	# 문 앞의 배달 라이더
	if S.delivery != null and S.delivery.state == "wait":
		Art.person(self, Vector2(612, 246), RIDER_PROFILE, 1.5, 1.0)
		UIUtil.rounded(self, Rect2(618, 210, 16, 14), Color(0.20, 0.55, 0.75), Color(0.1, 0.3, 0.45), 2, 1)
	var leaving: Array = S.customers.filter(func(c: Dictionary) -> bool: return c.state == "leaving")
	if not leaving.is_empty():
		var lc: Dictionary = leaving[leaving.size() - 1]
		_draw_customer(lc, Vector2(584, 248), 1.5, 0.45)
		_say_bubble(lc.say, Vector2(626, 214))

	# 카운터
	draw_rect(COUNTER, Color(0.60, 0.39, 0.22))
	draw_rect(Rect2(COUNTER.position, Vector2(COUNTER.size.x, 14)), Color(0.83, 0.60, 0.38))
	draw_rect(Rect2(COUNTER.position + Vector2(0, 14), Vector2(COUNTER.size.x, 2)), Color(0.48, 0.29, 0.14))
	UIUtil.rounded(self, Rect2(326, 214, 36, 24), Color(0.35, 0.35, 0.38), Color(0.2, 0.2, 0.22), 3, 1)
	draw_rect(Rect2(331, 218, 26, 8), Color(0.55, 0.85, 0.6))
	if S.time_up and act.is_empty():
		UIUtil.rounded(self, Rect2(370, 150, 120, 30), Color(1.0, 0.95, 0.87), Color(0.48, 0.29, 0.14), 6, 2)
		UIUtil.text(self, "영업 종료", Vector2(370, 171), 15, Color(0.48, 0.29, 0.14), HORIZONTAL_ALIGNMENT_CENTER, 120)

	# 카운터 손님 말풍선
	if not act.is_empty():
		_draw_bubble(act[0])
	sorry_btn.visible = not act.is_empty()
	_draw_delivery()


func _draw_shelf() -> void:
	var day := int(S.day)
	UIUtil.rounded(self, SHELF, Color(0.77, 0.54, 0.33), Color(0.54, 0.35, 0.17), 6, 5)
	for tier in [1, 2, 3]:
		var rr := row_rect(tier)
		var unlocked := D.tier_unlocked(tier, day)
		draw_rect(Rect2(rr.position.x, rr.end.y - 5, rr.size.x, 5), Color(0.54, 0.35, 0.17))
		for t in row_types(tier):
			var r := cell(t)
			var n := count(t)
			var center := r.position + Vector2(r.size.x / 2, 28)
			if unlocked and n > 0:
				UIUtil.rounded(self, r.grow(-2), Color(1, 1, 1, 0.16), Color(0, 0, 0, 0), 5)
			Art.bread(self, t, center, 2.0, Color(0, 0, 0, 0), 1.0 if (unlocked and n > 0) else 0.3)
			var label: String = D.BREADS[t].name
			if unlocked and n > 0:
				label += " " + D.fmt_money(float(D.sale_price(t, best_grade(t))))
			UIUtil.text(self, label, r.position + Vector2(0, r.size.y - 8), 8, Color(1.0, 0.97, 0.92, 1.0 if unlocked else 0.5), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			if not unlocked:
				continue
			if n > 0:
				# 개수 배지
				var badge := Rect2(r.end.x - 26, r.position.y + 3, 23, 14)
				UIUtil.rounded(self, badge, Color(0.25, 0.16, 0.10, 0.9), Color(1.0, 0.95, 0.87), 7, 1)
				UIUtil.text(self, "x%d" % n, badge.position + Vector2(0, 11), 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x)
				# 다음에 나갈 빵 등급
				var g := best_grade(t)
				draw_circle(Vector2(r.position.x + 10, r.position.y + 10), 6.5, D.grade_info(g).color)
				UIUtil.text(self, g, Vector2(r.position.x + 4, r.position.y + 13.5), 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 12)
			else:
				UIUtil.text(self, "품절", center + Vector2(-20, 4), 9, Color(1.0, 0.95, 0.87, 0.75), HORIZONTAL_ALIGNMENT_CENTER, 40)
		if not unlocked:
			UIUtil.rounded(self, Rect2(rr.position.x, rr.position.y + 2, rr.size.x, rr.size.y - 10), Color(0.15, 0.10, 0.06, 0.6), Color(0, 0, 0, 0), 5)
			UIUtil.text(self, "잠김", Vector2(rr.position.x, rr.position.y + 38), 14, Color(1.0, 0.95, 0.87), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
	UIUtil.tag(self, "진열대 · 등급별 값 " + D.grade_price_text(), SHELF.position + Vector2(SHELF.size.x / 2, -1), 8)


func _draw_customer(c: Dictionary, feet: Vector2, sc: float, alpha: float) -> void:
	if c.get("secret", false):
		Art.secret_guest(self, feet, sc * 0.95, alpha, _t)
	else:
		Art.person(self, feet, D.PROFILES[int(c.p)], sc, alpha)


func _say_bubble(text: String, right_anchor: Vector2) -> void:
	var w := minf(260.0, UIUtil.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 16.0)
	UIUtil.rounded(self, Rect2(right_anchor - Vector2(w, 0), Vector2(w, 20)), Color.WHITE, Color(0.6, 0.5, 0.4), 6, 1)
	UIUtil.text(self, text, right_anchor + Vector2(8 - w, 14), 10, Color(0.2, 0.15, 0.1), HORIZONTAL_ALIGNMENT_LEFT, w - 12)


func _draw_bubble(c: Dictionary) -> void:
	var secret: bool = c.get("secret", false)
	var r := BUBBLE
	var bg := Color(0.18, 0.14, 0.25) if secret else Color.WHITE
	var fg := Color(0.91, 0.86, 1.0) if secret else Color(0.23, 0.16, 0.10)
	UIUtil.rounded(self, r, bg, Color(0.6, 0.5, 0.4) if not secret else Color(0.49, 0.36, 0.77), 8, 1)
	draw_colored_polygon(PackedVector2Array([Vector2(400, r.end.y - 1), Vector2(416, r.end.y - 1), Vector2(410, r.end.y + 10)]), bg)
	var pr: Dictionary = D.SECRET if secret else D.PROFILES[int(c.p)]
	UIUtil.text(self, pr.name, r.position + Vector2(10, 15), 11, fg)
	var nw := UIUtil.FONT.get_string_size(pr.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	UIUtil.text(self, pr.desc, r.position + Vector2(16 + nw, 15), 8, Color(fg, 0.6))
	UIUtil.text_wrap(self, "\"%s\"" % c.line, r.position + Vector2(10, 30), r.size.x - 20, 9, Color(fg, 0.75), 2)
	var req: String = c.get("req", "")
	if not secret:
		req = "%s 하나 주세요." % D.BREADS[c.want].name
		if count(c.want) == 0:
			req += " (없음)"
	UIUtil.text(self, req, r.position + Vector2(10, 62), 11, fg)
	if c.get("say2", "") != "":
		UIUtil.rounded(self, Rect2(r.position + Vector2(0, r.size.y + 12), Vector2(r.size.x, 18)), Color(1.0, 0.92, 0.90), Color(0.85, 0.2, 0.15), 5, 1)
		UIUtil.text(self, c.say2, r.position + Vector2(8, r.size.y + 25), 9, Color(0.75, 0.15, 0.1), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16)
	var pat := clampf(float(c.pat), 0.0, 1.0)
	var pw := (r.size.x - 20) * pat
	draw_rect(Rect2(r.position + Vector2(10, 72), Vector2(r.size.x - 20, 5)), Color(0.9, 0.9, 0.9))
	var pc := Color(0.9, 0.3, 0.2).lerp(Color(0.2, 0.75, 0.4), pat)
	if pat < 0.3 and fmod(_t, 0.4) < 0.2:
		pc = Color(1.0, 0.15, 0.1)
	draw_rect(Rect2(r.position + Vector2(10, 72), Vector2(pw, 5)), pc)


func _draw_delivery() -> void:
	var dv = S.delivery
	deliv_btn.visible = dv != null and dv.state == "wait"
	if dv == null:
		if int(S.day) >= D.DELIVERY_START and not S.time_up and int(S.deliv_left) > 0:
			UIUtil.rounded(self, Rect2(SLIP.position, Vector2(SLIP.size.x, 22)), Color(1, 1, 1, 0.5), Color(0.6, 0.5, 0.4), 5, 1)
			UIUtil.text(self, "배달 대기 중…", SLIP.position + Vector2(0, 15), 9, Color(0.4, 0.3, 0.2), HORIZONTAL_ALIGNMENT_CENTER, SLIP.size.x)
		return
	var r := SLIP
	UIUtil.rounded(self, r, Color(0.98, 0.98, 0.94), Color(0.20, 0.55, 0.75), 6, 2)
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 16)), Color(0.20, 0.55, 0.75))
	UIUtil.text(self, "배달 주문", r.position + Vector2(0, 14), 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	UIUtil.text(self, str(dv.rider).replace("빵배달 라이더 ", "라이더 "), r.position + Vector2(0, 29), 8, Color(0.3, 0.3, 0.35), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var y := r.position.y + 36
	for it in dv.items:
		var got: bool = it.got != null
		Art.bread(self, it.type, Vector2(r.position.x + 16, y + 9), 0.9, Color(0, 0, 0, 0), 0.45 if got else 1.0)
		UIUtil.text(self, D.BREADS[it.type].name, Vector2(r.position.x + 30, y + 13), 9, Color(0.5, 0.5, 0.5) if got else Color(0.2, 0.15, 0.1))
		if got:
			draw_polyline(PackedVector2Array([Vector2(r.end.x - 16, y + 9), Vector2(r.end.x - 12, y + 13), Vector2(r.end.x - 5, y + 4)]), Color(0.25, 0.65, 0.3), 2.0)
		y += 20
	if dv.state == "leaving":
		UIUtil.text_wrap(self, dv.say, Vector2(r.position.x + 6, r.end.y - 34), r.size.x - 12, 8, Color(0.2, 0.4, 0.55), 3)
		return
	UIUtil.text(self, "수수료 %d%%" % int(D.DELIVERY_FEE * 100), Vector2(r.position.x, r.end.y - 46), 8, Color(0.6, 0.3, 0.2), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var pat := clampf(float(dv.pat), 0.0, 1.0)
	draw_rect(Rect2(r.position + Vector2(8, r.size.y - 40), Vector2(r.size.x - 16, 5)), Color(0.88, 0.88, 0.88))
	draw_rect(Rect2(r.position + Vector2(8, r.size.y - 40), Vector2((r.size.x - 16) * pat, 5)), Color(0.9, 0.3, 0.2).lerp(Color(0.2, 0.55, 0.75), pat))

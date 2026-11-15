extends Control
## 빵집 화면: 진열대, 카운터, 손님 줄. 진열대의 빵을 클릭하면 카운터 손님에게 건넨다.

signal hit(what: String, idx: int)

const D = preload("res://scripts/systems/game_data.gd")
const UIUtil = preload("res://scripts/systems/ui_util.gd")
const Art = preload("res://scripts/systems/art.gd")

const SHELF := Rect2(16, 48, 282, 236)
const COUNTER := Rect2(310, 236, 330, 90)
const AT_FEET := Vector2(418, 262)

var S: Dictionary
var sorry_btn: Button
var _t := 0.0


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	sorry_btn = UIUtil.button("죄송해요, 지금 없어요", 10)
	sorry_btn.position = Vector2(500, 286)
	sorry_btn.focus_mode = Control.FOCUS_NONE
	sorry_btn.pressed.connect(func() -> void: hit.emit("sorry", 0))
	add_child(sorry_btn)


static func shelf_cell(i: int) -> Rect2:
	var cw := (SHELF.size.x - 16) / 5.0
	var ch := (SHELF.size.y - 30) / 3.0
	return Rect2(SHELF.position.x + 8 + (i % 5) * cw, SHELF.position.y + 22 + int(i / 5) * ch, cw, ch)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	for i in D.SHELF_MAX:
		if shelf_cell(i).has_point(event.position) and i < S.shelf.size():
			hit.emit("give", i)
			return


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
	UIUtil.rounded(self, Rect2(320, 44, 166, 96), Color(0.62, 0.84, 0.95), Color(1.0, 0.95, 0.87), 4, 6)
	draw_rect(Rect2(326, 116, 154, 18), Color(0.78, 0.75, 0.70))
	draw_circle(Vector2(350, 104), 12.0, Color(0.35, 0.62, 0.32))
	draw_rect(Rect2(348, 110, 4, 10), Color(0.45, 0.30, 0.18))
	draw_circle(Vector2(456, 100), 14.0, Color(0.30, 0.58, 0.30))
	draw_rect(Rect2(454, 108, 4, 12), Color(0.45, 0.30, 0.18))
	UIUtil.rounded(self, Rect2(560, 60, 66, 186), Color(0.48, 0.29, 0.14), Color(0.35, 0.20, 0.09), 30, 4)
	draw_circle(Vector2(612, 156), 3.5, Color(1.0, 0.83, 0.42))
	UIUtil.rounded(self, Rect2(570, 96, 46, 16), Color(1.0, 0.95, 0.87), Color(0.35, 0.20, 0.09), 3, 1)
	UIUtil.text(self, "OPEN", Vector2(570, 108), 9, Color(0.48, 0.29, 0.14), HORIZONTAL_ALIGNMENT_CENTER, 46)

	# 진열대
	UIUtil.rounded(self, SHELF, Color(0.77, 0.54, 0.33), Color(0.54, 0.35, 0.17), 6, 5)
	for row in 3:
		var y := shelf_cell(row * 5).end.y
		draw_rect(Rect2(SHELF.position.x + 6, y - 4, SHELF.size.x - 12, 5), Color(0.54, 0.35, 0.17))
	for i in D.SHELF_MAX:
		if i >= S.shelf.size():
			continue
		var b: Dictionary = S.shelf[i]
		var cell := shelf_cell(i)
		var center := cell.position + Vector2(cell.size.x / 2, cell.size.y - 22)
		Art.bread(self, b.type, center, 2.2)
		var gi := D.grade_info(b.g)
		draw_circle(cell.position + Vector2(cell.size.x - 9, cell.size.y - 13), 6.0, gi.color)
		UIUtil.text(self, b.g, cell.position + Vector2(cell.size.x - 15, cell.size.y - 9.5), 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 12)
	if S.shelf.is_empty():
		UIUtil.text(self, "진열대가 비었어요…", SHELF.position + Vector2(0, 130), 12, Color(1, 0.95, 0.87), HORIZONTAL_ALIGNMENT_CENTER, SHELF.size.x)
	UIUtil.tag(self, "진열대 %d/%d" % [S.shelf.size(), D.SHELF_MAX], SHELF.position + Vector2(SHELF.size.x / 2, -1))

	# 손님 (줄 선 순서대로, 맨 앞이 카운터)
	var act := _active()
	for i in range(mini(act.size(), 4) - 1, -1, -1):
		var c: Dictionary = act[i]
		var feet := AT_FEET if i == 0 else Vector2(492 + (i - 1) * 34, 248)
		var sc := 2.4 if i == 0 else 1.5
		_draw_customer(c, feet, sc, 1.0 if i == 0 else 0.92)
	var leaving: Array = S.customers.filter(func(c: Dictionary) -> bool: return c.state == "leaving")
	if not leaving.is_empty():
		var lc: Dictionary = leaving[leaving.size() - 1]
		_draw_customer(lc, Vector2(596, 248), 1.5, 0.45)
		var w := minf(220.0, UIUtil.FONT.get_string_size(lc.say, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 16.0)
		UIUtil.rounded(self, Rect2(Vector2(620 - w, 158), Vector2(w, 20)), Color.WHITE, Color(0.6, 0.5, 0.4), 6, 1)
		UIUtil.text(self, lc.say, Vector2(628 - w, 172), 10, Color(0.2, 0.15, 0.1), HORIZONTAL_ALIGNMENT_LEFT, w - 12)

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


func _draw_customer(c: Dictionary, feet: Vector2, sc: float, alpha: float) -> void:
	if c.get("secret", false):
		Art.secret_guest(self, feet, sc * 0.95, alpha, _t)
	else:
		Art.person(self, feet, D.PROFILES[int(c.p)], sc, alpha)


func _draw_bubble(c: Dictionary) -> void:
	var secret: bool = c.get("secret", false)
	var r := Rect2(310, 36, 250, 84)
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
		if not S.shelf.any(func(b: Dictionary) -> bool: return b.type == c.want):
			req += "  (진열대에 없음)"
	UIUtil.text(self, req, r.position + Vector2(10, 62), 11, fg)
	if c.get("say2", "") != "":
		UIUtil.text(self, c.say2, r.position + Vector2(10, 62), 9, Color(0.85, 0.2, 0.15), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 20)
	var pw := (r.size.x - 20) * clampf(float(c.pat), 0.0, 1.0)
	draw_rect(Rect2(r.position + Vector2(10, 72), Vector2(r.size.x - 20, 4)), Color(0.9, 0.9, 0.9))
	draw_rect(Rect2(r.position + Vector2(10, 72), Vector2(pw, 4)), Color(0.9, 0.3, 0.2).lerp(Color(0.2, 0.75, 0.4), clampf(float(c.pat), 0.0, 1.0)))

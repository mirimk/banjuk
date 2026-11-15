extends Control
## 퇴근 후: 정산(영수증) → 집(번 돈으로 보상 하나 고르기) → 잠들기.
## GameState.screen 이 "settle" 이면 정산, "home" 이면 집 화면.

const D = preload("res://scripts/systems/game_data.gd")
const UIUtil = preload("res://scripts/systems/ui_util.gd")
const Hud = preload("res://scripts/game/hud.gd")
const BreadCharacter = preload("res://scripts/characters/bread_character.gd")

var S: Dictionary
var _content: Control
var _t := 0.0


func _ready() -> void:
	S = GameState.s
	Sound.bgm("home")
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	add_child(Hud.new())
	_build()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _build() -> void:
	for c in _content.get_children():
		c.queue_free()
	if GameState.screen == "settle":
		_build_settle()
	else:
		_build_home()


# ---------------------------------------------------------------- 정산

func _build_settle() -> void:
	var t: Dictionary = S.today
	var panel := PanelContainer.new()
	var sb := UIUtil.panel_style(Color(1.0, 0.99, 0.97), Color(0.8, 0.75, 0.68), 1)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(200, 44)
	panel.custom_minimum_size = Vector2(240, 0)
	_content.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var ink := Color(0.23, 0.16, 0.10)
	var title := UIUtil.label("%d일차 정산" % int(S.day), 18, ink)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UIUtil.label("빵집 「반죽」 · 18:00 퇴근", 9, Color(0.54, 0.49, 0.42))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	_row(box, "만든 빵", "%d개" % int(t.made))
	_row(box, "판매한 빵", "%d개" % int(t.sold))
	_row(box, "그냥 돌아간 손님", "%d명" % int(t.missed))
	_row(box, "버려진 반죽 · 남은 빵", "%d개 · %d개" % [int(t.lost), int(t.discarded)])
	_row(box, "팁", D.fmt_money(float(t.tips)))
	box.add_child(HSeparator.new())
	_row(box, "오늘 매출", D.fmt_money(float(t.revenue)), 14)
	_row(box, "현재 소지금", D.fmt_money(float(S.money)))
	var btn := UIUtil.button("집으로", 13)
	btn.pressed.connect(_go_home)
	box.add_child(btn)
	btn.grab_focus()


func _row(box: VBoxContainer, k: String, v: String, size: int = 11) -> void:
	var row := HBoxContainer.new()
	var a := UIUtil.label(k, size, Color(0.23, 0.16, 0.10))
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(a)
	row.add_child(UIUtil.label(v, size, Color(0.23, 0.16, 0.10)))
	box.add_child(row)


func _go_home() -> void:
	if GameState.busy:
		return
	Sound.sfx("door")
	await GameState.transition("집", "19:00 · 퇴근 후", func() -> void:
		GameState.screen = "home"
		S.screen = "home"
		_build())


# ---------------------------------------------------------------- 집

func _build_home() -> void:
	var panel := PanelContainer.new()
	var sb := UIUtil.panel_style(Color(1.0, 0.97, 0.92, 0.97), Color(0.54, 0.35, 0.17), 2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(84, 52)
	panel.custom_minimum_size = Vector2(472, 0)
	_content.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var ink := Color(0.23, 0.16, 0.10)

	if S.night == "":
		box.add_child(UIUtil.label("%d일차 밤 · 오늘 번 돈으로 무엇을 할까?" % int(S.day), 15, ink))
		box.add_child(UIUtil.label("하나만 고를 수 있어요. (보상 상세는 기획 확정 후 조정 예정)", 9, Color(0.42, 0.31, 0.25)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		for r in D.REWARDS:
			var b := UIUtil.button("%s\n%s\n\n%s" % [r.name, "무료" if int(r.cost) == 0 else D.fmt_money(float(r.cost)), r.desc], 10)
			b.custom_minimum_size = Vector2(110, 96)
			b.disabled = int(S.money) < int(r.cost)
			b.pressed.connect(_take_reward.bind(r.id))
			row.add_child(b)
	else:
		var r := _reward(S.night)
		var title := UIUtil.label(r.name, 18, ink)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)
		var msg := UIUtil.label(r.msg, 12, ink)
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg.custom_minimum_size = Vector2(440, 0)
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(msg)
		var label := "잠들기 → 이야기 마무리" if int(S.day) >= D.LAST_DAY else "잠들기 → %d일차 출근" % (int(S.day) + 1)
		var btn := UIUtil.button(label, 13)
		btn.pressed.connect(func() -> void:
			if not GameState.busy:
				GameState.next_day())
		box.add_child(btn)
		btn.grab_focus()


func _reward(id: String) -> Dictionary:
	for r in D.REWARDS:
		if r.id == id:
			return r
	return D.REWARDS[0]


func _take_reward(id: String) -> void:
	var r := _reward(id)
	if int(S.money) < int(r.cost):
		GameState.toast("돈이 부족해요")
		Sound.sfx("bad")
		return
	S.money = int(S.money) - int(r.cost)
	GameState.add_stat("stamina", float(r.st))
	GameState.add_stat("damage", float(r.dmg))
	GameState.add_stat("mood", float(r.mood))
	S.night = id
	Sound.sfx("great")
	_build()


# ---------------------------------------------------------------- 배경

func _draw() -> void:
	if GameState.screen == "settle":
		draw_rect(Rect2(0, 0, 640, 360), Color(0.16, 0.11, 0.08))
		UIUtil.ellipse(self, Vector2(320, 190), Vector2(300, 160), Color(0.29, 0.20, 0.14))
		return
	# 밤의 방: 창문(달), 침대, 책상과 노트북, 스탠드
	draw_rect(Rect2(0, 0, 640, 252), Color(0.24, 0.23, 0.36))
	draw_rect(Rect2(0, 252, 640, 108), Color(0.36, 0.27, 0.21))
	UIUtil.rounded(self, Rect2(470, 50, 140, 100), Color(0.08, 0.10, 0.23), Color(0.54, 0.48, 0.42), 4, 6)
	draw_circle(Vector2(580, 78), 12.0, Color(1.0, 0.95, 0.75))
	draw_circle(Vector2(586, 74), 11.0, Color(0.08, 0.10, 0.23))
	for p in [Vector2(490, 70), Vector2(520, 110), Vector2(545, 66), Vector2(500, 130)]:
		draw_circle(p, 1.0 + 0.5 * sin(_t * 2.0 + p.x), Color(1, 1, 1, 0.8))
	UIUtil.rounded(self, Rect2(24, 236, 210, 60), Color(0.91, 0.85, 0.94), Color(0.48, 0.35, 0.54), 10, 4)
	UIUtil.rounded(self, Rect2(32, 222, 60, 24), Color.WHITE, Color(0.8, 0.8, 0.85), 8, 1)
	draw_rect(Rect2(470, 250, 150, 8), Color(0.54, 0.38, 0.25))
	draw_rect(Rect2(480, 258, 6, 50), Color(0.45, 0.31, 0.2))
	draw_rect(Rect2(604, 258, 6, 50), Color(0.45, 0.31, 0.2))
	draw_rect(Rect2(520, 226, 46, 26), Color(0.25, 0.25, 0.28))
	draw_rect(Rect2(523, 229, 40, 20), Color(0.45, 0.75, 0.95, 0.6 + 0.2 * sin(_t * 3.0)))
	draw_rect(Rect2(512, 250, 62, 3), Color(0.3, 0.3, 0.33))

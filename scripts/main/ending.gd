extends Control
## 2일차 끝 (프로토타입 엔딩). 이후 날짜는 기획 확정 후 추가.

const D = preload("res://scripts/systems/game_data.gd")
const UIUtil = preload("res://scripts/systems/ui_util.gd")
const BreadCharacter = preload("res://scripts/characters/bread_character.gd")

var _t := 0.0


func _ready() -> void:
	var S: Dictionary = GameState.s
	Sound.bgm("ending")
	var hero := BreadCharacter.new()
	hero.kind = "banjuk"
	hero.damage = float(S.damage)
	hero.position = Vector2(320, 74)
	hero.scale = Vector2(2.2, 2.2)
	add_child(hero)

	var box := VBoxContainer.new()
	box.position = Vector2(80, 84)
	box.size = Vector2(480, 260)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var fg := Color(0.95, 0.92, 1.0)
	_line(box, "2일차 끝", 26, fg)
	var a := "손끝의 반죽은… 어제보다 조금 더 단단히 붙어 있었다." if float(S.damage) >= 50.0 else "아직은 말랑하다. 아직은."
	var b := "사장님의 웃는 눈이 자꾸 떠오른다. \"조금만 더 내어주게.\"" if S.flags.get("asked", false) else "오븐의 온기가 오늘따라 낯설게 느껴진다."
	_line(box, a + "\n" + b, 12, fg)
	if S.flags.get("secret2", false):
		var card := PanelContainer.new()
		var sb := UIUtil.panel_style(Color(0.18, 0.14, 0.25), Color(0.49, 0.36, 0.77), 2)
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(8)
		card.add_theme_stylebox_override("panel", sb)
		var l := UIUtil.label("검은 외투의 손님이 남긴 카드\n\"그 반죽에 너무 많은 걸 주지 마. 사흘째 되는 날, 문 닫은 뒤에.\" — ???", 11, Color(0.91, 0.86, 1.0))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(l)
		box.add_child(card)
	_line(box, "총 매출 %s · 소지금 %s · 반죽 손상 %d" % [D.fmt_money(float(S.total)), D.fmt_money(float(S.money)), int(S.damage)], 10, Color(fg, 0.75))
	_line(box, "To be continued…", 18, fg)
	_line(box, "3일차 이후는 기획서 확정 후 추가 예정", 9, Color(fg, 0.55))
	var btn := UIUtil.button("타이틀로", 13)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func() -> void:
		if not GameState.busy:
			GameState.quit_to_title())
	box.add_child(btn)
	btn.grab_focus()


func _line(box: VBoxContainer, text: String, size: int, color: Color) -> void:
	var l := UIUtil.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(480, 0)
	box.add_child(l)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.07, 0.05, 0.09))
	UIUtil.ellipse(self, Vector2(320, 120), Vector2(300, 200), Color(0.23, 0.17, 0.31, 0.8 + 0.1 * sin(_t)))

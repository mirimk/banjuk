extends Control
## 상단 HUD: 반죽이 얼굴, 체력/반죽 손상/기분, 날짜·시각·시간대, 위치, 돈.

const D = preload("res://scripts/systems/game_data.gd")
const UIUtil = preload("res://scripts/systems/ui_util.gd")
const BreadCharacter = preload("res://scripts/characters/bread_character.gd")

var _avatar: BreadCharacter


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(640, 32)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatar = BreadCharacter.new()
	_avatar.position = Vector2(17, 29)
	_avatar.scale = Vector2(0.95, 0.95)
	add_child(_avatar)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var S: Dictionary = GameState.s
	if S.is_empty():
		return
	_avatar.damage = float(S.damage)
	draw_rect(Rect2(0, 0, 640, 32), Color(0.16, 0.10, 0.06, 0.88))
	_bar("체력", float(S.stamina), Color(0.35, 0.65, 0.41), 38)
	_bar("반죽 손상", float(S.damage), Color(0.78, 0.45, 0.18), 106)
	_bar("기분", float(S.mood), Color(0.89, 0.70, 0.24), 174)

	var scr := GameState.screen
	var ph: Dictionary = D.PHASES[int(S.phase_idx)]
	var label: String = ph.name if scr == "game" else ("퇴근 · 정산" if scr == "settle" else "퇴근 후 · 집")
	var time: String = D.fmt_time(float(S.minute)) if scr == "game" else ("18:00" if scr == "settle" else "21:00")
	var loc := "주방" if S.location == "kitchen" else "빵집"
	if scr != "game":
		loc = "집"
	UIUtil.text(self, "%d일차" % int(S.day), Vector2(244, 19), 13, Color(1.0, 0.97, 0.92))
	UIUtil.text(self, "/ %d" % D.LAST_DAY, Vector2(246, 29), 7, Color(1.0, 0.97, 0.92, 0.6))
	UIUtil.text(self, time, Vector2(290, 22), 17, Color(1.0, 0.84, 0.54))
	var lw := UIUtil.FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 12.0
	UIUtil.rounded(self, Rect2(344, 9, lw, 15), Color(1, 1, 1, 0.13), Color(0, 0, 0, 0), 5)
	UIUtil.text(self, label, Vector2(350, 20), 9, Color(1.0, 0.97, 0.92))
	UIUtil.text(self, "위치: " + loc, Vector2(440, 15), 9, Color(1.0, 0.97, 0.92, 0.8))
	if S.flags.get("levain", false):
		UIUtil.text(self, "르방 보유", Vector2(440, 27), 8, Color(0.85, 0.78, 1.0))
	UIUtil.text(self, D.fmt_money(float(S.money)), Vector2(490, 21), 13, Color(1.0, 0.97, 0.92) if int(S.money) >= 0 else Color(1.0, 0.45, 0.4), HORIZONTAL_ALIGNMENT_RIGHT, 110)


func _bar(name: String, v: float, col: Color, x: float) -> void:
	UIUtil.text(self, name, Vector2(x, 12), 8, Color(1.0, 0.97, 0.92, 0.85))
	UIUtil.text(self, str(int(round(v))), Vector2(x, 12), 8, Color(1.0, 0.97, 0.92, 0.85), HORIZONTAL_ALIGNMENT_RIGHT, 60)
	draw_rect(Rect2(x, 16, 60, 5), Color(1, 1, 1, 0.18))
	draw_rect(Rect2(x, 16, 60 * clampf(v / 100.0, 0.0, 1.0), 5), col)

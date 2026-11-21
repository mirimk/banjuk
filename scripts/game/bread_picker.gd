extends Control
## 반죽 전에 만들 빵을 고르는 창. 단계(1~3)별로 한 줄씩, 해금되지 않은 단계는 잠겨 있다.

signal picked(type: String)
signal blocked(msg: String)
signal cancelled

const D = preload("res://scripts/systems/game_data.gd")
const P = preload("res://scripts/game/process.gd")
const UIUtil = preload("res://scripts/systems/ui_util.gd")
const Art = preload("res://scripts/systems/art.gd")

const PANEL := Rect2(70, 38, 500, 284)
const INK := Color(0.35, 0.23, 0.12)

var day := 1
var has_levain := false


static func row_types(tier: int) -> Array:
	return D.BREAD_ORDER.filter(func(t: String) -> bool: return D.tier_of(t) == tier)


static func card(tier: int, i: int) -> Rect2:
	return Rect2(PANEL.position.x + 92 + i * 98, PANEL.position.y + 30 + (tier - 1) * 76, 92, 70)


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var cancel := UIUtil.button("취소", 12)
	cancel.position = Vector2(PANEL.position.x + 220, PANEL.end.y - 28)
	cancel.size = Vector2(60, 24)
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(func() -> void:
		hide()
		cancelled.emit())
	add_child(cancel)


func open(today: int, levain: bool) -> void:
	day = today
	has_levain = levain
	show()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


## 이 빵을 지금 만들 수 없으면 이유를, 만들 수 있으면 "" 를 돌려준다.
func lock_reason(type: String) -> String:
	var tier := D.tier_of(type)
	if not D.tier_unlocked(tier, day):
		return "%d일차부터 만들 수 있어요" % int(D.TIERS[tier].unlock)
	if D.TIERS[tier].get("levain", false) and not has_levain:
		return "발효종(르방)이 있어야 만들 수 있어요"
	return ""


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.08, 0.05, 0.02, 0.55))
	UIUtil.rounded(self, PANEL, Color(1.0, 0.97, 0.92), Color(0.54, 0.35, 0.17), 10, 2)
	UIUtil.text(self, "어떤 빵을 만들까요?  (반죽 1판 = %d개)" % D.BATCH, PANEL.position + Vector2(0, 22), 14, INK, HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x)
	UIUtil.text(self, "등급별 값  " + D.grade_price_text(), Vector2(PANEL.position.x + 12, PANEL.end.y - 12), 8, Color(0.54, 0.35, 0.17))
	var mouse := get_local_mouse_position()
	for tier in [1, 2, 3]:
		var t: Dictionary = D.TIERS[tier]
		var y := card(tier, 0).position.y
		var unlocked := D.tier_unlocked(tier, day)
		UIUtil.text(self, t.name, Vector2(PANEL.position.x + 10, y + 18), 12, INK if unlocked else Color(INK, 0.4))
		var sub := "체력 -%d" % (int(t.st_knead) + int(t.st_shape))
		UIUtil.text(self, sub, Vector2(PANEL.position.x + 10, y + 32), 8, Color(0.54, 0.35, 0.17, 1.0 if unlocked else 0.4))
		var flow := P.flow_text(tier).replace(" → ", "→")
		UIUtil.text_wrap(self, flow, Vector2(PANEL.position.x + 10, y + 44), 80, 7, Color(0.45, 0.35, 0.28, 1.0 if unlocked else 0.4), 3)
		var types := row_types(tier)
		for i in types.size():
			var key: String = types[i]
			var r := card(tier, i)
			var reason := lock_reason(key)
			var hover := r.has_point(mouse) and reason == ""
			UIUtil.rounded(self, r, Color.WHITE if reason == "" else Color(0.92, 0.89, 0.85), Color(0.88, 0.48, 0.22) if hover else Color(0.91, 0.81, 0.66), 8, 2)
			Art.bread(self, key, r.position + Vector2(r.size.x / 2, 24), 2.0, Color(0, 0, 0, 0), 1.0 if reason == "" else 0.35)
			UIUtil.text(self, D.BREADS[key].name, r.position + Vector2(0, 50), 11, INK if reason == "" else Color(INK, 0.45), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			if reason == "":
				UIUtil.text(self, "S %s · %s" % [D.fmt_money(D.sale_price(key, "S")), "타이밍" if D.BREADS[key].knead == "timing" else "문지르기"], r.position + Vector2(0, 63), 8, Color(0.54, 0.35, 0.17), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			else:
				var short := "%d일차 해금" % int(t.unlock) if not unlocked else "발효종 필요"
				UIUtil.text(self, "잠김 · " + short, r.position + Vector2(0, 63), 8, Color(0.6, 0.25, 0.2), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	for tier in [1, 2, 3]:
		var types := row_types(tier)
		for i in types.size():
			if card(tier, i).has_point(event.position):
				var reason := lock_reason(types[i])
				if reason != "":
					blocked.emit(reason)
					return
				hide()
				picked.emit(types[i])
				return
	if not PANEL.has_point(event.position):
		hide()
		cancelled.emit()

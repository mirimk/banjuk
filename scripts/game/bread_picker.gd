extends Control
## 반죽 전에 만들 빵을 고르는 창.

signal picked(type: String)
signal cancelled

const D = preload("res://scripts/systems/game_data.gd")
const UIUtil = preload("res://scripts/systems/ui_util.gd")
const Art = preload("res://scripts/systems/art.gd")

const PANEL := Rect2(130, 82, 380, 176)


static func card(i: int) -> Rect2:
	return Rect2(PANEL.position.x + 16 + i * 88, PANEL.position.y + 40, 80, 92)


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var cancel := UIUtil.button("취소", 12)
	cancel.position = Vector2(PANEL.position.x + 160, PANEL.end.y - 34)
	cancel.size = Vector2(60, 24)
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(func() -> void:
		hide()
		cancelled.emit())
	add_child(cancel)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.08, 0.05, 0.02, 0.55))
	UIUtil.rounded(self, PANEL, Color(1.0, 0.97, 0.92), Color(0.54, 0.35, 0.17), 10, 2)
	UIUtil.text(self, "어떤 빵을 만들까요?", PANEL.position + Vector2(0, 26), 15, Color(0.35, 0.23, 0.12), HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x)
	var mouse := get_local_mouse_position()
	for i in D.BREAD_ORDER.size():
		var key: String = D.BREAD_ORDER[i]
		var r := card(i)
		var hover := r.has_point(mouse)
		UIUtil.rounded(self, r, Color.WHITE, Color(0.88, 0.48, 0.22) if hover else Color(0.91, 0.81, 0.66), 8, 2)
		Art.bread(self, key, r.position + Vector2(r.size.x / 2, 34), 2.4)
		UIUtil.text(self, D.BREADS[key].name, r.position + Vector2(0, 66), 12, Color(0.35, 0.23, 0.12), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		UIUtil.text(self, "%s · %d개" % [D.fmt_money(D.BREADS[key].price), D.BATCH], r.position + Vector2(0, 82), 8, Color(0.54, 0.35, 0.17), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	for i in D.BREAD_ORDER.size():
		if card(i).has_point(event.position):
			hide()
			picked.emit(D.BREAD_ORDER[i])
			return
	if not PANEL.has_point(event.position):
		hide()
		cancelled.emit()

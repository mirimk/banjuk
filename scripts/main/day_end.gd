extends Control
## 하루 마감 화면: 오늘의 결과와 능력치 변화를 보여준다.

const UIUtil = preload("res://scripts/systems/ui_util.gd")

const STATS := [
	["돈", "money", "원"],
	["체력", "stamina", ""],
	["기억", "memory", ""],
	["신체", "body", ""],
	["반죽 오염도", "contamination", ""],
]


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.07, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := UIUtil.label("%d일 차 마감" % GameState.day, 24, Color(0.98, 0.88, 0.66))
	title.position = Vector2(0, 24)
	title.size = Vector2(640, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var t: Dictionary = GameState.today
	var summary := UIUtil.label("오늘 만든 빵: 품질 %d (%s)" % [int(t["bread_quality"]), str(t["bread_grade"])], 13, Color(0.95, 0.90, 0.80))
	summary.position = Vector2(0, 70)
	summary.size = Vector2(640, 20)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(summary)

	var start: Dictionary = t["start"]
	var y := 104.0
	for s in STATS:
		var before: int = start[s[1]]
		var now: int = GameState.get(s[1])
		var diff := now - before
		var diff_text := ""
		if diff != 0:
			diff_text = "  (%s%d)" % ["+" if diff > 0 else "", diff]
		var row := UIUtil.label("%s    %d%s  →  %d%s%s" % [s[0], before, s[2], now, s[2], diff_text], 13, _row_color(s[1], diff))
		row.position = Vector2(0, y)
		row.size = Vector2(640, 20)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(row)
		y += 24.0

	var note := UIUtil.label("손끝에 묻은 반죽은, 씻어도 잘 지워지지 않았다.", 11, Color(0.65, 0.58, 0.52))
	note.position = Vector2(0, 236)
	note.size = Vector2(640, 18)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(note)

	var box := HBoxContainer.new()
	box.position = Vector2(170, 280)
	box.size = Vector2(300, 32)
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)

	var next_btn := UIUtil.button("%d일 차로 (개발 예정)" % (GameState.day + 1), 12)
	next_btn.disabled = true
	box.add_child(next_btn)

	var title_btn := UIUtil.button("타이틀로", 12)
	title_btn.pressed.connect(func() -> void: GameState.change_scene("res://scenes/main/title.tscn"))
	box.add_child(title_btn)
	title_btn.grab_focus()


func _row_color(stat: String, diff: int) -> Color:
	if diff == 0:
		return Color(0.80, 0.76, 0.70)
	# 돈은 늘면 좋은 것, 오염도는 늘면 나쁜 것, 나머지는 줄면 나쁜 것
	var good := diff > 0
	if stat == "contamination":
		good = diff < 0
	return Color(0.65, 0.90, 0.60) if good else Color(0.95, 0.50, 0.45)

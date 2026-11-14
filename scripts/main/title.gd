extends Control
## 타이틀 화면

const UIUtil = preload("res://scripts/systems/ui_util.gd")
const BreadCharacter = preload("res://scripts/characters/bread_character.gd")

var _started := false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.10, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := UIUtil.label("반죽", 56, Color(0.98, 0.88, 0.66))
	title.position = Vector2(0, 36)
	title.size = Vector2(640, 76)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var sub := UIUtil.label("BANJUK  ·  빵을 만들수록, 나는 조금씩 사라진다", 11, Color(0.75, 0.62, 0.48))
	sub.position = Vector2(0, 114)
	sub.size = Vector2(640, 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	var hero: BreadCharacter = BreadCharacter.new()
	hero.kind = "banjuk"
	hero.position = Vector2(320, 214)
	hero.scale = Vector2(2.5, 2.5)
	add_child(hero)

	var box := VBoxContainer.new()
	box.position = Vector2(255, 236)
	box.size = Vector2(130, 70)
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var start_btn := UIUtil.button("새 게임")
	start_btn.pressed.connect(_on_start)
	box.add_child(start_btn)

	var quit_btn := UIUtil.button("종료")
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit_btn)

	var hint := UIUtil.label("↑↓ 선택   Enter 결정        프로토타입 v0.1 (임시 그래픽)", 9, Color(0.55, 0.45, 0.38))
	hint.position = Vector2(0, 336)
	hint.size = Vector2(640, 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	start_btn.grab_focus()


func _on_start() -> void:
	if _started:
		return
	_started = true
	GameState.new_game()
	GameState.change_scene("res://scenes/bakery/bakery.tscn")

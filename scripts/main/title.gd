extends Control
## 타이틀 화면: 새 게임 / 이어하기 / 종료

const UIUtil = preload("res://scripts/systems/ui_util.gd")
const Art = preload("res://scripts/systems/art.gd")
const BreadCharacter = preload("res://scripts/characters/bread_character.gd")

var _t := 0.0
var _btn_continue: Button


func _ready() -> void:
	GameState.screen = "title"
	Sound.bgm("title")

	var title := UIUtil.label("반죽", 56, Color(0.98, 0.88, 0.66))
	title.position = Vector2(0, 30)
	title.size = Vector2(640, 76)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var sub := UIUtil.label("BANJUK  ·  빵을 만들수록, 나는 조금씩 사라진다", 11, Color(0.75, 0.62, 0.48))
	sub.position = Vector2(0, 106)
	sub.size = Vector2(640, 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	var hero := BreadCharacter.new()
	hero.kind = "banjuk"
	hero.position = Vector2(320, 190)
	hero.scale = Vector2(2.5, 2.5)
	add_child(hero)

	var box := VBoxContainer.new()
	box.position = Vector2(250, 206)
	box.size = Vector2(140, 100)
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var start_btn := UIUtil.button("새 게임")
	start_btn.pressed.connect(_on_new)
	box.add_child(start_btn)

	_btn_continue = UIUtil.button("이어하기")
	_btn_continue.disabled = not GameState.has_save()
	_btn_continue.pressed.connect(_on_continue)
	box.add_child(_btn_continue)

	var quit_btn := UIUtil.button("종료")
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit_btn)

	var hint := UIUtil.label("마우스 클릭 · Space/Enter 결정 · Esc 설정        프로토타입 v0.2 (임시 그래픽)", 9, Color(0.55, 0.45, 0.38))
	hint.position = Vector2(0, 336)
	hint.size = Vector2(640, 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	if GameState.has_save():
		_btn_continue.grab_focus()
	else:
		start_btn.grab_focus()


func _on_new() -> void:
	if GameState.busy:
		return
	if GameState.has_save():
		GameState.ask("저장된 게임이 있어요.\n새로 시작해도 저장하기 전까지는 기존 데이터가 남아 있어요.", _start)
	else:
		_start()


func _start() -> void:
	Sound.sfx("good")
	GameState.start_new_game()


func _on_continue() -> void:
	if GameState.busy:
		return
	Sound.sfx("good")
	GameState.load_game()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.16, 0.10, 0.08))
	UIUtil.ellipse(self, Vector2(320, 150), Vector2(260, 150), Color(0.24, 0.15, 0.10))
	var types := ["toast", "croissant", "baguette", "bagel", "toast", "croissant"]
	for i in types.size():
		var y := fmod(380.0 - _t * (14.0 + i * 3.0) + i * 70.0, 420.0) - 30.0
		Art.bread(self, types[i], Vector2(50 + i * 108, y), 2.0, Color(0, 0, 0, 0), 0.18)

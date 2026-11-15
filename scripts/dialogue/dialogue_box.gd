extends CanvasLayer
## 대화창. 사용법: var choice: int = await dialogue.say(line, damage)
## line = {"speaker": "boss|crew|me|narr", "text": "...", "choices": [{"t": "..."}]}
## 선택지가 없으면 -1, 있으면 고른 번호를 돌려준다.

signal _done(result: int)

const UIUtil = preload("res://scripts/systems/ui_util.gd")
const BreadCharacter = preload("res://scripts/characters/bread_character.gd")
const CHARS_PER_SEC := 40.0
const SPEAKERS := {
	"boss": ["사장", Color(1.0, 0.82, 0.55), "boss"],
	"crew": ["크루", Color(0.95, 0.68, 0.32), "crew"],
	"me": ["반죽이", Color(1.0, 0.92, 0.72), "banjuk"],
	"narr": ["", Color.WHITE, ""],
}

var active := false

var _catcher: Control
var _panel: Panel
var _name_label: Label
var _text_label: Label
var _hint: Label
var _portrait_box: Panel
var _portrait: BreadCharacter
var _choices: HBoxContainer
var _has_choices := false
var _shown := 0.0
var _t := 0.0


func _ready() -> void:
	layer = 10
	_catcher = Control.new()
	_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(_on_catcher_input)
	add_child(_catcher)

	_panel = Panel.new()
	_panel.position = Vector2(14, 256)
	_panel.size = Vector2(612, 96)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_portrait_box = Panel.new()
	_portrait_box.position = Vector2(10, 10)
	_portrait_box.size = Vector2(76, 76)
	_portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_box.add_theme_stylebox_override("panel", UIUtil.panel_style(Color(0.95, 0.86, 0.74), Color(0.55, 0.40, 0.28), 1))
	_panel.add_child(_portrait_box)
	_portrait = BreadCharacter.new()
	_portrait_box.add_child(_portrait)

	_name_label = UIUtil.label("", 13)
	_name_label.position = Vector2(98, 6)
	_panel.add_child(_name_label)

	_text_label = UIUtil.label("", 13, Color(0.98, 0.95, 0.88))
	_text_label.position = Vector2(98, 26)
	_text_label.size = Vector2(500, 40)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_panel.add_child(_text_label)

	_choices = HBoxContainer.new()
	_choices.position = Vector2(98, 64)
	_choices.add_theme_constant_override("separation", 8)
	_panel.add_child(_choices)

	_hint = UIUtil.label("▼ 클릭 / Space", 9, Color(0.95, 0.84, 0.62))
	_hint.position = Vector2(530, 78)
	_panel.add_child(_hint)

	_set_visible(false)


func _set_visible(v: bool) -> void:
	_catcher.visible = v
	_panel.visible = v


func say(line: Dictionary, damage: float = 0.0) -> int:
	active = true
	_set_visible(true)
	var sp: String = line.get("speaker", "narr")
	var info: Array = SPEAKERS.get(sp, SPEAKERS["narr"])
	var narr := sp == "narr"
	_panel.add_theme_stylebox_override("panel", UIUtil.panel_style(
		Color(0.12, 0.08, 0.06, 0.95) if narr else Color(0.20, 0.13, 0.09, 0.96), Color(0.95, 0.84, 0.62)))
	_portrait_box.visible = not narr
	var left := 14.0 if narr else 98.0
	_name_label.position.x = left
	_text_label.position.x = left
	_text_label.size.x = 598.0 - left
	_choices.position.x = left
	if not narr:
		_portrait.kind = info[2]
		_portrait.damage = damage if sp == "me" else 0.0
		_portrait.position = Vector2(38, 66 if sp != "boss" else 72)
		_portrait.scale = Vector2(1.6, 1.6) if sp != "boss" else Vector2(0.95, 0.95)
	_name_label.text = info[0]
	_name_label.add_theme_color_override("font_color", info[1])
	_text_label.text = line.get("text", "")
	_text_label.add_theme_color_override("font_color", Color(0.82, 0.80, 0.76) if narr else Color(0.98, 0.95, 0.88))
	_shown = 0.0
	_text_label.visible_characters = 0

	for c in _choices.get_children():
		c.queue_free()
	var choices: Array = line.get("choices", [])
	_has_choices = not choices.is_empty()
	_choices.visible = false
	for i in choices.size():
		var b := UIUtil.button(str(choices[i].get("t", "")), 12)
		b.pressed.connect(func() -> void: _finish(i))
		_choices.add_child(b)

	var r: int = await _done
	return r


func _finish(result: int) -> void:
	active = false
	_set_visible(false)
	_done.emit(result)


func _is_typing() -> bool:
	return _text_label.visible_characters >= 0 and _text_label.visible_characters < _text_label.get_total_character_count()


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	if _is_typing():
		_shown += delta * CHARS_PER_SEC
		_text_label.visible_characters = int(_shown)
		_hint.visible = false
	else:
		_choices.visible = _has_choices
		_hint.visible = not _has_choices and fmod(_t, 0.8) < 0.5


## 클릭/Space: 타자 중이면 전체 표시, 아니면 다음 대사 (선택지가 있으면 버튼으로만 진행)
func advance() -> void:
	if not active:
		return
	if _is_typing():
		_text_label.visible_characters = -1
		return
	if _has_choices:
		return
	Sound.sfx("click")
	_finish(-1)


## 테스트용: 선택지가 있으면 i 번을 고른다
func debug_skip(i: int = 0) -> void:
	if not active:
		return
	_text_label.visible_characters = -1
	if _has_choices:
		_finish(i)
	else:
		_finish(-1)


func _on_catcher_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()


func _unhandled_input(event: InputEvent) -> void:
	if active and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		advance()

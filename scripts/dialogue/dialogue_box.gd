extends CanvasLayer
## 대화창. 사용법: await dialogue.play([{"speaker": "사장", "text": "..."}, ...])
## speaker 가 "" 이면 내레이션으로 표시.

signal finished

const UIUtil = preload("res://scripts/systems/ui_util.gd")
const CHARS_PER_SEC := 40.0
const SPEAKER_COLORS := {
	"사장": Color(1.0, 0.82, 0.55),
	"크루": Color(0.95, 0.68, 0.32),
	"반죽이": Color(1.0, 0.92, 0.72),
	"꼬마 손님": Color(1.0, 0.62, 0.72),
}

var active := false

var _lines: Array = []
var _index := 0
var _shown := 0.0
var _t := 0.0
var _panel: Panel
var _name_label: Label
var _text_label: Label
var _hint: Label


func _ready() -> void:
	layer = 10
	_panel = Panel.new()
	_panel.position = Vector2(16, 262)
	_panel.size = Vector2(608, 88)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 클릭이 _unhandled_input 으로 오도록
	_panel.add_theme_stylebox_override("panel", UIUtil.panel_style(Color(0.12, 0.08, 0.06, 0.94), Color(0.95, 0.84, 0.62)))
	add_child(_panel)

	_name_label = UIUtil.label("", 13)
	_name_label.position = Vector2(12, 6)
	_panel.add_child(_name_label)

	_text_label = UIUtil.label("", 13, Color(0.98, 0.95, 0.88))
	_text_label.position = Vector2(12, 26)
	_text_label.size = Vector2(584, 54)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_panel.add_child(_text_label)

	_hint = UIUtil.label("▼", 10, Color(0.95, 0.84, 0.62))
	_hint.position = Vector2(588, 70)
	_panel.add_child(_hint)

	_panel.hide()


func play(lines: Array) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_index = 0
	active = true
	_panel.show()
	_show_line()
	await finished


func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	var speaker: String = line.get("speaker", "")
	_name_label.text = speaker
	_name_label.add_theme_color_override("font_color", SPEAKER_COLORS.get(speaker, Color.WHITE))
	_text_label.text = line.get("text", "")
	# 내레이션은 살짝 흐리게
	_text_label.add_theme_color_override("font_color", Color(0.80, 0.78, 0.74) if speaker == "" else Color(0.98, 0.95, 0.88))
	_shown = 0.0
	_text_label.visible_characters = 0


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
		_hint.visible = fmod(_t, 0.8) < 0.5


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	var pressed := event.is_action_pressed("interact")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _is_typing():
		_text_label.visible_characters = -1
		return
	_index += 1
	if _index >= _lines.size():
		active = false
		_panel.hide()
		finished.emit()
	else:
		_show_line()

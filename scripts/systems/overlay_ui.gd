extends CanvasLayer
## 모든 화면 위에 떠 있는 공용 UI: 설정(⚙) 버튼/창, 확인 창, 알림(토스트), 화면 전환 페이드.
## GameState 가 생성해서 들고 있다.

const UIUtil = preload("res://scripts/systems/ui_util.gd")

var fade: ColorRect
var fade_title: Label
var fade_sub: Label
var toast_box: VBoxContainer
var gear: Button
var settings: Control
var confirm_box: Control

var _btn_save: Button
var _btn_save_quit: Button
var _slider: HSlider
var _vol_label: Label
var _btn_mute: Button
var _confirm_label: Label
var _confirm_cb := Callable()


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_fade()
	_build_toast()
	_build_gear()
	_build_settings()
	_build_confirm()


func modal_open() -> bool:
	return settings.visible or confirm_box.visible


# ---------------------------------------------------------------- 페이드

func _build_fade() -> void:
	fade = ColorRect.new()
	fade.color = Color(0.11, 0.08, 0.06, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	fade_title = UIUtil.label("", 30, Color(1.0, 0.95, 0.87))
	fade_title.position = Vector2(0, 140)
	fade_title.size = Vector2(640, 40)
	fade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade.add_child(fade_title)
	fade_sub = UIUtil.label("", 12, Color(1.0, 0.95, 0.87, 0.8))
	fade_sub.position = Vector2(0, 186)
	fade_sub.size = Vector2(640, 20)
	fade_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade.add_child(fade_sub)


func fade_in(title: String, sub: String, dur: float = 0.35) -> void:
	fade_title.text = title
	fade_sub.text = sub
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, dur)
	await tw.finished


func fade_out(dur: float = 0.35) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, dur)
	await tw.finished
	fade_title.text = ""
	fade_sub.text = ""
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ---------------------------------------------------------------- 토스트

func _build_toast() -> void:
	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(120, 262)
	toast_box.size = Vector2(400, 60)
	toast_box.alignment = BoxContainer.ALIGNMENT_END
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_theme_constant_override("separation", 3)
	add_child(toast_box)


func toast(msg: String) -> void:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UIUtil.panel_style(Color(0.16, 0.10, 0.06, 0.92), Color(0, 0, 0, 0), 0)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := UIUtil.label(msg, 10, Color(1.0, 0.97, 0.92))
	pc.add_child(l)
	toast_box.add_child(pc)
	while toast_box.get_child_count() > 3:
		toast_box.get_child(0).free()
	var tw := pc.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(pc, "modulate:a", 0.0, 0.3)
	tw.tween_callback(pc.queue_free)


# ---------------------------------------------------------------- 설정

func _build_gear() -> void:
	gear = Button.new()
	gear.text = "⚙"
	gear.tooltip_text = "설정 (Esc)"
	gear.position = Vector2(608, 3)
	gear.size = Vector2(28, 26)
	gear.add_theme_font_size_override("font_size", 16)
	gear.add_theme_stylebox_override("normal", _round_style(Color(1.0, 0.95, 0.87), Color(0.79, 0.65, 0.49)))
	gear.add_theme_stylebox_override("hover", _round_style(Color(1.0, 1.0, 0.95), Color(0.88, 0.48, 0.22)))
	gear.add_theme_stylebox_override("pressed", _round_style(Color(0.9, 0.85, 0.75), Color(0.88, 0.48, 0.22)))
	gear.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	gear.add_theme_color_override("font_color", Color(0.35, 0.23, 0.12))
	gear.add_theme_color_override("font_hover_color", Color(0.35, 0.23, 0.12))
	gear.focus_mode = Control.FOCUS_NONE
	gear.pressed.connect(toggle_settings)
	add_child(gear)


func _round_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := UIUtil.panel_style(bg, border, 1)
	sb.set_corner_radius_all(13)
	sb.set_content_margin_all(0)
	return sb


func _modal_base() -> Array:
	var root := ColorRect.new()
	root.color = Color(0.04, 0.02, 0.01, 0.6)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.hide()
	add_child(root)
	var panel := PanelContainer.new()
	var sb := UIUtil.panel_style(Color(1.0, 0.97, 0.92), Color(0.54, 0.35, 0.17), 2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	return [root, panel, box]


func _build_settings() -> void:
	var parts := _modal_base()
	settings = parts[0]
	var panel: PanelContainer = parts[1]
	var box: VBoxContainer = parts[2]
	panel.position = Vector2(205, 62)
	panel.custom_minimum_size = Vector2(230, 0)

	var title := UIUtil.label("설정", 18, Color(0.35, 0.23, 0.12))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_btn_save = UIUtil.button("저장", 13)
	_btn_save.pressed.connect(func() -> void:
		GameState.save_game()
		Sound.sfx("good"))
	box.add_child(_btn_save)

	_btn_save_quit = UIUtil.button("저장 후 종료 (타이틀로)", 13)
	_btn_save_quit.pressed.connect(_on_save_quit)
	box.add_child(_btn_save_quit)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(UIUtil.label("음량", 12, Color(0.35, 0.23, 0.12)))
	_slider = HSlider.new()
	_slider.min_value = 0
	_slider.max_value = 100
	_slider.step = 1
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.value_changed.connect(func(v: float) -> void:
		Sound.set_volume(v / 100.0)
		_vol_label.text = str(int(v)))
	_slider.drag_ended.connect(func(_c: bool) -> void: Sound.sfx("click"))
	row.add_child(_slider)
	_vol_label = UIUtil.label("60", 12, Color(0.35, 0.23, 0.12))
	_vol_label.custom_minimum_size = Vector2(24, 0)
	_vol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_vol_label)
	box.add_child(row)

	_btn_mute = UIUtil.button("음소거", 13)
	_btn_mute.pressed.connect(func() -> void:
		Sound.set_muted(not Sound.muted)
		_sync_settings())
	box.add_child(_btn_mute)

	var close := UIUtil.button("닫기", 13)
	close.pressed.connect(close_settings)
	box.add_child(close)


func _sync_settings() -> void:
	_slider.set_value_no_signal(Sound.volume * 100.0)
	_vol_label.text = str(int(Sound.volume * 100.0))
	_btn_mute.text = "음소거 해제" if Sound.muted else "음소거"
	var ok := GameState.can_save()
	_btn_save.disabled = not ok
	_btn_save_quit.disabled = not ok


func toggle_settings() -> void:
	if settings.visible:
		close_settings()
	else:
		open_settings()


func open_settings() -> void:
	if confirm_box.visible or GameState.busy:
		return
	_sync_settings()
	settings.show()
	get_tree().paused = true
	Sound.sfx("click")


func close_settings() -> void:
	settings.hide()
	get_tree().paused = false


func _on_save_quit() -> void:
	if not GameState.save_game():
		return
	close_settings()
	GameState.quit_to_title()


# ---------------------------------------------------------------- 확인 창

func _build_confirm() -> void:
	var parts := _modal_base()
	confirm_box = parts[0]
	var panel: PanelContainer = parts[1]
	var box: VBoxContainer = parts[2]
	panel.position = Vector2(180, 110)
	panel.custom_minimum_size = Vector2(280, 0)
	_confirm_label = UIUtil.label("", 12, Color(0.23, 0.16, 0.10))
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.custom_minimum_size = Vector2(250, 0)
	box.add_child(_confirm_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var no := UIUtil.button("취소", 13)
	no.custom_minimum_size = Vector2(90, 0)
	no.pressed.connect(func() -> void:
		confirm_box.hide()
		get_tree().paused = false
		_confirm_cb = Callable())
	row.add_child(no)
	var yes := UIUtil.button("확인", 13)
	yes.custom_minimum_size = Vector2(90, 0)
	yes.pressed.connect(_on_confirm_yes)
	row.add_child(yes)
	box.add_child(row)


func ask(msg: String, on_yes: Callable) -> void:
	_confirm_label.text = msg
	_confirm_cb = on_yes
	confirm_box.show()
	get_tree().paused = true


func _on_confirm_yes() -> void:
	confirm_box.hide()
	get_tree().paused = false
	var cb := _confirm_cb
	_confirm_cb = Callable()
	if cb.is_valid():
		cb.call()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if confirm_box.visible:
			return
		toggle_settings()

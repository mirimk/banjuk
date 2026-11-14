extends RefCounted
## 임시 UI/도형 그리기 도우미. 최종 에셋이 들어오면 대부분 교체될 예정.


static func label(text: String, size: int = 12, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func panel_style(bg: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_content_margin_all(6)
	return sb


static func button(text: String, size: int = 14) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", panel_style(Color(0.30, 0.20, 0.14), Color(0.55, 0.40, 0.28)))
	b.add_theme_stylebox_override("hover", panel_style(Color(0.42, 0.28, 0.18), Color(0.98, 0.85, 0.60)))
	b.add_theme_stylebox_override("focus", panel_style(Color(0.42, 0.28, 0.18), Color(0.98, 0.85, 0.60)))
	b.add_theme_stylebox_override("pressed", panel_style(Color(0.22, 0.14, 0.10), Color(0.98, 0.85, 0.60)))
	b.add_theme_stylebox_override("disabled", panel_style(Color(0.20, 0.17, 0.15), Color(0.30, 0.26, 0.22)))
	b.add_theme_color_override("font_color", Color(0.98, 0.90, 0.75))
	b.add_theme_color_override("font_disabled_color", Color(0.50, 0.45, 0.40))
	return b


## 타원을 다각형으로 그린다.
static func ellipse(ci: CanvasItem, center: Vector2, radius: Vector2, color: Color, segments: int = 24) -> void:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	ci.draw_colored_polygon(pts, color)

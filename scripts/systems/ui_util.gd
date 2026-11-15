extends RefCounted

const FONT: Font = preload("res://assets/ui/default_font.tres")
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


## 글자를 그린다. width > 0 이면 그 폭 안에서 정렬한다. pos 는 글자 기준선(baseline) 왼쪽.
static func text(ci: CanvasItem, s: String, pos: Vector2, size: int = 10, color: Color = Color.WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	ci.draw_string(FONT, pos, s, align, width, size, color)


## 여러 줄 글자 (자동 줄바꿈)
static func text_wrap(ci: CanvasItem, s: String, pos: Vector2, width: float, size: int = 10, color: Color = Color.WHITE, max_lines: int = -1) -> void:
	ci.draw_multiline_string(FONT, pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, size, max_lines, color)


## 둥근 사각형
static func rounded(ci: CanvasItem, rect: Rect2, bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 6, border_width: int = 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border_width > 0:
		sb.border_color = border
		sb.set_border_width_all(border_width)
	sb.draw(ci.get_canvas_item(), rect)


## 게이지: v / max, 최적 구간 band(x~y) 표시
static func gauge(ci: CanvasItem, rect: Rect2, v: float, max_v: float, band: Vector2) -> void:
	ci.draw_rect(rect, Color(0, 0, 0, 0.3))
	ci.draw_rect(Rect2(rect.position.x + rect.size.x * band.x / max_v, rect.position.y, rect.size.x * (band.y - band.x) / max_v, rect.size.y), Color(0.47, 0.86, 0.47, 0.75))
	var w := rect.size.x * clampf(v / max_v, 0.0, 1.0)
	ci.draw_rect(Rect2(rect.position, Vector2(w, rect.size.y)), Color(1, 1, 1, 0.75))
	ci.draw_rect(Rect2(rect.position.x + w - 1.5, rect.position.y - 1, 2, rect.size.y + 2), Color(0.9, 0.2, 0.2))


## 이름표 (어두운 배경 + 흰 글자), center 는 이름표 중앙
static func tag(ci: CanvasItem, s: String, center: Vector2, size: int = 9) -> void:
	var w := FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 12.0
	rounded(ci, Rect2(center.x - w / 2.0, center.y - size * 0.8, w, size * 1.6), Color(0.35, 0.23, 0.12), Color(0, 0, 0, 0), 5)
	text(ci, s, Vector2(center.x - w / 2.0, center.y + size * 0.38), size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, w)

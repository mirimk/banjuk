extends Control
## 주방 화면: 반죽대 → 발효실 → 오븐 → 식힘대, 사장과 크루.
## 그리기와 클릭 판정만 담당하고, 실제 처리는 game.gd 가 hit 신호를 받아서 한다.

signal hit(what: String, idx: int)

const D = preload("res://scripts/systems/game_data.gd")
const UIUtil = preload("res://scripts/systems/ui_util.gd")
const Art = preload("res://scripts/systems/art.gd")
const BreadCharacter = preload("res://scripts/characters/bread_character.gd")

const KNEAD := Rect2(18, 180, 140, 104)
const PROOF := Rect2(172, 92, 118, 192)
const OVEN := Rect2(304, 92, 152, 192)
const RACK := Rect2(472, 128, 152, 156)
const BOSS_FEET := Vector2(96, 178)
const CREW_FEET := Vector2(590, 124)

var S: Dictionary
var say_who := ""
var say_text := ""
var say_t := 0.0
var _t := 0.0
var _boss: BreadCharacter
var _crew: BreadCharacter


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_boss = BreadCharacter.new()
	_boss.kind = "boss"
	_boss.position = BOSS_FEET
	add_child(_boss)
	_crew = BreadCharacter.new()
	_crew.kind = "crew"
	_crew.position = CREW_FEET
	_crew.scale = Vector2(1.3, 1.3)
	add_child(_crew)


static func proof_slot(i: int) -> Rect2:
	return Rect2(PROOF.position.x + 7, PROOF.position.y + 16 + i * 86, PROOF.size.x - 14, 78)


static func oven_slot(i: int) -> Rect2:
	return Rect2(OVEN.position.x + 8, OVEN.position.y + 16 + i * 86, OVEN.size.x - 16, 78)


static func rack_slot(i: int) -> Rect2:
	return Rect2(RACK.position.x + 6 + (i % 2) * 71, RACK.position.y + 8 + int(i / 2) * 71, 67, 66)


func say(who: String, text: String) -> void:
	say_who = who
	say_text = text
	say_t = 2.6


func _process(delta: float) -> void:
	_t += delta
	if say_t > 0.0:
		say_t -= delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = event.position
	if KNEAD.has_point(p):
		hit.emit("knead", 0)
		return
	for i in 2:
		if proof_slot(i).has_point(p):
			hit.emit("proof", i)
			return
		if oven_slot(i).has_point(p):
			hit.emit("oven", i)
			return
	for i in 4:
		if rack_slot(i).has_point(p):
			hit.emit("rack", i)
			return
	if Rect2(BOSS_FEET + Vector2(-20, -68), Vector2(40, 70)).has_point(p):
		hit.emit("staff", 0)
	elif Rect2(CREW_FEET + Vector2(-26, -36), Vector2(52, 38)).has_point(p):
		hit.emit("staff", 1)


func _draw() -> void:
	if S.is_empty():
		return
	var ph: Dictionary = D.PHASES[int(S.phase_idx)]
	var can_knead: bool = str(ph.id).begins_with("bake") and not S.time_up
	# 벽 / 타일 / 바닥
	draw_rect(Rect2(0, 0, 640, 232), Color(0.87, 0.91, 0.89))
	for x in range(0, 640, 24):
		draw_line(Vector2(x, 32), Vector2(x, 232), Color(1, 1, 1, 0.7), 1.0)
	for y in range(32, 232, 24):
		draw_line(Vector2(0, y), Vector2(640, y), Color(1, 1, 1, 0.7), 1.0)
	draw_rect(Rect2(0, 232, 640, 128), Color(0.55, 0.48, 0.40))
	draw_rect(Rect2(0, 232, 640, 3), Color(0.45, 0.38, 0.31))
	draw_colored_polygon(PackedVector2Array([Vector2(320, 34), Vector2(440, 34), Vector2(462, 70), Vector2(298, 70)]), Color(0.66, 0.70, 0.71))

	# ① 반죽대
	draw_rect(Rect2(KNEAD.position + Vector2(0, 34), Vector2(KNEAD.size.x, KNEAD.size.y - 34)), Color(0.66, 0.48, 0.29))
	draw_rect(Rect2(KNEAD.position, Vector2(KNEAD.size.x, 36)), Color(0.91, 0.78, 0.60))
	draw_rect(Rect2(KNEAD.position + Vector2(0, KNEAD.size.y - 4), Vector2(KNEAD.size.x, 4)), Color(0.44, 0.30, 0.17))
	UIUtil.ellipse(self, KNEAD.position + Vector2(70, 18), Vector2(52, 10), Color(1, 1, 1, 0.45))
	UIUtil.ellipse(self, KNEAD.position + Vector2(70, 16), Vector2(24, 13), Color(0.97, 0.91, 0.81))
	if can_knead:
		draw_rect(KNEAD.grow(2), Color(1.0, 0.85, 0.4, 0.35 + 0.25 * sin(_t * 4.0)), false, 2.0)
	var khint := "클릭해서 반죽 시작" if can_knead else ("쉬는 시간" if ph.id == "break" else "지금은 반죽할 수 없어요")
	UIUtil.text(self, khint, KNEAD.position + Vector2(0, 80), 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, KNEAD.size.x)
	UIUtil.tag(self, "① 반죽대", KNEAD.position + Vector2(KNEAD.size.x / 2, 52))

	# ② 발효실
	UIUtil.rounded(self, PROOF, Color(0.74, 0.79, 0.81), Color(0.42, 0.48, 0.50), 6, 2)
	for i in 2:
		var r := proof_slot(i)
		UIUtil.rounded(self, r, Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.85), 5, 2)
		var it = S.proofer[i]
		if it == null:
			UIUtil.text(self, "비어 있음", r.position + Vector2(0, 42), 9, Color(0.3, 0.3, 0.3, 0.6), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			continue
		var p: float = it.p
		var sz := 16.0 + minf(p, 1.1) * 18.0
		var flat := p > 1.25
		UIUtil.ellipse(self, r.position + Vector2(r.size.x / 2, 34), Vector2(sz * 1.3, sz * (0.45 if flat else 0.75)), Color(0.97, 0.91, 0.81))
		UIUtil.gauge(self, Rect2(r.position + Vector2(8, 54), Vector2(r.size.x - 16, 6)), p, D.PROOF_MAX, D.PROOF_BAND)
		var txt := "발효 중…" if p < 0.55 else ("부푸는 중" if p < 1.0 else ("꽤 부풀었어요" if p < 1.25 else "과발효!"))
		UIUtil.text(self, "%s %s · 클릭→오븐" % [D.BREADS[it.type].name, txt], r.position + Vector2(0, 72), 8, Color(0.2, 0.15, 0.1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	UIUtil.tag(self, "② 발효실", PROOF.position + Vector2(PROOF.size.x / 2, -2))

	# ③ 오븐
	UIUtil.rounded(self, OVEN, Color(0.30, 0.27, 0.25), Color(0.16, 0.13, 0.12), 6, 2)
	for i in 2:
		var r := oven_slot(i)
		var it = S.oven[i]
		UIUtil.rounded(self, r, Color(0.18, 0.14, 0.12), Color(0.55, 0.52, 0.50), 5, 2)
		if it == null:
			UIUtil.text(self, "비어 있음", r.position + Vector2(0, 42), 9, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			continue
		draw_rect(r.grow(-3), Color(1.0, 0.5, 0.1, 0.18 + 0.06 * sin(_t * 5.0)))
		var b: float = it.b
		Art.bread(self, it.type, r.position + Vector2(r.size.x / 2, 32), 2.0, Art.oven_color(b))
		if b > 1.2:
			for k in 3:
				var ph2 := fmod(_t * 0.8 + k * 0.33, 1.0)
				draw_circle(r.position + Vector2(r.size.x / 2 - 10 + k * 10, 22 - ph2 * 18), 3.0 + ph2 * 3.0, Color(0.6, 0.6, 0.6, 0.6 * (1.0 - ph2)))
		UIUtil.gauge(self, Rect2(r.position + Vector2(8, 54), Vector2(r.size.x - 16, 6)), b, D.BAKE_MAX, D.BAKE_BAND)
		var txt := "굽는 중…" if b < 0.6 else ("노릇해지는 중" if b < 0.85 else ("황금빛!" if b < 1.08 else ("진한 갈색…" if b < 1.3 else "타고 있어요!")))
		UIUtil.text(self, txt + " · 클릭해서 꺼내기", r.position + Vector2(0, 72), 8, Color(1.0, 0.88, 0.71), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	UIUtil.tag(self, "③ 오븐", OVEN.position + Vector2(OVEN.size.x / 2, -2))

	# ④ 식힘대
	draw_rect(RACK, Color(0.71, 0.73, 0.73), false, 4.0)
	for x in range(int(RACK.position.x) + 8, int(RACK.end.x) - 4, 9):
		draw_line(Vector2(x, RACK.position.y + 2), Vector2(x, RACK.end.y - 2), Color(0.80, 0.82, 0.83), 1.0)
	draw_line(Vector2(RACK.position.x + 6, RACK.end.y), Vector2(RACK.position.x + 6, RACK.end.y + 18), Color(0.6, 0.62, 0.62), 3.0)
	draw_line(Vector2(RACK.end.x - 6, RACK.end.y), Vector2(RACK.end.x - 6, RACK.end.y + 18), Color(0.6, 0.62, 0.62), 3.0)
	for i in 4:
		var r := rack_slot(i)
		var it = S.rack[i]
		if it == null:
			continue
		var ready: bool = float(it.c) >= 1.0
		if ready:
			UIUtil.rounded(self, r, Color(0.47, 0.86, 0.47, 0.30 + 0.15 * sin(_t * 4.0)), Color(0.3, 0.7, 0.3), 5, 1)
		var c: float = it.c
		var tint: Color = Color(0, 0, 0, 0) if ready else Art.BREAD_COLORS[it.type].lerp(Color(0.95, 0.35, 0.15), 0.55 * (1.0 - c))
		Art.bread(self, it.type, r.position + Vector2(r.size.x / 2, 30), 2.0, tint)
		if not ready:
			for k in 3:
				var ph3 := fmod(_t * 0.9 + k * 0.33, 1.0)
				var x := r.position.x + r.size.x / 2 - 12 + k * 12 + sin(_t * 3.0 + k) * 2.0
				draw_line(Vector2(x, r.position.y + 16 - ph3 * 12), Vector2(x + 2, r.position.y + 10 - ph3 * 12), Color(1, 1, 1, 0.8 * (1.0 - ph3)), 1.5)
		var label: String = "진열대로 (%s)" % D.grade_of(float(it.q)).g if ready else "식는 중 %d%%" % int(c * 100.0)
		UIUtil.rounded(self, Rect2(r.position + Vector2(4, 50), Vector2(r.size.x - 8, 13)), Color(1, 1, 1, 0.85), Color(0, 0, 0, 0), 3)
		UIUtil.text(self, label, r.position + Vector2(4, 60), 8, Color(0.2, 0.15, 0.1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8)
	UIUtil.tag(self, "④ 식힘대", RACK.position + Vector2(36, -2))

	# 직원 이름 / 말풍선
	UIUtil.tag(self, "사장", BOSS_FEET + Vector2(0, -74), 8)
	UIUtil.tag(self, "크루", CREW_FEET + Vector2(0, -40), 8)
	if say_t > 0.0 and say_who != "":
		var anchor := BOSS_FEET + Vector2(-10, -88) if say_who == "boss" else CREW_FEET + Vector2(-150, -56)
		var w := minf(180.0, UIUtil.FONT.get_string_size(say_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 16.0)
		UIUtil.rounded(self, Rect2(anchor, Vector2(w, 20)), Color.WHITE, Color(0.6, 0.5, 0.4), 6, 1)
		UIUtil.text(self, say_text, anchor + Vector2(8, 14), 10, Color(0.2, 0.15, 0.1), HORIZONTAL_ALIGNMENT_LEFT, w - 12)

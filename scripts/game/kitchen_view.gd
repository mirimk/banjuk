extends Control
## 주방 화면: ① 반죽대 → ② 발효실(1차·2차) → ③ 성형대 → ④ 오븐 → ⑤ 식힘대, 사장과 크루.
## 그리기와 클릭(탭) 판정만 담당하고, 실제 처리는 game.gd 가 hit 신호를 받아서 한다.

signal hit(what: String, idx: int)

const D = preload("res://scripts/systems/game_data.gd")
const P = preload("res://scripts/game/process.gd")
const UIUtil = preload("res://scripts/systems/ui_util.gd")
const Art = preload("res://scripts/systems/art.gd")
const BreadCharacter = preload("res://scripts/characters/bread_character.gd")

const KNEAD := Rect2(8, 196, 100, 92)
const PROOF := Rect2(114, 76, 108, 212)
const SHAPE := Rect2(228, 172, 104, 116)
const OVEN := Rect2(338, 76, 132, 212)
const RACK := Rect2(478, 128, 154, 160)
const BOSS_FEET := Vector2(280, 170)
const CREW_FEET := Vector2(594, 124)
const INK := Color(0.2, 0.15, 0.1)

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
	return Rect2(PROOF.position.x + 6, PROOF.position.y + 14 + i * 49, PROOF.size.x - 12, 46)


static func shape_slot(i: int) -> Rect2:
	return Rect2(SHAPE.position.x + 4 + i * 49, SHAPE.position.y + 4, 47, 72)


static func oven_slot(i: int) -> Rect2:
	return Rect2(OVEN.position.x + 8, OVEN.position.y + 14 + i * 65, OVEN.size.x - 16, 61)


static func rack_slot(i: int) -> Rect2:
	return Rect2(RACK.position.x + 6 + (i % 2) * 72, RACK.position.y + 8 + int(i / 2) * 74, 70, 70)


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
	for i in D.PROOF_SLOTS:
		if proof_slot(i).has_point(p):
			hit.emit("proof", i)
			return
	for i in D.SHAPE_SLOTS:
		if shape_slot(i).has_point(p):
			hit.emit("shape", i)
			return
	for i in D.OVEN_SLOTS:
		if oven_slot(i).has_point(p):
			hit.emit("oven", i)
			return
	for i in D.RACK_SLOTS:
		if rack_slot(i).has_point(p):
			hit.emit("rack", i)
			return
	if Rect2(BOSS_FEET + Vector2(-20, -68), Vector2(40, 66)).has_point(p):
		hit.emit("staff", 0)
	elif Rect2(CREW_FEET + Vector2(-26, -36), Vector2(52, 38)).has_point(p):
		hit.emit("staff", 1)


func _next_label(it: Dictionary) -> String:
	match P.next_step(it):
		"shape":
			return "탭→성형대"
		"proof2":
			return "탭→2차 발효"
	return "탭→오븐"


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
	draw_colored_polygon(PackedVector2Array([Vector2(354, 34), Vector2(454, 34), Vector2(474, 66), Vector2(334, 66)]), Color(0.66, 0.70, 0.71))

	# 벽 선반: 발효종(르방) 병
	draw_rect(Rect2(10, 150, 96, 4), Color(0.55, 0.40, 0.25))
	if S.flags.get("levain", false):
		var jar := Rect2(44, 118, 26, 32)
		UIUtil.rounded(self, jar, Color(0.85, 0.92, 0.95, 0.75), Color(0.5, 0.6, 0.65), 4, 1)
		var lv := 0.55 + 0.06 * sin(_t * 1.5)
		draw_rect(Rect2(jar.position.x + 3, jar.end.y - 3 - 26 * lv, jar.size.x - 6, 26 * lv), Color(0.95, 0.90, 0.78))
		for k in 3:
			draw_circle(Vector2(jar.position.x + 8 + k * 5, jar.end.y - 8 - k * 4), 1.2, Color(1, 1, 1, 0.8))
		draw_rect(Rect2(jar.position.x - 1, jar.position.y - 3, jar.size.x + 2, 4), Color(0.6, 0.45, 0.3))
		UIUtil.tag(self, "르방", Vector2(57, 112), 8)
	else:
		UIUtil.text(self, "(빈 자리)", Vector2(10, 146), 8, Color(0.4, 0.4, 0.4, 0.5), HORIZONTAL_ALIGNMENT_CENTER, 96)

	# ① 반죽대
	draw_rect(Rect2(KNEAD.position + Vector2(0, 34), Vector2(KNEAD.size.x, KNEAD.size.y - 34)), Color(0.66, 0.48, 0.29))
	draw_rect(Rect2(KNEAD.position, Vector2(KNEAD.size.x, 36)), Color(0.91, 0.78, 0.60))
	draw_rect(Rect2(KNEAD.position + Vector2(0, KNEAD.size.y - 4), Vector2(KNEAD.size.x, 4)), Color(0.44, 0.30, 0.17))
	UIUtil.ellipse(self, KNEAD.position + Vector2(50, 18), Vector2(40, 10), Color(1, 1, 1, 0.45))
	UIUtil.ellipse(self, KNEAD.position + Vector2(50, 16), Vector2(20, 12), Color(0.97, 0.91, 0.81))
	if can_knead:
		draw_rect(KNEAD.grow(2), Color(1.0, 0.85, 0.4, 0.35 + 0.25 * sin(_t * 4.0)), false, 2.0)
	var khint := "탭해서 반죽" if can_knead else ("쉬는 시간" if ph.id == "break" else "지금은 반죽 불가")
	UIUtil.text(self, khint, KNEAD.position + Vector2(0, 76), 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, KNEAD.size.x)
	UIUtil.tag(self, "① 반죽대", KNEAD.position + Vector2(KNEAD.size.x / 2, 52))

	# ② 발효실
	UIUtil.rounded(self, PROOF, Color(0.74, 0.79, 0.81), Color(0.42, 0.48, 0.50), 6, 2)
	for i in D.PROOF_SLOTS:
		var r := proof_slot(i)
		UIUtil.rounded(self, r, Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.85), 5, 2)
		var it = S.proofer[i]
		if it == null:
			UIUtil.text(self, "비어 있음", r.position + Vector2(0, 27), 9, Color(0.3, 0.3, 0.3, 0.6), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			continue
		var p: float = it.p
		var second: bool = it.stage == "proof2"
		Art.dough(self, it.type, r.position + Vector2(r.size.x / 2, 13), 1.0, p, second)
		UIUtil.gauge(self, Rect2(r.position + Vector2(6, 25), Vector2(r.size.x - 12, 4)), p, D.PROOF_MAX, D.PROOF_BAND)
		var txt := "발효 중" if p < 0.55 else ("부푸는 중" if p < 0.75 else ("딱 좋아요!" if p < 1.0 else ("많이 부풂" if p < 1.25 else "과발효!")))
		var stage_name := "2차" if second else ("1차" if P.needs(it.type, "proof2") or P.needs(it.type, "shape") else "")
		UIUtil.text(self, "%s %s" % [D.BREADS[it.type].name, stage_name], r.position + Vector2(0, 36), 7, INK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		var dest := "탭→성형대" if not second and P.needs(it.type, "shape") else "탭→오븐"
		UIUtil.text(self, "%s · %s" % [txt, dest], r.position + Vector2(0, 44), 7, Color(0.35, 0.3, 0.25), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	UIUtil.tag(self, "② 발효실", PROOF.position + Vector2(PROOF.size.x / 2, -2))

	# ③ 성형대
	var tier2 := D.tier_unlocked(2, int(S.day))
	draw_rect(Rect2(SHAPE.position + Vector2(0, 74), Vector2(SHAPE.size.x, SHAPE.size.y - 74)), Color(0.62, 0.45, 0.28))
	draw_rect(Rect2(SHAPE.position + Vector2(0, 66), Vector2(SHAPE.size.x, 10)), Color(0.85, 0.72, 0.54))
	for i in D.SHAPE_SLOTS:
		var r := shape_slot(i)
		UIUtil.rounded(self, Rect2(r.position + Vector2(0, 40), Vector2(r.size.x, 30)), Color(0.93, 0.84, 0.68), Color(0.72, 0.58, 0.40), 4, 1)
		var it = S.shaper[i]
		if it == null:
			continue
		var shaped: bool = it.get("shaped", false)
		if not shaped:
			draw_rect(r.grow(1), Color(1.0, 0.85, 0.4, 0.35 + 0.25 * sin(_t * 4.0)), false, 2.0)
		Art.dough(self, it.type, r.position + Vector2(r.size.x / 2, 52), 1.2, 1.0 if shaped else 0.9, shaped)
		UIUtil.rounded(self, Rect2(r.position + Vector2(1, 2), Vector2(r.size.x - 2, 24)), Color(1, 1, 1, 0.85), Color(0, 0, 0, 0), 3)
		UIUtil.text(self, D.BREADS[it.type].name, r.position + Vector2(0, 12), 7, INK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		UIUtil.text(self, (_next_label(it) if shaped else "탭해서 성형"), r.position + Vector2(0, 22), 7, Color(0.55, 0.3, 0.1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if not tier2:
		UIUtil.text(self, "3일차부터 사용", SHAPE.position + Vector2(0, 100), 8, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, SHAPE.size.x)
	UIUtil.tag(self, "③ 성형대", SHAPE.position + Vector2(SHAPE.size.x / 2, 92))

	# ④ 오븐
	UIUtil.rounded(self, OVEN, Color(0.30, 0.27, 0.25), Color(0.16, 0.13, 0.12), 6, 2)
	for i in D.OVEN_SLOTS:
		var r := oven_slot(i)
		var it = S.oven[i]
		UIUtil.rounded(self, r, Color(0.18, 0.14, 0.12), Color(0.55, 0.52, 0.50), 5, 2)
		if it == null:
			UIUtil.text(self, "비어 있음", r.position + Vector2(0, 34), 9, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			continue
		draw_rect(r.grow(-3), Color(1.0, 0.5, 0.1, 0.18 + 0.06 * sin(_t * 5.0)))
		var b: float = it.b
		for k in 2:
			Art.bread(self, it.type, r.position + Vector2(r.size.x / 2 - 22 + k * 44, 18), 1.3, Art.oven_color(b))
		if b > 1.2:
			for k in 3:
				var ph2 := fmod(_t * 0.8 + k * 0.33, 1.0)
				draw_circle(r.position + Vector2(r.size.x / 2 - 10 + k * 10, 14 - ph2 * 12), 2.5 + ph2 * 3.0, Color(0.6, 0.6, 0.6, 0.6 * (1.0 - ph2)))
		UIUtil.gauge(self, Rect2(r.position + Vector2(8, 32), Vector2(r.size.x - 16, 5)), b, D.BAKE_MAX, D.BAKE_BAND)
		var txt := "굽는 중…" if b < 0.6 else ("노릇해지는 중" if b < 0.85 else ("황금빛!" if b < 1.08 else ("진한 갈색…" if b < 1.3 else "타고 있어요!")))
		UIUtil.text(self, "%s x%d%s" % [D.BREADS[it.type].name, D.BATCH, " (공정 생략)" if it.get("skip", false) else ""], r.position + Vector2(0, 47), 7, Color(1.0, 0.88, 0.71, 0.8), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		UIUtil.text(self, txt + " · 탭해서 꺼내기", r.position + Vector2(0, 57), 7, Color(1.0, 0.88, 0.71), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	UIUtil.tag(self, "④ 오븐", OVEN.position + Vector2(OVEN.size.x / 2, -2))

	# ⑤ 식힘대
	draw_rect(RACK, Color(0.71, 0.73, 0.73), false, 4.0)
	for x in range(int(RACK.position.x) + 8, int(RACK.end.x) - 4, 9):
		draw_line(Vector2(x, RACK.position.y + 2), Vector2(x, RACK.end.y - 2), Color(0.80, 0.82, 0.83), 1.0)
	draw_line(Vector2(RACK.position.x + 6, RACK.end.y), Vector2(RACK.position.x + 6, RACK.end.y + 18), Color(0.6, 0.62, 0.62), 3.0)
	draw_line(Vector2(RACK.end.x - 6, RACK.end.y), Vector2(RACK.end.x - 6, RACK.end.y + 18), Color(0.6, 0.62, 0.62), 3.0)
	for i in D.RACK_SLOTS:
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
		var g: String = D.grade_of(float(it.q)).g
		var label: String = "%s · %s" % [g, D.fmt_money(float(D.sale_price(it.type, g)))] if ready else "식는 중 %d%%" % int(c * 100.0)
		UIUtil.rounded(self, Rect2(r.position + Vector2(3, 52), Vector2(r.size.x - 6, 14)), Color(1, 1, 1, 0.85), Color(0, 0, 0, 0), 3)
		UIUtil.text(self, label, r.position + Vector2(3, 62), 8, INK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 6)
	UIUtil.tag(self, "⑤ 식힘대", RACK.position + Vector2(36, -2))

	# 직원 이름 / 말풍선
	UIUtil.tag(self, "사장", BOSS_FEET + Vector2(0, -74), 8)
	UIUtil.tag(self, "크루", CREW_FEET + Vector2(0, -40), 8)
	if say_t > 0.0 and say_who != "":
		var w := minf(200.0, UIUtil.FONT.get_string_size(say_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 16.0)
		var anchor := BOSS_FEET + Vector2(-w / 2, -100) if say_who == "boss" else CREW_FEET + Vector2(-w - 10, -56)
		UIUtil.rounded(self, Rect2(anchor, Vector2(w, 20)), Color.WHITE, Color(0.6, 0.5, 0.4), 6, 1)
		UIUtil.text(self, say_text, anchor + Vector2(8, 14), 10, INK, HORIZONTAL_ALIGNMENT_LEFT, w - 12)

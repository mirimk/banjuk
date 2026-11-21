extends Control
## 하루 진행 메인 씬 (주방 ↔ 빵집).
## 시간표: 05~08 빵 만들기 / 08~11 영업 / 11~13 쉬는 시간(스토리) / 13~15 빵 만들기 / 15~18 영업 → 정산
## 상태는 모두 GameState.s 에 있고, 이 스크립트는 규칙과 화면 연결을 담당한다.

const D = preload("res://scripts/systems/game_data.gd")
const P = preload("res://scripts/game/process.gd")
const UIUtil = preload("res://scripts/systems/ui_util.gd")
const KitchenView = preload("res://scripts/game/kitchen_view.gd")
const BakeryView = preload("res://scripts/game/bakery_view.gd")
const Hud = preload("res://scripts/game/hud.gd")
const KneadPanel = preload("res://scripts/game/knead_panel.gd")
const ShapePanel = preload("res://scripts/game/shape_panel.gd")
const BreadPicker = preload("res://scripts/game/bread_picker.gd")
const DialogueBox = preload("res://scripts/dialogue/dialogue_box.gd")

const MOVE_LABELS := {"bake1": "빵집으로", "sale1": "주방으로 (쉬는 시간)", "bake2": "빵집으로", "sale2": "퇴근하기"}
const TIME_UP_MSG := {"bake1": "08:00 — 빵집 오픈 시간이에요!", "sale1": "11:00 — 오전 영업 끝! 쉬는 시간이에요.", "bake2": "15:00 — 오후 영업 시간이에요!", "sale2": "18:00 — 퇴근 시간이에요!"}
const RIDERS := ["빵배달 라이더 정우", "빵배달 라이더 수진", "빵배달 라이더 하산", "빵배달 라이더 민지"]

var S: Dictionary
var kitchen: KitchenView
var bakery: BakeryView
var hud: Hud
var knead: KneadPanel
var shaper: ShapePanel
var picker: BreadPicker
var dialogue: DialogueBox
var story_running := false

var _tip: Label
var _btn_eat: Button
var _btn_speed: Button
var _btn_skip: Button
var _btn_move: Button
var _t := 0.0
var _tired_warned := false


func _ready() -> void:
	S = GameState.s
	kitchen = KitchenView.new()
	kitchen.S = S
	kitchen.hit.connect(_on_kitchen_hit)
	add_child(kitchen)
	bakery = BakeryView.new()
	bakery.S = S
	bakery.hit.connect(_on_bakery_hit)
	add_child(bakery)
	hud = Hud.new()
	add_child(hud)
	_build_bottom()

	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	picker = BreadPicker.new()
	picker.picked.connect(_start_knead)
	picker.blocked.connect(func(msg: String) -> void:
		GameState.toast(msg)
		Sound.sfx("bad"))
	picker.hide()
	layer.add_child(picker)
	knead = KneadPanel.new()
	knead.finished.connect(_finish_knead)
	knead.hide()
	layer.add_child(knead)
	shaper = ShapePanel.new()
	shaper.finished.connect(_finish_shape)
	shaper.hide()
	layer.add_child(shaper)

	dialogue = DialogueBox.new()
	add_child(dialogue)

	_refresh()
	if S.story != null:
		_run_story()


func _build_bottom() -> void:
	var bar := Panel.new()
	bar.position = Vector2(0, 326)
	bar.size = Vector2(640, 34)
	bar.add_theme_stylebox_override("panel", UIUtil.panel_style(Color(0.16, 0.10, 0.06, 0.9), Color(0, 0, 0, 0), 0))
	add_child(bar)
	_tip = UIUtil.label("", 9, Color(1.0, 0.97, 0.92))
	_tip.position = Vector2(8, 10)
	bar.add_child(_tip)
	var box := HBoxContainer.new()
	box.position = Vector2(236, 4)
	box.size = Vector2(398, 26)
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 4)
	bar.add_child(box)
	_btn_eat = UIUtil.button("빵 먹기", 10)
	_btn_eat.focus_mode = Control.FOCUS_NONE
	_btn_eat.tooltip_text = "빵을 먹어 체력 회복 (빵값은 일급에서 차감)"
	_btn_eat.pressed.connect(open_eat)
	box.add_child(_btn_eat)
	_btn_speed = UIUtil.button("시간 x1", 10)
	_btn_speed.focus_mode = Control.FOCUS_NONE
	_btn_speed.pressed.connect(func() -> void:
		S.speed = 3 if int(S.speed) == 1 else 1
		Sound.sfx("click"))
	box.add_child(_btn_speed)
	_btn_skip = UIUtil.button("건너뛰기", 10)
	_btn_skip.focus_mode = Control.FOCUS_NONE
	_btn_skip.pressed.connect(_on_skip)
	box.add_child(_btn_skip)
	_btn_move = UIUtil.button("이동", 10)
	_btn_move.focus_mode = Control.FOCUS_NONE
	_btn_move.pressed.connect(try_move)
	box.add_child(_btn_move)


func _phase() -> Dictionary:
	return D.PHASES[int(S.phase_idx)]


func _day() -> int:
	return int(S.day)


# ---------------------------------------------------------------- 루프

func _process(delta: float) -> void:
	_t += delta
	var blocked := GameState.busy or dialogue.active or GameState.overlay.modal_open()
	if not blocked:
		_update(delta)
		if knead.visible:
			knead.tick(delta)
		if shaper.visible:
			shaper.tick(delta)
	_refresh()


func _refresh() -> void:
	var in_kitchen: bool = S.location == "kitchen"
	Sound.bgm(S.location)
	kitchen.visible = in_kitchen
	bakery.visible = not in_kitchen
	var ph := _phase()
	var is_break: bool = ph.id == "break"
	_btn_move.get_parent().visible = not is_break
	_tip.visible = not is_break
	if is_break:
		return
	var end_t := D.fmt_time(float(ph.end))
	_btn_speed.text = "시간 x%d" % int(S.speed)
	_btn_skip.text = "%s까지 건너뛰기" % end_t
	_btn_skip.disabled = S.time_up
	_btn_move.disabled = not S.time_up
	_btn_move.text = MOVE_LABELS[ph.id] if S.time_up else "%s (%s~)" % [MOVE_LABELS[ph.id], end_t]
	_btn_move.modulate = Color(1, 1, 1).lerp(Color(1.3, 1.2, 0.9), 0.5 + 0.5 * sin(_t * 5.0)) if S.time_up else Color.WHITE
	var low := float(S.stamina) < 20.0
	_btn_eat.modulate = Color(1, 1, 1).lerp(Color(1.4, 1.1, 0.7), 0.5 + 0.5 * sin(_t * 6.0)) if low else Color.WHITE
	if in_kitchen:
		if S.time_up:
			_tip.text = "오픈 시간! 진행 중인 빵을 마무리하고 나가세요."
		elif low:
			_tip.text = "체력이 부족해요! '빵 먹기'로 회복 (일급에서 차감)"
		else:
			_tip.text = "%s  ·  진열대 %d개" % [P.flow_text(D.max_tier(_day())).replace(" → ", "→"), S.shelf.size()]
	else:
		var extra := "  ·  배달 주문 중" if S.delivery != null else ""
		_tip.text = "영업 종료! 남은 손님을 응대하고 이동하세요." if S.time_up else "손님이 원하는 빵을 진열대에서 탭%s  ·  판매 %d개" % [extra, int(S.today.sold)]


func _update(dt: float) -> void:
	var ph := _phase()
	if ph.id != "break" and not S.time_up:
		S.minute = float(S.minute) + dt * int(S.speed) / D.SEC_PER_MIN
		if S.minute >= float(ph.end):
			S.minute = float(ph.end)
			S.time_up = true
			Sound.sfx("bell")
			GameState.toast(TIME_UP_MSG[ph.id])
	# 시간 배속은 발효·굽기·손님 대기까지 모두 빠르게 한다 (미니게임은 제외)
	var sdt := dt * int(S.speed)
	if S.location == "kitchen":
		_update_kitchen(sdt)
	else:
		_update_bakery(sdt, ph)


func _update_kitchen(dt: float) -> void:
	for it in S.proofer:
		if it != null:
			it.p = minf(D.PROOF_MAX + 0.1, float(it.p) + dt / D.PROOF_TIME)
	for it in S.oven:
		if it == null:
			continue
		it.b = minf(D.BAKE_MAX + 0.05, float(it.b) + dt / D.BAKE_TIME)
		if not it.dinged and it.b >= 0.9:
			it.dinged = true
			Sound.sfx("ding")
		if not it.warned and it.b >= 1.2:
			it.warned = true
			GameState.toast("타는 냄새가 나요!")
	for it in S.rack:
		if it != null:
			it.c = minf(1.0, float(it.c) + dt / D.COOL_TIME)


func _update_bakery(dt: float, ph: Dictionary) -> void:
	if not S.time_up:
		S.spawn_timer = float(S.spawn_timer) - dt
		if S.spawn_timer <= 0.0:
			if _active_customers().size() < 4:
				_spawn_customer()
			var iv := D.spawn_interval(_day()) * D.mood_spawn(float(S.mood))   # 기분이 낮으면 손님이 덜 옴
			S.spawn_timer = randf_range(iv.x, iv.y)
		if ph.id == "sale2" and not S.secret_done and float(S.minute) >= D.SECRET_MINUTE:
			S.secret_done = true
			_spawn_secret()
		if S.delivery == null and int(S.deliv_left) > 0:
			S.deliv_timer = float(S.deliv_timer) - dt
			if S.deliv_timer <= 0.0:
				_spawn_delivery()
	var first := true
	for c in S.customers:
		if c.state == "leaving":
			c.lt = float(c.lt) - dt
			continue
		c.pat = float(c.pat) - dt / (float(c.maxT) if first else float(c.maxT) * 3.0)
		first = false
		if c.pat <= 0.0:
			if c.get("secret", false):
				_secret_leave(c, false)
			else:
				if not _sold_out_penalty(c):
					_late_penalty(c)
				GameState.add_stat("mood", -3)
				S.today.missed = int(S.today.missed) + 1
				Sound.sfx("bad")
	S.customers = S.customers.filter(func(c: Dictionary) -> bool: return c.state != "leaving" or float(c.lt) > 0.0)
	_update_delivery(dt)
	bakery.S = S


# ---------------------------------------------------------------- 이동 / 시간대

func _on_skip() -> void:
	if S.time_up:
		return
	var ph := _phase()
	GameState.ask("%s까지 시간을 건너뛸까요?" % D.fmt_time(float(ph.end)), func() -> void:
		S.minute = float(ph.end) - 0.01)


func try_move() -> void:
	if not S.time_up:
		return
	var ph := _phase()
	if ph.loc == "kitchen":
		var n := _count(S.proofer) + _count(S.shaper) + _count(S.oven)
		if n > 0:
			GameState.ask("발효실·성형대·오븐에 반죽 %d판이 남아 있어요.\n지금 나가면 버려집니다. 나갈까요?\n(식힘대의 빵은 크루가 진열대로 옮겨줘요)" % n, advance_phase)
			return
	else:
		var n := _active_customers().size()
		var deliv: bool = S.delivery != null and S.delivery.state == "wait"
		if n > 0 or deliv:
			GameState.ask("아직 손님 %d명%s이 기다리고 있어요.\n그래도 이동할까요?" % [n, " · 배달 주문 1건" if deliv else ""], advance_phase)
			return
	advance_phase()


func advance_phase() -> void:
	var ph := _phase()
	if str(ph.id).begins_with("bake"):
		S.today.lost = int(S.today.lost) + (_count(S.proofer) + _count(S.shaper) + _count(S.oven)) * D.BATCH
		for it in S.rack:
			if it != null:
				var q := int(it.q)
				if float(it.c) < 1.0:
					q = mini(q, D.SKIP_Q)   # 덜 식은 채로 옮겨짐
				_shelve(it.type, q, true)
		S.proofer = GameState._nulls(D.PROOF_SLOTS)
		S.shaper = GameState._nulls(D.SHAPE_SLOTS)
		S.oven = GameState._nulls(D.OVEN_SLOTS)
		S.rack = GameState._nulls(D.RACK_SLOTS)
	if str(ph.id).begins_with("sale"):
		S.today.missed = int(S.today.missed) + _active_customers().size()
		S.customers = []
		if S.delivery != null and S.delivery.state == "wait":
			_fail_delivery("주문이 취소됐어요…")
		S.delivery = null
	knead.hide()
	shaper.hide()
	picker.hide()
	if int(S.phase_idx) == D.PHASES.size() - 1:
		_go_settle()
		return
	var next_idx := int(S.phase_idx) + 1
	var np: Dictionary = D.PHASES[next_idx]
	Sound.sfx("door")
	var subs := {"sale1": "08:00 · 빵집 오픈", "break": "11:00 · 주방 · 쉬는 시간", "bake2": "13:00 · 오후 빵 만들기", "sale2": "15:00 · 오후 영업"}
	await GameState.transition("주방" if np.loc == "kitchen" else "빵집", subs[np.id], _apply_phase.bind(next_idx))
	if S.story != null:
		_run_story()


func _apply_phase(idx: int) -> void:
	var np: Dictionary = D.PHASES[idx]
	S.phase_idx = idx
	S.minute = float(np.start)
	S.time_up = false
	S.location = np.loc
	S.spawn_timer = 1.0
	S.speed = 1
	_tired_warned = false
	if str(np.id).begins_with("sale"):
		S.deliv_left = D.deliveries_per_phase(_day())
		S.deliv_timer = randf_range(8.0, 16.0)
		S.delivery = null
	if np.id == "break":
		S.story = {"key": "break%d" % _day(), "idx": 0, "ret": null}


func _go_settle() -> void:
	S.today.discarded = S.shelf.size()
	S.shelf = []
	S.peaks.append(int(round(float(S.damage))))
	S.moods.append(int(round(float(S.mood))))
	# 2일차에 비밀 손님을 놓쳤다면, 퇴근길 문 앞에 르방 병이 놓여 있다
	if _day() >= 2 and not S.flags.get("levain", false):
		S.flags.levain = true
		S.flags.levain_door = true
		S.flags.secret2 = true
	Sound.sfx("door")
	GameState.change_scene("settle", "퇴근", "%d일차 18:00" % _day())


# ---------------------------------------------------------------- 스토리

func _run_story() -> void:
	if story_running:
		return
	story_running = true
	while S.story != null:
		var st: Dictionary = S.story
		var lines: Array = GameState.stories.get(st.key, [])
		var idx := int(st.idx)
		if idx >= lines.size():
			if st.ret != null:
				S.story = st.ret
				continue
			var key: String = st.key
			S.story = null
			story_running = false
			_on_story_end(key)
			return
		var ln: Dictionary = lines[idx]
		if ln.has("cond") and not GameState.cond(ln.cond):
			st.idx = idx + 1
			continue
		var r: int = await dialogue.say(ln, float(S.damage))
		if not is_inside_tree():
			return
		st.idx = idx + 1
		if r >= 0 and ln.has("choices"):
			var o: Dictionary = ln.choices[r]
			if o.has("set"):
				S.flags[o.set] = true
			if o.has("aff"):
				for k in o.aff:
					S.affinity[k] = int(S.affinity.get(k, 0)) + int(o.aff[k])
			if o.has("dmg"):
				GameState.add_stat("damage", float(o.dmg))
			if o.has("mood"):
				GameState.add_stat("mood", float(o.mood))
			Sound.sfx("good")
			if o.has("go"):
				S.story = {"key": o.go, "idx": 0, "ret": st}
	story_running = false


func _on_story_end(key: String) -> void:
	if key.begins_with("break"):
		advance_phase()


# ---------------------------------------------------------------- 주방

func _busy_ui() -> bool:
	return dialogue.active or GameState.busy or knead.visible or shaper.visible or picker.visible


func _on_kitchen_hit(what: String, idx: int) -> void:
	if _busy_ui():
		return
	match what:
		"knead":
			open_picker()
		"proof":
			click_proof(idx)
		"shape":
			click_shape(idx)
		"oven":
			click_oven(idx)
		"rack":
			click_rack(idx)
		"staff":
			var who := "boss" if idx == 0 else "crew"
			kitchen.say(who, D.STAFF_TALK[who].pick_random())
			Sound.sfx("click")


func _no_stamina(need: float) -> bool:
	if float(S.stamina) >= need:
		return false
	GameState.toast("너무 지쳤어요… (체력 %d 필요) '빵 먹기'로 회복하세요" % int(need))
	Sound.sfx("bad")
	return true


func _check_tired() -> void:
	if float(S.stamina) < 10.0 and not _tired_warned:
		_tired_warned = true
		get_tree().create_timer(0.8).timeout.connect(func() -> void:
			GameState.toast("체력이 바닥나고 있어요! 아래 '빵 먹기'로 회복할 수 있어요 (일급에서 차감)"))


func open_picker() -> void:
	var ph := _phase()
	if not str(ph.id).begins_with("bake"):
		return
	if S.time_up:
		GameState.toast("영업 시간이에요! 진행 중인 빵만 마무리하세요.")
		Sound.sfx("bad")
		return
	if not S.proofer.has(null):
		GameState.toast("발효실이 꽉 찼어요! 발효된 반죽을 먼저 다음 공정으로 옮기세요.")
		Sound.sfx("bad")
		return
	if _no_stamina(float(D.TIERS[1].st_knead)):
		return
	Sound.sfx("click")
	picker.open(_day(), S.flags.get("levain", false))


func _start_knead(type: String) -> void:
	var t: Dictionary = D.TIERS[D.tier_of(type)]
	if _no_stamina(float(t.st_knead)):
		return
	GameState.add_stat("stamina", -float(t.st_knead))
	GameState.add_stat("damage", float(t.dmg_knead))
	knead.start(type, float(S.stamina), float(S.damage))
	_check_tired()


func _finish_knead(type: String, score: float) -> void:
	var i: int = S.proofer.find(null)
	if i < 0:
		GameState.toast("발효실에 자리가 없어 반죽을 버렸어요…")
		S.today.lost = int(S.today.lost) + D.BATCH
		return
	S.proofer[i] = P.new_item(type, score)
	GameState.toast("%s 반죽을 발효실에 넣었어요" % D.BREADS[type].name)


## 발효실의 반죽을 탭: 다음 공정(성형대 또는 오븐)으로. 성형이 필요한 빵은 건너뛸지 고를 수 있다.
func click_proof(i: int) -> void:
	var it = S.proofer[i]
	if it == null:
		return
	var score := P.proof_score(float(it.p))
	if it.stage == "proof2":
		_proof_to_oven(i, score, false)
		return
	if P.needs(it.type, "shape"):
		var skip_msg := "바로 오븐에 넣기 (성형%s 생략 → 등급 F)" % (" · 2차 발효" if P.needs(it.type, "proof2") else "")
		GameState.overlay.choose("%s 발효 %s (%d)\n다음 공정은 성형이에요." % [D.BREADS[it.type].name, KneadPanel.word(score), int(score)],
			["성형대로 옮기기 (정상 공정)", skip_msg], func(k: int) -> void:
				if k == 0:
					_proof_to_shaper(i, score)
				else:
					_proof_to_oven(i, score, true))
		return
	_proof_to_oven(i, score, false)


func _proof_to_shaper(i: int, score: float) -> void:
	var it = S.proofer[i]
	if it == null:
		return
	var j: int = S.shaper.find(null)
	if j < 0:
		GameState.toast("성형대가 꽉 찼어요! 성형대의 반죽을 먼저 처리하세요.")
		Sound.sfx("bad")
		return
	it.ps = score
	it.shaped = false
	S.shaper[j] = it
	S.proofer[i] = null
	GameState.toast("발효 %s (%d) → 성형대로! 탭해서 모양을 잡으세요" % [KneadPanel.word(score), int(score)])
	Sound.sfx("good" if score >= 70.0 else "click")


func _proof_to_oven(i: int, score: float, skip: bool) -> void:
	var it = S.proofer[i]
	if it == null:
		return
	if not _put_in_oven(it, skip):
		return
	S.proofer[i] = null
	if it.stage == "proof2":
		it.ps2 = score
		GameState.toast("2차 발효 %s (%d) → 오븐으로!" % [KneadPanel.word(score), int(score)])
	else:
		it.ps = score
		GameState.toast(("공정 생략! " if skip else "") + "발효 %s (%d) → 오븐으로!" % [KneadPanel.word(score), int(score)])
	Sound.sfx("good" if score >= 70.0 and not skip else "click")


## 오븐 빈칸에 넣는다. skip 이면 남은 공정을 건너뛴 것(등급 F).
func _put_in_oven(it: Dictionary, skip: bool) -> bool:
	var j: int = S.oven.find(null)
	if j < 0:
		GameState.toast("오븐이 꽉 찼어요! 오븐의 빵을 먼저 꺼내세요.")
		Sound.sfx("bad")
		return false
	if skip:
		it.skip = true
	it.b = 0.0
	it.dinged = false
	it.warned = false
	S.oven[j] = it
	return true


## 성형대의 반죽을 탭: 성형 전이면 성형 미니게임, 성형 후면 다음 공정(오븐 또는 2차 발효).
func click_shape(i: int) -> void:
	var it = S.shaper[i]
	if it == null:
		return
	if not it.get("shaped", false):
		var t: Dictionary = D.TIERS[D.tier_of(it.type)]
		if _no_stamina(float(t.st_shape)):
			return
		Sound.sfx("click")
		shaper.start(i, it.type, float(S.stamina), float(S.damage))
		return
	if P.needs(it.type, "proof2"):
		GameState.overlay.choose("%s 성형 완료 (%d)\n다음 공정은 2차 발효예요." % [D.BREADS[it.type].name, int(it.ss)],
			["2차 발효실로 옮기기 (정상 공정)", "바로 오븐에 넣기 (2차 발효 생략 → 등급 F)"], func(k: int) -> void:
				if k == 0:
					_shaper_to_proof(i)
				else:
					_shaper_to_oven(i, true))
		return
	_shaper_to_oven(i, false)


func _shaper_to_proof(i: int) -> void:
	var it = S.shaper[i]
	if it == null:
		return
	var j: int = S.proofer.find(null)
	if j < 0:
		GameState.toast("발효실이 꽉 찼어요!")
		Sound.sfx("bad")
		return
	it.stage = "proof2"
	it.p = 0.0
	S.proofer[j] = it
	S.shaper[i] = null
	GameState.toast("%s → 2차 발효 시작" % D.BREADS[it.type].name)
	Sound.sfx("click")


func _shaper_to_oven(i: int, skip: bool) -> void:
	var it = S.shaper[i]
	if it == null or not _put_in_oven(it, skip):
		return
	S.shaper[i] = null
	GameState.toast(("공정 생략! " if skip else "") + "%s → 오븐으로!" % D.BREADS[it.type].name)
	Sound.sfx("click" if skip else "good")


func _finish_shape(slot: int, score: float) -> void:
	var it = S.shaper[slot]
	if it == null or score < 0.0:
		return
	var t: Dictionary = D.TIERS[D.tier_of(it.type)]
	GameState.add_stat("stamina", -float(t.st_shape))
	GameState.add_stat("damage", float(t.dmg_shape))
	it.ss = score
	it.shaped = true
	GameState.toast("성형 %s (%d) · 다시 탭하면 다음 공정으로" % [KneadPanel.word(score), int(score)])
	_check_tired()


func click_oven(i: int) -> void:
	var it = S.oven[i]
	if it == null:
		return
	var j: int = S.rack.find(null)
	if j < 0:
		GameState.toast("식힘대가 꽉 찼어요! 다 식은 빵을 진열대로 옮기세요.")
		Sound.sfx("bad")
		return
	var bs := P.bake_score(float(it.b))
	var q := P.quality(it, bs)
	S.rack[j] = {"type": it.type, "q": q, "c": 0.0}
	S.oven[i] = null
	var t: Dictionary = D.TIERS[D.tier_of(it.type)]
	GameState.add_stat("damage", float(t.dmg_oven) + (3.0 if float(it.b) > 1.25 else 0.0))   # 오븐 열기
	S.today.made = int(S.today.made) + D.BATCH
	var g: String = D.grade_of(q).g
	GameState.toast("굽기 %s (%d) → 빵 완성! 등급 %s · 개당 %s%s" % [KneadPanel.word(bs), int(bs), g, D.fmt_money(D.sale_price(it.type, g)), " (공정 생략)" if it.get("skip", false) else ""])
	Sound.sfx("great" if g == "S" or g == "A" else "good")
	if float(S.damage) >= 30.0 and not S.flags.get("heat_hint", false):
		S.flags.heat_hint = true
		get_tree().create_timer(0.9).timeout.connect(func() -> void:
			GameState.toast("손끝에 반죽이 들러붙어 잘 떨어지지 않는다…"))


func click_rack(i: int) -> void:
	var it = S.rack[i]
	if it == null:
		return
	if float(it.c) < 1.0:
		GameState.ask("아직 뜨거워요! 지금 진열하면 식히기 공정을 건너뛰어\n등급이 최하(F)가 됩니다. 그래도 옮길까요?", func() -> void:
			_rack_to_shelf(i, true))
		return
	_rack_to_shelf(i, false)


func _rack_to_shelf(i: int, hot: bool) -> void:
	var it = S.rack[i]
	if it == null:
		return
	var q := mini(int(it.q), D.SKIP_Q) if hot else int(it.q)
	for k in D.BATCH:
		_shelve(it.type, q, false)
	S.rack[i] = null
	GameState.toast("%s %d개를 진열대로 옮겼어요%s" % [D.BREADS[it.type].name, D.BATCH, " (덜 식음 · F)" if hot else ""])
	Sound.sfx("cash")


func _shelve(type: String, q: int, whole_batch: bool) -> void:
	for k in (D.BATCH if whole_batch else 1):
		S.shelf.append({"type": type, "q": q, "g": D.grade_of(float(q)).g})


## 진열대에서 그 종류 중 가장 등급이 좋은 빵의 번호 (없으면 -1). worst 면 가장 나쁜 빵.
func shelf_pick(type: String, worst: bool = false) -> int:
	var best := -1
	for i in S.shelf.size():
		var b: Dictionary = S.shelf[i]
		if b.type != type:
			continue
		if best < 0 or (int(b.q) < int(S.shelf[best].q) if worst else int(b.q) > int(S.shelf[best].q)):
			best = i
	return best


# ---------------------------------------------------------------- 빵 먹기 (체력 회복, 일급에서 차감)

## 먹을 수 있는 빵: 진열대의 (종류, 등급) 조합마다 하나씩, 비싼 순 (최대 9개) + 사장님 빵
func eat_options() -> Array:
	var seen := {}
	var opts := []
	for b in S.shelf:
		var key := "%s/%s" % [b.type, b.g]
		if seen.has(key):
			continue
		seen[key] = true
		var cost := D.sale_price(b.type, b.g)
		opts.append({"type": b.type, "g": b.g, "cost": cost, "st": D.eat_stamina(cost)})
	opts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.cost) > int(b.cost))
	opts = opts.slice(0, 9)
	var staff := int(D.STAFF_BREAD.price)
	opts.append({"type": "", "g": "", "cost": staff, "st": D.eat_stamina(staff)})
	return opts


func open_eat() -> void:
	if _busy_ui() or _phase().id == "break":
		return
	var opts := eat_options()
	var labels := []
	for k in opts.size():
		var o: Dictionary = opts[k]
		var nm: String = D.STAFF_BREAD.name if o.type == "" else "%s (%s)" % [D.BREADS[o.type].name, o.g]
		labels.append("%s  체력+%d · -%s" % [nm, int(o.st), D.fmt_money(float(o.cost))])
	Sound.sfx("click")
	GameState.overlay.choose("무엇을 먹을까요?  (체력 %d/100)\n비싼 빵일수록 체력이 많이 올라요. 빵값은 일급에서 차감 (모자라면 빚)" % int(S.stamina), labels, func(k: int) -> void:
		eat(opts[k]))


func eat(o: Dictionary) -> void:
	if o.type != "":
		var i := -1
		for k in S.shelf.size():
			if S.shelf[k].type == o.type and S.shelf[k].g == o.g:
				i = k
				break
		if i < 0:
			return
		S.shelf.remove_at(i)
	S.money = int(S.money) - int(o.cost)
	S.today.eaten = int(S.today.eaten) + 1
	S.today.eat_cost = int(S.today.eat_cost) + int(o.cost)
	GameState.add_stat("stamina", float(o.st))
	_tired_warned = false
	var nm: String = "빵" if o.type == "" else D.BREADS[o.type].name
	GameState.toast("%s을(를) 먹었다. 체력 +%d · 일급 -%s" % [nm, int(o.st), D.fmt_money(float(o.cost))])
	Sound.sfx("good")


# ---------------------------------------------------------------- 빵집 / 손님

func _on_bakery_hit(what: String, idx: int) -> void:
	if dialogue.active or GameState.busy:
		return
	match what:
		"give":
			give_bread(D.BREAD_ORDER[idx])
		"sorry":
			sorry()
		"deliv_cancel":
			if S.delivery != null and S.delivery.state == "wait":
				GameState.ask("배달 주문을 거절할까요?\n(담아 둔 빵은 진열대로 돌아와요)", func() -> void:
					_fail_delivery("아, 다른 가게에 맡길게요."))


func _active_customers() -> Array:
	return S.customers.filter(func(c: Dictionary) -> bool: return c.state != "leaving")


func counter_customer():
	var a := _active_customers()
	return null if a.is_empty() else a[0]


## 손님·배달이 원할 수 있는 빵 (해금 + 3단계는 발효종이 있을 때만)
func _wantable() -> Array:
	var lv: bool = S.flags.get("levain", false)
	return D.unlocked_breads(_day()).filter(func(t: String) -> bool:
		return lv or not D.TIERS[D.tier_of(t)].get("levain", false))


func _pick_want() -> String:
	var pool := _wantable()
	var on_shelf := pool.filter(func(t: String) -> bool: return shelf_pick(t) >= 0)
	if not on_shelf.is_empty() and randf() < 0.75:
		return on_shelf.pick_random()
	return pool.pick_random()


func _spawn_customer() -> void:
	var p := randi() % D.PROFILES.size()
	while p == int(S.last_profile):
		p = randi() % D.PROFILES.size()
	S.last_profile = p
	var dmg := float(S.damage)
	var tier := 2 if dmg >= 60.0 or _day() >= 6 else (1 if dmg >= 30.0 or _day() >= 2 else 0)
	var pool: Array = D.FLAVOR[tier] if randf() < 0.6 else D.FLAVOR[maxi(0, tier - 1)]
	S.cid = int(S.cid) + 1
	S.customers.append({"id": S.cid, "p": p, "want": _pick_want(), "line": pool.pick_random(), "pat": 1.0,
		"maxT": D.patience(_day()), "state": "wait", "say": "", "say2": "", "lt": 0.0, "wrong": 0})
	Sound.sfx("door")


func _spawn_secret() -> void:
	var info: Dictionary = D.SECRET_LINES.get(_day(), D.SECRET_LINES[1])
	var line: String = info.line
	if _day() == 2 and float(S.damage) < 30.0:
		line = "아직은 괜찮군. 다행이야. …그래도 이걸 받아."
	S.cid = int(S.cid) + 1
	S.customers.append({"id": S.cid, "secret": true, "p": -1, "want": "cream", "pat": 1.0, "maxT": 30.0,
		"state": "wait", "say": "", "say2": "", "lt": 0.0, "line": line, "req": info.req, "wrong": 0})
	Sound.sfx("ding")


func _leave(c: Dictionary, say: String, secs: float = 1.6) -> void:
	c.state = "leaving"
	c.say = say
	c.lt = secs


func _secret_leave(c: Dictionary, served: bool) -> void:
	var d := _day()
	S.flags["secret%d" % d] = true
	match d:
		1:
			_leave(c, "…좋은 반죽이군. 아직은.", 2.4)
		2:
			S.flags.levain = true
			_leave(c, "이건 당신만의 발효종이야. 사장 것 말고." if served else "빵은 됐소. 이건 두고 가지.", 2.6)
			get_tree().create_timer(0.6).timeout.connect(func() -> void:
				GameState.toast("검은 외투의 손님이 작은 유리병을 두고 갔다… 「르방(발효종)」을 얻었다!"))
		7:
			_leave(c, "…잘 가. 어느 쪽으로든.", 2.6)
		_:
			_leave(c, "…곧 다시 보지." if served else "바쁘군. 그럼 이만.", 2.2)


## 진열대의 빵 종류를 탭: 카운터 손님 → 배달 주문 순으로 원하는 쪽에 건넨다.
## 아무도 원하지 않는 빵을 카운터 손님에게 주면 패널티.
func give_bread(type: String) -> void:
	var i := shelf_pick(type)
	if i < 0:
		return
	var c = counter_customer()
	var wants: bool = c != null and (c.get("secret", false) or c.want == type)
	if wants:
		_serve_customer(c, i)
		return
	if _delivery_needs(type):
		_give_delivery(i)
		return
	if c == null:
		GameState.toast("지금 %s을(를) 찾는 손님이 없어요" % D.BREADS[type].name)
		Sound.sfx("click")
		return
	_wrong_bread(c, type)


func _wrong_bread(c: Dictionary, type: String) -> void:
	c.wrong = int(c.get("wrong", 0)) + 1
	c.pat = float(c.pat) - D.WRONG_PAT
	GameState.add_stat("mood", -D.WRONG_MOOD)
	S.today.wrong = int(S.today.wrong) + 1
	Sound.sfx("bad")
	if int(c.wrong) >= D.WRONG_LIMIT or float(c.pat) <= 0.0:
		_leave(c, "이건 %s잖아요! 됐어요, 안 살래요." % D.BREADS[type].name, 2.0)
		S.today.missed = int(S.today.missed) + 1
		GameState.add_stat("mood", -2)
		return
	c.say2 = "어… 이건 %s인데요? 저는 %s요." % [D.BREADS[type].name, D.BREADS[c.want].name]
	GameState.toast("빵을 잘못 건넸어요! 손님 인내심 -%d%% · 기분 -%d" % [int(D.WRONG_PAT * 100), D.WRONG_MOOD])


func _serve_customer(c: Dictionary, i: int) -> void:
	var b: Dictionary = S.shelf[i]
	S.shelf.remove_at(i)
	var price := D.sale_price(b.type, b.g)
	var tip := 300 if float(S.mood) >= 70.0 else 0   # 기분이 좋으면 기본 팁
	var fast := {} if c.get("secret", false) else D.fast_tip(float(c.pat))
	var fast_amt := 0
	if not fast.is_empty():
		fast_amt = maxi(100, int(round(price * float(fast.rate) / 100.0)) * 100)
		tip += fast_amt
		S.today.fast_tips = int(S.today.get("fast_tips", 0)) + 1
		GameState.add_stat("mood", 1)
	_earn(price + tip)
	S.today.tips = int(S.today.tips) + tip
	S.today.sold = int(S.today.sold) + 1
	GameState.add_stat("stamina", -1)
	Sound.sfx("cash")
	if c.get("secret", false):
		_secret_leave(c, true)
		return
	var msg: String = D.THANKS.pick_random() if fast.is_empty() else str(fast.msg)
	if b.g == "S" and fast.is_empty():
		msg = "와, 이거 정말 맛있어 보여요!"
		GameState.add_stat("mood", 2)
	elif b.g == "F":
		msg = "…좀 이상하네요? 그래도 살게요."
	if tip > 0:
		_leave(c, "%s (+%s · 팁 %s)" % [msg, D.fmt_money(price), D.fmt_money(tip)])
	else:
		_leave(c, "%s (+%s)" % [msg, D.fmt_money(price)])
	if fast_amt > 0:
		GameState.toast("빨리 건네서 팁 +%s!" % D.fmt_money(fast_amt))


func _earn(n: int) -> void:
	S.money = int(S.money) + n
	S.total = int(S.total) + n
	S.today.revenue = int(S.today.revenue) + n


func sorry() -> void:
	var c = counter_customer()
	if c == null:
		return
	if c.get("secret", false):
		_secret_leave(c, false)
		return
	GameState.add_stat("mood", -1)
	S.today.missed = int(S.today.missed) + 1
	if not _sold_out_penalty(c):
		_leave(c, "아, 그럼 다음에 올게요.")
	Sound.sfx("click")


## 빵은 있었는데 늦게 줘서 손님이 기다리다 떠남: 일당에서 차감
func _late_penalty(c: Dictionary) -> void:
	var p := D.LATE_PENALTY
	S.money = int(S.money) - p
	S.today.late = int(S.today.get("late", 0)) + 1
	S.today.late_cost = int(S.today.get("late_cost", 0)) + p
	_leave(c, "%s (대기 초과 -%s)" % [D.SAD.pick_random(), D.fmt_money(float(p))])
	GameState.toast("손님이 기다리다 떠났어요! 일당에서 %s 차감" % D.fmt_money(float(p)))


## 손님이 찾는 빵이 진열대에 없어서 그냥 돌아가면 일당에서 일정 금액 차감. 차감했으면 true.
func _sold_out_penalty(c: Dictionary) -> bool:
	if c.get("secret", false) or shelf_pick(c.want) >= 0:
		return false
	var p := D.SOLD_OUT_PENALTY
	S.money = int(S.money) - p
	S.today.soldout = int(S.today.get("soldout", 0)) + 1
	S.today.soldout_cost = int(S.today.get("soldout_cost", 0)) + p
	_leave(c, "%s이(가) 없네요… (품절 -%s)" % [D.BREADS[c.want].name, D.fmt_money(float(p))])
	GameState.toast("%s 품절! 일당에서 %s 차감" % [D.BREADS[c.want].name, D.fmt_money(float(p))])
	return true


# ---------------------------------------------------------------- 배달

func _spawn_delivery() -> void:
	var n := 2 if _day() < 5 else randi_range(2, 3)
	var items := []
	for k in n:
		items.append({"type": _pick_want(), "got": null})
	S.delivery = {"items": items, "pat": 1.0, "maxT": D.DELIVERY_PAT, "rider": RIDERS.pick_random(),
		"state": "wait", "say": "", "lt": 0.0}
	S.deliv_left = int(S.deliv_left) - 1
	Sound.sfx("bell")
	GameState.toast("배달 주문이 들어왔어요! (수수료 %d%%)" % int(D.DELIVERY_FEE * 100))


func _delivery_needs(type: String) -> bool:
	if S.delivery == null or S.delivery.state != "wait":
		return false
	for it in S.delivery.items:
		if it.type == type and it.got == null:
			return true
	return false


func _give_delivery(i: int) -> void:
	var b: Dictionary = S.shelf[i]
	for it in S.delivery.items:
		if it.type == b.type and it.got == null:
			it.got = b
			break
	S.shelf.remove_at(i)
	Sound.sfx("click")
	var left: Array = S.delivery.items.filter(func(it: Dictionary) -> bool: return it.got == null)
	if left.is_empty():
		_complete_delivery()
	else:
		GameState.toast("배달 봉투에 %s을(를) 담았어요 (남은 빵 %d개)" % [D.BREADS[b.type].name, left.size()])


func _complete_delivery() -> void:
	var dv: Dictionary = S.delivery
	var gross := 0
	for it in dv.items:
		gross += D.sale_price(it.type, it.got.g)
	var fee := int(round(gross * D.DELIVERY_FEE / 100.0)) * 100
	var pay := gross - fee
	_earn(pay)
	S.today.sold = int(S.today.sold) + dv.items.size()
	S.today.deliv = int(S.today.deliv) + 1
	S.today.deliv_rev = int(S.today.deliv_rev) + pay
	S.today.deliv_fee = int(S.today.deliv_fee) + fee
	GameState.add_stat("stamina", -1)
	dv.state = "leaving"
	dv.say = "배달 출발! +%s (수수료 -%s)" % [D.fmt_money(float(pay)), D.fmt_money(float(fee))]
	dv.lt = 2.0
	S.deliv_timer = randf_range(14.0, 26.0)
	Sound.sfx("cash")


func _fail_delivery(say: String) -> void:
	var dv: Dictionary = S.delivery
	for it in dv.items:
		if it.got != null:
			S.shelf.append(it.got)
			it.got = null
	S.today.deliv_fail = int(S.today.deliv_fail) + 1
	GameState.add_stat("mood", -3)
	dv.state = "leaving"
	dv.say = say
	dv.lt = 2.0
	S.deliv_timer = randf_range(14.0, 26.0)
	Sound.sfx("bad")


func _update_delivery(dt: float) -> void:
	if S.delivery == null:
		return
	var dv: Dictionary = S.delivery
	if dv.state == "leaving":
		dv.lt = float(dv.lt) - dt
		if dv.lt <= 0.0:
			S.delivery = null
		return
	dv.pat = float(dv.pat) - dt / float(dv.maxT)
	if dv.pat <= 0.0:
		_fail_delivery("너무 늦어서 주문이 취소됐어요…")


static func _count(arr: Array) -> int:
	var n := 0
	for x in arr:
		if x != null:
			n += 1
	return n


func _unhandled_input(event: InputEvent) -> void:
	if not knead.visible or dialogue.active:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		knead.hit()
	elif event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		knead.key_rub(-1)
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		knead.key_rub(1)

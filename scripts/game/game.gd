extends Control
## 하루 진행 메인 씬 (주방 ↔ 빵집).
## 시간표: 05~08 빵 만들기 / 08~11 영업 / 11~13 쉬는 시간(스토리) / 13~15 빵 만들기 / 15~18 영업 → 정산
## 상태는 모두 GameState.s 에 있고, 이 스크립트는 규칙과 화면 연결을 담당한다.

const D = preload("res://scripts/systems/game_data.gd")
const UIUtil = preload("res://scripts/systems/ui_util.gd")
const KitchenView = preload("res://scripts/game/kitchen_view.gd")
const BakeryView = preload("res://scripts/game/bakery_view.gd")
const Hud = preload("res://scripts/game/hud.gd")
const KneadPanel = preload("res://scripts/game/knead_panel.gd")
const BreadPicker = preload("res://scripts/game/bread_picker.gd")
const DialogueBox = preload("res://scripts/dialogue/dialogue_box.gd")

const MOVE_LABELS := {"bake1": "빵집으로 나가기", "sale1": "주방으로 (쉬는 시간)", "bake2": "빵집으로 나가기", "sale2": "퇴근하기"}
const TIME_UP_MSG := {"bake1": "08:00 — 빵집 오픈 시간이에요!", "sale1": "11:00 — 오전 영업 끝! 쉬는 시간이에요.", "bake2": "15:00 — 오후 영업 시간이에요!", "sale2": "18:00 — 퇴근 시간이에요!"}

var S: Dictionary
var kitchen: KitchenView
var bakery: BakeryView
var hud: Hud
var knead: KneadPanel
var picker: BreadPicker
var dialogue: DialogueBox
var story_running := false

var _tip: Label
var _btn_speed: Button
var _btn_skip: Button
var _btn_move: Button
var _t := 0.0


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
	picker.hide()
	layer.add_child(picker)
	knead = KneadPanel.new()
	knead.finished.connect(_finish_knead)
	knead.hide()
	layer.add_child(knead)

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
	_tip = UIUtil.label("", 10, Color(1.0, 0.97, 0.92))
	_tip.position = Vector2(8, 9)
	bar.add_child(_tip)
	var box := HBoxContainer.new()
	box.position = Vector2(300, 4)
	box.size = Vector2(334, 26)
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 5)
	bar.add_child(box)
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
	_btn_move = UIUtil.button("이동", 11)
	_btn_move.focus_mode = Control.FOCUS_NONE
	_btn_move.pressed.connect(try_move)
	box.add_child(_btn_move)


func _phase() -> Dictionary:
	return D.PHASES[int(S.phase_idx)]


# ---------------------------------------------------------------- 루프

func _process(delta: float) -> void:
	_t += delta
	var blocked := GameState.busy or dialogue.active or GameState.overlay.modal_open()
	if not blocked:
		_update(delta)
		if knead.visible:
			knead.tick(delta)
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
	_btn_move.text = MOVE_LABELS[ph.id] if S.time_up else "%s (%s부터)" % [MOVE_LABELS[ph.id], end_t]
	_btn_move.modulate = Color(1, 1, 1).lerp(Color(1.3, 1.2, 0.9), 0.5 + 0.5 * sin(_t * 5.0)) if S.time_up else Color.WHITE
	if in_kitchen:
		_tip.text = "오픈 시간! 진행 중인 빵을 마무리하고 나가세요." if S.time_up else "반죽 → 발효 → 굽기 → 식히기 → 진열대  ·  진열대 %d/%d" % [S.shelf.size(), D.SHELF_MAX]
	else:
		_tip.text = "영업 종료! 남은 손님을 응대하고 이동하세요." if S.time_up else "손님이 원하는 빵을 진열대에서 클릭하세요  ·  오늘 판매 %d개" % int(S.today.sold)


func _update(dt: float) -> void:
	var ph := _phase()
	if ph.id != "break" and not S.time_up:
		S.minute = float(S.minute) + dt * int(S.speed) / D.SEC_PER_MIN
		if S.minute >= float(ph.end):
			S.minute = float(ph.end)
			S.time_up = true
			Sound.sfx("bell")
			GameState.toast(TIME_UP_MSG[ph.id])
	if S.location == "kitchen":
		_update_kitchen(dt)
	else:
		_update_bakery(dt, ph)


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
			S.spawn_timer = randf_range(5.0, 8.0) if int(S.day) >= 2 else randf_range(6.0, 10.0)
		if ph.id == "sale2" and not S.secret_done and float(S.minute) >= D.SECRET_MINUTE:
			S.secret_done = true
			_spawn_secret()
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
				_leave(c, D.SAD.pick_random())
				GameState.add_stat("mood", -3)
				S.today.missed = int(S.today.missed) + 1
				Sound.sfx("bad")
	S.customers = S.customers.filter(func(c: Dictionary) -> bool: return c.state != "leaving" or float(c.lt) > 0.0)
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
		var n := _count(S.proofer) + _count(S.oven)
		if n > 0:
			GameState.ask("발효실·오븐에 반죽 %d판이 남아 있어요.\n지금 나가면 버려집니다. 나갈까요?\n(식힘대의 빵은 크루가 진열대로 옮겨줘요)" % n, advance_phase)
			return
	else:
		var n := _active_customers().size()
		if n > 0:
			GameState.ask("아직 손님 %d명이 기다리고 있어요.\n그래도 이동할까요?" % n, advance_phase)
			return
	advance_phase()


func advance_phase() -> void:
	var ph := _phase()
	if str(ph.id).begins_with("bake"):
		S.today.lost = int(S.today.lost) + (_count(S.proofer) + _count(S.oven)) * D.BATCH
		for it in S.rack:
			if it != null:
				for k in D.BATCH:
					if S.shelf.size() < D.SHELF_MAX:
						S.shelf.append(_make_bread(it))
		S.proofer = [null, null]
		S.oven = [null, null]
		S.rack = [null, null, null, null]
	if str(ph.id).begins_with("sale"):
		S.today.missed = int(S.today.missed) + _active_customers().size()
		S.customers = []
	knead.hide()
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
	S.spawn_timer = 2.0
	S.speed = 1
	if np.id == "break":
		S.story = {"key": "break%d" % int(S.day), "idx": 0, "ret": null}


func _go_settle() -> void:
	S.today.discarded = S.shelf.size()
	S.shelf = []
	Sound.sfx("door")
	GameState.change_scene("settle", "퇴근", "%d일차 18:00" % int(S.day))


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
			Sound.sfx("good")
			if o.has("go"):
				S.story = {"key": o.go, "idx": 0, "ret": st}
	story_running = false


func _on_story_end(key: String) -> void:
	if key.begins_with("break"):
		advance_phase()


# ---------------------------------------------------------------- 주방

func _on_kitchen_hit(what: String, idx: int) -> void:
	if dialogue.active or GameState.busy:
		return
	match what:
		"knead":
			open_picker()
		"proof":
			click_proof(idx)
		"oven":
			click_oven(idx)
		"rack":
			click_rack(idx)
		"staff":
			var who := "boss" if idx == 0 else "crew"
			kitchen.say(who, D.STAFF_TALK[who].pick_random())
			Sound.sfx("click")


func open_picker() -> void:
	var ph := _phase()
	if not str(ph.id).begins_with("bake"):
		return
	if S.time_up:
		GameState.toast("영업 시간이에요! 진행 중인 빵만 마무리하세요.")
		Sound.sfx("bad")
		return
	if not S.proofer.has(null):
		GameState.toast("발효실이 꽉 찼어요! 발효된 반죽을 먼저 오븐에 넣으세요.")
		Sound.sfx("bad")
		return
	if float(S.stamina) < 6.0:
		GameState.toast("너무 지쳤어요… (체력 부족)")
		Sound.sfx("bad")
		return
	Sound.sfx("click")
	picker.show()


func _start_knead(type: String) -> void:
	GameState.add_stat("stamina", -6)
	GameState.add_stat("damage", 1)
	knead.start(type, float(S.stamina), float(S.damage))


func _finish_knead(type: String, score: float) -> void:
	var i: int = S.proofer.find(null)
	if i < 0:
		GameState.toast("발효실에 자리가 없어 반죽을 버렸어요…")
		S.today.lost = int(S.today.lost) + D.BATCH
		return
	S.proofer[i] = {"type": type, "k": score, "p": 0.0}
	GameState.toast("%s 반죽을 발효실에 넣었어요" % D.BREADS[type].name)


func click_proof(i: int) -> void:
	var it = S.proofer[i]
	if it == null:
		return
	var j: int = S.oven.find(null)
	if j < 0:
		GameState.toast("오븐이 꽉 찼어요! 오븐의 빵을 먼저 꺼내세요.")
		Sound.sfx("bad")
		return
	var ps := proof_score(float(it.p))
	S.oven[j] = {"type": it.type, "k": it.k, "ps": ps, "b": 0.0, "dinged": false, "warned": false}
	S.proofer[i] = null
	GameState.toast("발효 %s (%d) → 오븐으로!" % [KneadPanel.word(ps), int(ps)])
	Sound.sfx("good" if ps >= 70.0 else "click")


func click_oven(i: int) -> void:
	var it = S.oven[i]
	if it == null:
		return
	var j: int = S.rack.find(null)
	if j < 0:
		GameState.toast("식힘대가 꽉 찼어요! 다 식은 빵을 진열대로 옮기세요.")
		Sound.sfx("bad")
		return
	var bs := bake_score(float(it.b))
	var q := int(round((float(it.k) + float(it.ps) + bs) / 3.0))
	S.rack[j] = {"type": it.type, "q": q, "c": 0.0}
	S.oven[i] = null
	GameState.add_stat("damage", 6 if float(it.b) > 1.25 else 3)   # 오븐 열기
	S.today.made = int(S.today.made) + D.BATCH
	var g: String = D.grade_of(q).g
	GameState.toast("굽기 %s (%d) → 빵 완성! 등급 %s" % [KneadPanel.word(bs), int(bs), g])
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
		GameState.toast("아직 뜨거워요! 김이 다 빠질 때까지 기다리세요.")
		Sound.sfx("bad")
		return
	if S.shelf.size() + D.BATCH > D.SHELF_MAX:
		GameState.toast("진열대가 꽉 찼어요!")
		Sound.sfx("bad")
		return
	for k in D.BATCH:
		S.shelf.append(_make_bread(it))
	S.rack[i] = null
	GameState.toast("%s %d개를 진열대로 옮겼어요" % [D.BREADS[it.type].name, D.BATCH])
	Sound.sfx("cash")


static func proof_score(p: float) -> float:
	return clampf(100.0 - absf(p - 0.85) * 220.0, 0.0, 100.0)


static func bake_score(b: float) -> float:
	return clampf(100.0 - absf(b - 0.95) * 250.0, 0.0, 100.0)


func _make_bread(it: Dictionary) -> Dictionary:
	return {"type": it.type, "q": it.q, "g": D.grade_of(float(it.q)).g}


# ---------------------------------------------------------------- 빵집 / 손님

func _on_bakery_hit(what: String, idx: int) -> void:
	if dialogue.active or GameState.busy:
		return
	if what == "give":
		give_bread(idx)
	elif what == "sorry":
		sorry()


func _active_customers() -> Array:
	return S.customers.filter(func(c: Dictionary) -> bool: return c.state != "leaving")


func counter_customer():
	var a := _active_customers()
	return null if a.is_empty() else a[0]


func _spawn_customer() -> void:
	var p := randi() % D.PROFILES.size()
	while p == int(S.last_profile):
		p = randi() % D.PROFILES.size()
	S.last_profile = p
	var want: String = D.BREAD_ORDER.pick_random()
	if not S.shelf.is_empty() and randf() < 0.75:
		want = S.shelf.pick_random().type
	var dmg := float(S.damage)
	var tier := 2 if dmg >= 60.0 else (1 if dmg >= 30.0 or int(S.day) >= 2 else 0)
	var pool: Array = D.FLAVOR[tier] if randf() < 0.6 else D.FLAVOR[maxi(0, tier - 1)]
	S.cid = int(S.cid) + 1
	S.customers.append({"id": S.cid, "p": p, "want": want, "line": pool.pick_random(), "pat": 1.0, "maxT": 20.0,
		"state": "wait", "say": "", "say2": "", "lt": 0.0})
	Sound.sfx("door")


func _spawn_secret() -> void:
	var d2 := int(S.day) >= 2
	var line := "……"
	if d2:
		line = "또 보는군. 어제보다 손이 더 말랑해졌어." if float(S.damage) >= 30.0 else "아직은 괜찮군. 다행이야."
	S.cid = int(S.cid) + 1
	S.customers.append({"id": S.cid, "secret": true, "p": -1, "want": "toast", "pat": 1.0, "maxT": 30.0,
		"state": "wait", "say": "", "say2": "", "lt": 0.0, "line": line,
		"req": "오늘도 아무 빵이나. 당신이 만든 걸로." if d2 else "아무 빵이나 하나. 당신이 만든 걸로."})
	Sound.sfx("ding")


func _leave(c: Dictionary, say: String, secs: float = 1.6) -> void:
	c.state = "leaving"
	c.say = say
	c.lt = secs


func _secret_leave(c: Dictionary, served: bool) -> void:
	if int(S.day) >= 2:
		S.flags.secret2 = true
		_leave(c, "…곧 다시 보지." if served else "빵은 됐소. 이건 두고 가지.", 2.4)
		get_tree().create_timer(0.6).timeout.connect(func() -> void:
			GameState.toast("검은 외투의 손님이 카운터에 카드를 두고 갔다…"))
	else:
		S.flags.secret1 = true
		_leave(c, "…좋은 반죽이군. 아직은.", 2.4)


func give_bread(i: int) -> void:
	if i >= S.shelf.size():
		return
	var c = counter_customer()
	if c == null:
		GameState.toast("카운터에 손님이 없어요")
		return
	var b: Dictionary = S.shelf[i]
	if not c.get("secret", false) and b.type != c.want:
		c.pat = float(c.pat) - 0.2
		c.say2 = "어… 제가 찾는 건 %s인데요." % D.BREADS[c.want].name
		Sound.sfx("bad")
		return
	S.shelf.remove_at(i)
	var gi := D.grade_info(b.g)
	var price := int(round(D.BREADS[b.type].price * float(gi.m) / 100.0)) * 100
	var tip := 300 if float(S.mood) >= 70.0 else 0
	S.money = int(S.money) + price + tip
	S.total = int(S.total) + price + tip
	S.today.revenue = int(S.today.revenue) + price + tip
	S.today.tips = int(S.today.tips) + tip
	S.today.sold = int(S.today.sold) + 1
	GameState.add_stat("stamina", -1)
	Sound.sfx("cash")
	if c.get("secret", false):
		_secret_leave(c, true)
		return
	var msg: String = D.THANKS.pick_random()
	if b.g == "S":
		msg = "와, 이거 정말 맛있어 보여요!"
		GameState.add_stat("mood", 2)
	elif b.g == "F":
		msg = "…좀 탔네요? 그래도 살게요."
	_leave(c, "%s (+%s)" % [msg, D.fmt_money(price + tip)])


func sorry() -> void:
	var c = counter_customer()
	if c == null:
		return
	if c.get("secret", false):
		_secret_leave(c, false)
		return
	GameState.add_stat("mood", -1)
	S.today.missed = int(S.today.missed) + 1
	_leave(c, "아, 그럼 다음에 올게요.")
	Sound.sfx("click")


static func _count(arr: Array) -> int:
	var n := 0
	for x in arr:
		if x != null:
			n += 1
	return n


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and knead.visible and not dialogue.active:
		get_viewport().set_input_as_handled()
		knead.hit()

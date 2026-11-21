extends SceneTree
## 자동 스모크 테스트: 타이틀 → 1일차 … 7일차 → 엔딩까지 자동으로 플레이.
## 도중에 저장 → 불러오기, 공정 생략(F 등급), 빵 잘못 주기, 빵 먹기, 배달, 성형·2차 발효를 모두 한 번 이상 거친다.
## 실행: godot --headless --fixed-fps 60 --path . -s res://tests/smoke_test.gd [-- 선택지번호]
##   선택지번호 0(기본) = 첫 번째 선택지만 고름 → '나만의 빵' 엔딩 경로, 1 = 두 번째 선택지 → '명부' 엔딩 경로

var frame := 0
var started := false
var save_tested := false
var log_phase := -1
var choice := 0
var stats := {"tier": {1: 0, 2: 0, 3: 0}, "skipF": 0, "wrong": 0, "eaten": 0, "deliv": 0, "shaped": 0, "proof2": 0, "rub": 0}
var did_wrong := false
var did_skip := false
var did_hot := false
var kneads := {}   # 날짜별 반죽 횟수 (선택지 0 경로는 하루 11판까지만 = 적당히 일하기)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		choice = int(args[0])
	change_scene_to_file("res://scenes/main/title.tscn")


func _fail(msg: String) -> void:
	print("SMOKE FAIL: ", msg)
	quit(1)


func _process(_delta: float) -> bool:
	frame += 1
	if frame > 400000:
		_fail("timeout, scene=%s" % (current_scene.name if current_scene else "null"))
		return false
	var scene := current_scene
	var gs := root.get_node("GameState")
	if scene == null or gs.busy:
		return false
	match scene.name:
		"Title":
			if frame > 20 and not started:
				started = true
				print("SMOKE: title ok -> new game")
				scene.call("_start")
		"Game":
			_drive_game(scene, gs)
		"DayEnd":
			if frame % 30 == 0:
				if gs.screen == "settle":
					var t: Dictionary = gs.s.today
					stats.wrong += int(t.wrong)
					stats.eaten += int(t.eaten)
					stats.deliv += int(t.deliv)
					if int(stats.skipF) == 0:
						did_skip = false   # 생략한 반죽이 시간대 끝에 버려졌으면 다음 날 다시 시도
					print("SMOKE: day %d settle %s stamina=%d damage=%d" % [int(gs.s.day), JSON.stringify(t), int(gs.s.stamina), int(gs.s.damage)])
					if int(gs.s.day) == 2 and not gs.s.flags.get("levain", false):
						_fail("day 2 ended without levain")
						return false
					scene.call("_go_home")
				elif gs.s.night == "":
					# 선택지 0 경로는 반죽 손상을 관리하는 플레이(스파·푹 자기), 1 경로는 유튜브만 보는 플레이
					var pick := "youtube"
					if choice == 0:
						pick = "spa" if int(gs.s.money) >= 100000 else ("youtube" if float(gs.s.mood) < 45.0 else "sleep")
					scene.call("_take_reward", pick)
				else:
					gs.next_day()
		"Ending":
			if frame % 30 == 0:
				_finish(gs)
	return false


func _finish(gs: Node) -> void:
	var s: Dictionary = gs.s
	var ending: String = load("res://scripts/main/ending.gd").pick_ending(s)
	print("SMOKE: stats ", JSON.stringify(stats))
	var problems := []
	if int(s.day) != 7:
		problems.append("ended on day %d" % int(s.day))
	for t in [1, 2, 3]:
		if int(stats.tier[t]) == 0:
			problems.append("no tier %d bread baked" % t)
	for k in ["skipF", "wrong", "eaten", "deliv", "shaped", "proof2", "rub"]:
		if int(stats[k]) == 0:
			problems.append("never exercised: " + k)
	if choice == 0 and ending != "own":
		problems.append("choice 0 route expected 'own' ending, got " + ending)
	if choice == 1 and ending != "stay":
		problems.append("choice 1 route expected 'stay' ending, got " + ending)
	if not problems.is_empty():
		_fail(", ".join(problems))
		return
	print("SMOKE OK: ending=%s day=%d money=%d total=%d stamina=%d damage=%d peaks=%s flags=%s" % [
		ending, int(s.day), int(s.money), int(s.total), int(s.stamina), int(s.damage), JSON.stringify(s.peaks), JSON.stringify(s.flags)])
	quit(0)


func _drive_game(g: Node, gs: Node) -> void:
	var s: Dictionary = gs.s
	if g.dialogue.active:
		if frame % 6 == 0:
			g.dialogue.debug_skip(choice)
		return
	if gs.overlay.modal_open():
		# 테스트는 확인 창을 직접 누른다 (덜 식은 빵 진열 확인 등)
		if gs.overlay.confirm_box.visible and frame % 10 == 0:
			gs.overlay._on_confirm_yes()
		return
	var ph: Dictionary = g.D.PHASES[int(s.phase_idx)]
	if int(s.phase_idx) != log_phase:
		log_phase = int(s.phase_idx)
		print("SMOKE: day %d phase %s loc %s stamina=%d money=%d" % [int(s.day), ph.id, s.location, int(s.stamina), int(s.money)])
	s.speed = 3

	# 1일차 오전 영업 시작 시 저장 → 불러오기 확인
	if ph.id == "sale1" and int(s.day) == 1 and not save_tested and frame % 10 == 0:
		save_tested = true
		var ok: bool = gs.save_game()
		print("SMOKE: save ", ok)
		gs.load_game()
		return

	if g.knead.visible:
		if frame % 10 == 0:
			if g.knead.mode == "rub":
				stats.rub += 1
				g.knead.rub(g.knead.need * 0.5)
			else:
				g.knead.pos = g.knead.zc
				g.knead.hit()
		return
	if g.shaper.visible:
		if frame % 10 == 0 and not g.shaper.done:
			g.shaper.debug_trace_all()
			stats.shaped += 1
		return

	# 체력이 떨어지면 빵 먹기
	if float(s.stamina) < 25.0 and frame % 15 == 0:
		var opts: Array = g.eat_options()
		g.eat(opts[0])

	if str(ph.id).begins_with("bake"):
		_drive_kitchen(g, s)
	elif str(ph.id).begins_with("sale") and frame % 20 == 0:
		_drive_bakery(g, s)
	if s.time_up and frame % 20 == 0 and not g.knead.visible and not g.shaper.visible:
		g.advance_phase()


func _drive_kitchen(g: Node, s: Dictionary) -> void:
	var P = g.P
	for i in s.proofer.size():
		var p = s.proofer[i]
		if p == null or float(p.p) < 0.85:
			continue
		if p.stage == "proof2":
			stats.proof2 += 1
			g.click_proof(i)
		elif P.needs(p.type, "shape"):
			if not did_skip and int(s.day) >= 3 and not s.time_up:
				did_skip = true
				g._proof_to_oven(i, P.proof_score(float(p.p)), true)   # 공정 생략 → F
			else:
				g._proof_to_shaper(i, P.proof_score(float(p.p)))
		else:
			g.click_proof(i)
	for i in s.shaper.size():
		var it = s.shaper[i]
		if it == null:
			continue
		if not it.get("shaped", false):
			g.click_shape(i)
			return
		if P.needs(it.type, "proof2"):
			g._shaper_to_proof(i)
		else:
			g.click_shape(i)
	for i in s.oven.size():
		var o = s.oven[i]
		if o != null and float(o.b) >= 0.95:
			var t: String = o.type
			var skipped: bool = o.get("skip", false)
			g.click_oven(i)
			if s.oven[i] != null:
				continue
			stats.tier[g.D.tier_of(t)] += 1
			if skipped:
				for r in s.rack:
					if r != null and r.type == t and int(r.q) <= g.D.SKIP_Q:
						stats.skipF += 1
						break
	for i in s.rack.size():
		var r = s.rack[i]
		if r == null:
			continue
		if float(r.c) >= 1.0:
			g.click_rack(i)
		elif not did_hot and int(s.day) == 1 and float(r.c) > 0.3:
			did_hot = true
			g.click_rack(i)   # 확인 창 → 덜 식은 채로 진열(F)
			return
	if s.time_up:
		return
	var dk := int(kneads.get(int(s.day), 0))
	if choice == 0 and dk >= 11:
		return
	if s.proofer.has(null) and frame % 30 == 0:
		kneads[int(s.day)] = dk + 1
		g.open_picker()
		if g.picker.visible:
			g.picker.hide()
			var pool: Array = []
			for t in g.D.unlocked_breads(int(s.day)):
				if g.picker.lock_reason(t) == "":
					pool.append(t)
			# 높은 단계 빵을 더 자주 만든다
			var top: Array = pool.filter(func(t: String) -> bool: return g.D.tier_of(t) == g.D.max_tier(int(s.day)))
			g._start_knead((top if randf() < 0.6 else pool).pick_random())


func _drive_bakery(g: Node, s: Dictionary) -> void:
	var c = g.counter_customer()
	# 배달 주문 우선 처리
	if s.delivery != null and s.delivery.state == "wait":
		for it in s.delivery.items:
			if it.got == null and g.shelf_pick(it.type) >= 0 and (c == null or c.get("secret", false) or c.want != it.type):
				g.give_bread(it.type)
				return
	if c == null:
		return
	if c.get("secret", false):
		if not s.shelf.is_empty():
			g.give_bread(s.shelf[0].type)
		else:
			g.sorry()
		return
	# 한 번은 일부러 다른 빵을 건네 패널티 확인
	if not did_wrong:
		for b in s.shelf:
			if b.type != c.want and not g._delivery_needs(b.type):
				did_wrong = true
				var before := int(s.today.wrong)
				g.give_bread(b.type)
				if int(s.today.wrong) != before + 1:
					_fail("wrong bread penalty not applied")
				return
	if g.shelf_pick(c.want) >= 0:
		g.give_bread(c.want)
	else:
		g.sorry()

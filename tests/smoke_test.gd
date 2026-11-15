extends SceneTree
## 자동 스모크 테스트: 타이틀 → 1일차 → 정산 → 집 → 2일차 → 엔딩까지 자동으로 플레이.
## 도중에 저장 → 불러오기도 한 번 확인한다.
## 실행: godot --headless --fixed-fps 60 --path . -s res://tests/smoke_test.gd

var frame := 0
var started := false
var save_tested := false
var log_phase := -1


func _initialize() -> void:
	change_scene_to_file("res://scenes/main/title.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if frame > 120000:
		print("SMOKE FAIL: timeout, scene=", current_scene.name if current_scene else "null")
		quit(1)
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
					print("SMOKE: day %d settle %s" % [int(gs.s.day), JSON.stringify(gs.s.today)])
					scene.call("_go_home")
				elif gs.s.night == "":
					scene.call("_take_reward", "sleep" if int(gs.s.day) == 1 else "youtube")
				else:
					gs.next_day()
		"Ending":
			if frame % 30 == 0:
				var s: Dictionary = gs.s
				print("SMOKE OK: ending reached. day=%d money=%d total=%d stamina=%d damage=%d flags=%s" % [
					int(s.day), int(s.money), int(s.total), int(s.stamina), int(s.damage), JSON.stringify(s.flags)])
				quit(0)
	return false


func _drive_game(g: Node, gs: Node) -> void:
	var s: Dictionary = gs.s
	if g.dialogue.active:
		if frame % 6 == 0:
			g.dialogue.debug_skip(frame % 2)
		return
	if gs.overlay.modal_open():
		return
	var ph: Dictionary = g.D.PHASES[int(s.phase_idx)]
	if int(s.phase_idx) != log_phase:
		log_phase = int(s.phase_idx)
		print("SMOKE: day %d phase %s loc %s" % [int(s.day), ph.id, s.location])
	s.speed = 3

	# 1일차 오전 영업 시작 시 저장 → 불러오기 확인
	if ph.id == "sale1" and int(s.day) == 1 and not save_tested and frame % 10 == 0:
		save_tested = true
		var ok: bool = gs.save_game()
		print("SMOKE: save ", ok)
		gs.load_game()
		return

	if s.time_up:
		if not g.knead.visible and not g.picker.visible and frame % 20 == 0:
			g.advance_phase()
		if g.knead.visible and frame % 10 == 0:
			g.knead.pos = g.knead.zc
			g.knead.hit()
		return

	if str(ph.id).begins_with("bake"):
		if g.knead.visible:
			if frame % 10 == 0:
				g.knead.pos = g.knead.zc
				g.knead.hit()
			return
		for i in 2:
			var p = s.proofer[i]
			if p != null and float(p.p) >= 0.85:
				g.click_proof(i)
			var o = s.oven[i]
			if o != null and float(o.b) >= 0.95:
				g.click_oven(i)
		for i in 4:
			var r = s.rack[i]
			if r != null and float(r.c) >= 1.0:
				g.click_rack(i)
		if s.proofer.has(null) and frame % 30 == 0:
			g.open_picker()
			if g.picker.visible:
				g.picker.hide()
				g._start_knead(["toast", "croissant", "baguette", "bagel"][frame % 4])
	elif str(ph.id).begins_with("sale") and frame % 20 == 0:
		var c = g.counter_customer()
		if c == null:
			return
		var idx := -1
		for i in s.shelf.size():
			if c.get("secret", false) or s.shelf[i].type == c.want:
				idx = i
				break
		if idx >= 0:
			g.give_bread(idx)
		else:
			g.sorry()

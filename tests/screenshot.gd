extends SceneTree
## 화면 캡처 도구 (창 모드로 실행): 주요 화면을 PNG 로 저장한다.
## 실행: godot --path . --fixed-fps 60 -s res://tests/screenshot.gd -- <저장폴더>

var frame := 0
var out := "user://shots"
var step := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main/title.tscn")


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


func _wait(n: int) -> bool:
	return frame > n


func _next() -> void:
	step += 1
	frame = 0


func _process(_d: float) -> bool:
	frame += 1
	var gs := root.get_node("GameState")
	if gs.busy:
		return false
	var sc := current_scene
	match step:
		0:
			if _wait(30):
				_shot("01_title")
				gs.start_new_game()
				_next()
		1:
			if sc and sc.name == "Game":
				if sc.dialogue.active and frame % 6 == 0:
					sc.dialogue.debug_skip(0)
				elif not sc.dialogue.active and _wait(40):
					_next()
		2:
			var s: Dictionary = gs.s
			s.day = 5
			s.flags.levain = true
			s.damage = 35.0
			var P = sc.P
			var a = P.new_item("cream", 90)
			a.p = 0.8
			var b = P.new_item("sausage", 80)
			b.p = 1.3
			var c = P.new_item("baguette", 85)
			c.ps = 90
			c.ss = 80
			c.stage = "proof2"
			c.shaped = true
			c.p = 0.5
			s.proofer = [a, b, c, null]
			var d = P.new_item("croquette", 85)
			d.ps = 80
			var e = P.new_item("ciabatta", 85)
			e.ps = 80
			e.ss = 70
			e.shaped = true
			s.shaper = [d, e]
			var o1 = P.new_item("wholewheat", 90)
			o1.merge({"ps": 90, "ss": 90, "ps2": 90, "b": 0.95, "dinged": true, "warned": false}, true)
			var o2 = P.new_item("sandwich", 90)
			o2.merge({"ps": 90, "skip": true, "b": 1.3, "dinged": true, "warned": true}, true)
			s.oven = [o1, o2, null]
			s.rack = [{"type": "soboro", "q": 95, "c": 1.0}, {"type": "choco", "q": 70, "c": 0.4}, null, {"type": "redbean", "q": 15, "c": 1.0}]
			sc.kitchen.say("crew", "…적당히 해.")
			_next()
		3:
			if _wait(20):
				_shot("02_kitchen")
				sc._start_knead("redbean")
				_next()
		4:
			if _wait(40):
				sc.knead.rub(sc.knead.need * 0.45, 40.0)
				_next()
		5:
			if _wait(5):
				_shot("03_knead_rub")
				sc.knead.hide()
				sc.shaper.start(0, "sausage", 80.0, 35.0)
				_next()
		6:
			if _wait(10):
				# 점선 절반만 따라 그린 상태
				var g: Array = sc.shaper.guide
				for i in range(0, g.size() / 2):
					sc.shaper.trace(g[i])
				_next()
		7:
			if _wait(5):
				_shot("04_shape")
				sc.shaper.hide()
				gs.s.proofer[0] = null
				gs.s.proofer[1] = null
				sc.open_picker()
				_next()
		8:
			if _wait(10):
				_shot("05_picker")
				sc.picker.hide()
				var b = sc.P.new_item("sausage", 80)
				b.p = 0.85
				gs.s.proofer[1] = b
				sc.click_proof(1)
				_next()
		9:
			if _wait(10):
				_shot("06_skip_choice")
				gs.overlay._close_choice(-1)
				var s: Dictionary = gs.s
				s.phase_idx = 1
				s.location = "bakery"
				s.minute = 500.0
				s.shelf = []
				for t in [["cream", 95], ["cream", 60], ["cream", 80], ["redbean", 80], ["choco", 50], ["sausage", 90], ["sausage", 70], ["sandwich", 40], ["baguette", 92], ["wholewheat", 75], ["wholewheat", 20]]:
					s.shelf.append({"type": t[0], "q": t[1], "g": sc.D.grade_of(t[1]).g})
				s.deliv_left = 1
				sc._spawn_delivery()
				s.delivery.items[0].got = {"type": s.delivery.items[0].type, "q": 80, "g": "A"}
				for i in 3:
					sc._spawn_customer()
				var cust: Dictionary = s.customers[0]
				cust.want = "baguette"
				sc.give_bread("cream" if not sc._delivery_needs("cream") else "redbean")
				_next()
		10:
			if _wait(20):
				_shot("07_bakery")
				sc.open_eat()
				_next()
		11:
			if _wait(10):
				_shot("08_eat")
				gs.overlay._close_choice(-1)
				gs.s.customers = []
				gs.s.delivery = null
				sc._spawn_secret()
				_next()
		12:
			if _wait(20):
				_shot("09_secret")
				gs.overlay.open_settings()
				_next()
		13:
			if _wait(10):
				_shot("10_settings")
				gs.overlay.close_settings()
				gs.s.customers = []
				var t: Dictionary = gs.s.today
				t.merge({"made": 28, "sold": 21, "missed": 3, "wrong": 2, "lost": 2, "deliv": 3, "deliv_fail": 1, "deliv_rev": 18200, "deliv_fee": 7800, "tips": 1200, "revenue": 96400, "eaten": 3, "eat_cost": 9800, "soldout": 4, "soldout_cost": 8000, "fast_tips": 12}, true)
				gs.s.phase_idx = 4
				gs.change_scene("settle", "퇴근", "")
				_next()
		14:
			if sc and sc.name == "DayEnd" and _wait(20):
				_shot("11_settle")
				sc.call("_go_home")
				_next()
		15:
			if _wait(30):
				_shot("12_home")
				gs.s.day = 7
				gs.s.flags.merge({"escape": true, "kept_levain": true, "fed_levain": true, "promise": true}, true)
				gs.s.peaks = [20, 25, 30, 35, 40, 38, 30]
				gs.change_scene("ending", "…", "")
				_next()
		16:
			if sc and sc.name == "Ending" and _wait(20):
				_shot("13_ending_own")
				gs.s.flags.erase("escape")
				gs.change_scene("ending", "…", "")
				_next()
		17:
			if sc and sc.name == "Ending" and _wait(20):
				_shot("14_ending_stay")
				quit(0)
	return false

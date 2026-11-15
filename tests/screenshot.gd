extends SceneTree
## 화면 캡처 도구 (창 모드로 실행): 주요 화면을 PNG 로 저장한다.
## 실행: godot --path . -s res://tests/screenshot.gd -- <저장폴더>

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


func _process(_d: float) -> bool:
	frame += 1
	var gs := root.get_node("GameState")
	if gs.busy:
		return false
	var sc := current_scene
	match step:
		0:
			if frame > 30:
				_shot("01_title")
				gs.start_new_game()
				step = 1
		1:
			if sc and sc.name == "Game":
				if sc.dialogue.active and frame > 40 and frame % 6 == 0:
					if frame < 1000:
						_shot("02_dialogue")
						frame = 1000
					sc.dialogue.debug_skip(0)
				elif not sc.dialogue.active and frame > 1000:
					step = 2
		2:
			var s: Dictionary = gs.s
			s.proofer[0] = {"type": "croissant", "k": 90, "p": 0.8}
			s.proofer[1] = {"type": "toast", "k": 80, "p": 1.3}
			s.oven[0] = {"type": "baguette", "k": 90, "ps": 90, "b": 0.95, "dinged": true, "warned": false}
			s.oven[1] = {"type": "bagel", "k": 90, "ps": 90, "b": 1.3, "dinged": true, "warned": true}
			s.rack[0] = {"type": "toast", "q": 95, "c": 1.0}
			s.rack[1] = {"type": "croissant", "q": 70, "c": 0.4}
			s.damage = 45.0
			sc.kitchen.say("crew", "…적당히 해.")
			step = 3
			frame = 0
		3:
			if frame > 20:
				_shot("03_kitchen")
				sc._start_knead("croissant")
				step = 4
				frame = 0
		4:
			if frame > 25:
				sc.knead.pos = sc.knead.zc
				sc.knead.hit()
				_shot("04_knead")
				sc.knead.hide()
				sc.open_picker()
				step = 5
				frame = 0
		5:
			if frame > 10:
				_shot("05_picker")
				sc.picker.hide()
				var s: Dictionary = gs.s
				s.phase_idx = 1
				s.location = "bakery"
				s.minute = 500.0
				s.shelf = [{"type": "toast", "q": 95, "g": "S"}, {"type": "bagel", "q": 60, "g": "B"}, {"type": "croissant", "q": 80, "g": "A"}, {"type": "baguette", "q": 20, "g": "F"}, {"type": "toast", "q": 80, "g": "A"}]
				for i in 3:
					sc._spawn_customer()
				step = 6
				frame = 0
		6:
			if frame > 20:
				_shot("06_bakery")
				gs.s.customers = []
				sc._spawn_secret()
				sc._spawn_customer()
				step = 7
				frame = 0
		7:
			if frame > 20:
				_shot("07_secret")
				gs.overlay.open_settings()
				step = 8
				frame = 0
		8:
			if frame > 10:
				_shot("08_settings")
				gs.overlay.close_settings()
				gs.s.customers = []
				gs.s.phase_idx = 4
				gs.change_scene("settle", "퇴근", "")
				step = 9
				frame = 0
		9:
			if sc and sc.name == "DayEnd" and frame > 20:
				_shot("09_settle")
				sc.call("_go_home")
				step = 10
				frame = 0
		10:
			if frame > 20:
				_shot("10_home")
				gs.s.flags["secret2"] = true
				gs.s.day = 2
				gs.change_scene("ending", "…", "")
				step = 11
				frame = 0
		11:
			if sc and sc.name == "Ending" and frame > 20:
				_shot("11_ending")
				quit(0)
	return false

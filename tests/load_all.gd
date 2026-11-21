extends SceneTree
## 모든 스크립트를 불러와 문법·컴파일 오류가 없는지 확인한다.
## 실행: godot --headless --path . -s res://tests/load_all.gd

func _initialize() -> void:
	var bad := 0
	var files := _scan("res://scripts")
	for f in files:
		var sc = load(f)
		if sc == null or not (sc is GDScript) or not sc.can_instantiate():
			print("LOAD FAIL: ", f)
			bad += 1
	print("LOAD %s: %d scripts" % ["OK" if bad == 0 else "FAIL", files.size()])
	quit(1 if bad > 0 else 0)


func _scan(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scan(dir.path_join(d)))
	return out

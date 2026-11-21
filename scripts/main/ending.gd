extends Control
## 7일차 밤 엔딩. 7일 동안의 반죽 손상 평균과 이야기 선택(플래그)으로 갈래가 나뉜다.
## - 명부의 마지막 줄 : 명부에 이름을 올렸다 (stay / 6일차 sign 후 도망치지 않음)
## - 나만의 빵       : 르방을 들고 나감 + 손상 평균이 낮고 르방을 지켰거나 키움 + 기분 평균 40 이상
## - 반쯤 남은 손     : 르방을 들고 나갔지만 너무 많이 내어줬다 (손상 평균 55 이상)
## - 문 밖의 새벽     : 르방을 들고 나갔지만 르방을 돌보지 않았거나, 마음이 지쳐 버렸다 (기분 평균 40 미만)

const D = preload("res://scripts/systems/game_data.gd")
const UIUtil = preload("res://scripts/systems/ui_util.gd")
const BreadCharacter = preload("res://scripts/characters/bread_character.gd")

const ENDINGS := {
	"stay": {"title": "엔딩 · 명부의 마지막 줄", "dark": true,
		"text": "문이 잠기는 소리가 났다. 펜 끝이 종이에 닿는 순간, 손끝부터 천천히 따뜻해졌다.\n다음 날 아침, 진열대 맨 윗단에 처음 보는 빵이 하나 놓여 있었다. 말랑하고, 아주 맛있어 보이는.\n사장님이 웃으며 새 공고를 붙인다. 「성실한 제빵사 구함」."},
	"own": {"title": "엔딩 · 나만의 빵", "dark": false,
		"text": "문이 잠기기 직전, 르방 병을 품에 안고 새벽 거리로 뛰어나왔다.\n몇 달 뒤, 골목 끝 작은 가게에 불이 켜진다. 간판도 없는 빵집. 처음부터 내가 키운 발효종으로 구운 빵.\n손끝은 조금 말랑하지만, 이 손으로 만든 빵은 누구의 것도 아닌 내 빵이다."},
	"half": {"title": "엔딩 · 반쯤 남은 손", "dark": true,
		"text": "르방을 들고 문을 나섰다. 하지만 문고리를 쥔 손이 끝내 문에서 떨어지지 않았다.\n손가락 몇 마디를 가게에 두고 나왔다. 그것들은 이제 진열대 어딘가에서 누군가에게 팔리고 있겠지.\n남은 손으로도 빵은 구울 수 있다. 다만 반죽을 만질 때마다, 반죽 쪽이 나를 먼저 알아본다."},
	"out": {"title": "엔딩 · 문 밖의 새벽", "dark": false,
		"text": "도망쳐 나왔지만, 마음도 주머니 속 르방도 조용했다. 아무도 돌보지 않은 발효종은 천천히 잠들어 버렸다.\n나는 다시는 빵집에서 일하지 않는다. 가끔 새벽 5시에 눈이 떠지면, 손끝이 오븐의 온기를 그리워한다.\n…그래도, 아직은 나다."},
}


var _t := 0.0
var _dark := true


static func avg_damage(S: Dictionary) -> float:
	var peaks: Array = S.get("peaks", [])
	if peaks.is_empty():
		return float(S.get("damage", 0.0))
	var sum := 0.0
	for p in peaks:
		sum += float(p)
	return sum / peaks.size()


static func avg_mood(S: Dictionary) -> float:
	var moods: Array = S.get("moods", [])
	if moods.is_empty():
		return float(S.get("mood", 60.0))
	var sum := 0.0
	for m in moods:
		sum += float(m)
	return sum / moods.size()


static func pick_ending(S: Dictionary) -> String:
	var f: Dictionary = S.get("flags", {})
	var escape: bool = f.get("escape", false)
	if not escape:
		return "stay"
	var avg := avg_damage(S)
	if avg >= 55.0 or (f.get("boss_starter", false) and f.get("sign", false)):
		return "half"
	# 나만의 빵: 르방을 지켰거나 키웠고, 7일 동안 기분도 너무 가라앉지 않았을 때
	if (f.get("kept_levain", false) or f.get("fed_levain", false)) and avg_mood(S) >= D.MOOD_ENDING:
		return "own"
	return "out"


func _ready() -> void:
	var S: Dictionary = GameState.s
	Sound.bgm("ending")
	var key := pick_ending(S)
	var e: Dictionary = ENDINGS[key]
	_dark = e.dark
	S.flags["ending_" + key] = true

	var hero := BreadCharacter.new()
	hero.kind = "banjuk"
	hero.damage = 100.0 if key == "stay" else avg_damage(S)
	hero.position = Vector2(320, 70)
	hero.scale = Vector2(2.2, 2.2)
	add_child(hero)

	var box := VBoxContainer.new()
	box.position = Vector2(60, 78)
	box.size = Vector2(520, 270)
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var fg := Color(0.95, 0.92, 1.0) if _dark else Color(0.30, 0.20, 0.12)
	_line(box, e.title, 22, fg)
	_line(box, e.text, 11, fg)
	if key != "stay" and S.flags.get("promise", false):
		_line(box, "옆에는 오른쪽 끝마디가 바랜 크루아상 하나가, 3년 만에 새벽 공기를 마시고 있었다.", 10, Color(fg, 0.85))
	_line(box, "7일 총 매출 %s · 소지금 %s · 반죽 손상 평균 %d · 기분 평균 %d" % [D.fmt_money(float(S.total)), D.fmt_money(float(S.money)), int(round(avg_damage(S))), int(round(avg_mood(S)))], 9, Color(fg, 0.7))
	_line(box, "엔딩 %d종 중 하나 · 다른 선택을 하면 다른 결말을 볼 수 있어요" % ENDINGS.size(), 8, Color(fg, 0.55))
	var btn := UIUtil.button("타이틀로", 13)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func() -> void:
		if not GameState.busy:
			GameState.quit_to_title())
	box.add_child(btn)
	btn.grab_focus()


func _line(box: VBoxContainer, text: String, size: int, color: Color) -> void:
	var l := UIUtil.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
	box.add_child(l)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _dark:
		draw_rect(Rect2(0, 0, 640, 360), Color(0.07, 0.05, 0.09))
		UIUtil.ellipse(self, Vector2(320, 120), Vector2(300, 200), Color(0.23, 0.17, 0.31, 0.8 + 0.1 * sin(_t)))
	else:
		draw_rect(Rect2(0, 0, 640, 360), Color(0.98, 0.90, 0.78))
		UIUtil.ellipse(self, Vector2(320, 120), Vector2(300, 200), Color(1.0, 0.82, 0.58, 0.7 + 0.1 * sin(_t)))

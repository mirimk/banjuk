extends RefCounted
## 게임 데이터: 밸런스 상수, 빵, 시간표, 손님, 보상.
## 숫자는 모두 임시값 (밸런스 미조정).

# ---------------------------------------------------------------- 시간 / 밸런스
const SEC_PER_MIN := 0.5      # 게임 1분 = 실제 0.5초 (3시간 ≈ 90초)
const PROOF_TIME := 9.0       # 발효 게이지 1.0 까지 걸리는 시간(초)
const BAKE_TIME := 11.0
const COOL_TIME := 7.0
const PROOF_MAX := 1.4
const BAKE_MAX := 1.45
const PROOF_BAND := Vector2(0.75, 0.95)   # 발효 최적 구간
const BAKE_BAND := Vector2(0.85, 1.05)    # 굽기 최적 구간
const SHELF_MAX := 15
const BATCH := 2              # 반죽 1판 = 빵 2개
const START_MONEY := 5000
const LAST_DAY := 2           # 현재 프로토타입의 마지막 날

const BREADS := {
	"toast": {"name": "식빵", "price": 3000},
	"croissant": {"name": "크루아상", "price": 3500},
	"baguette": {"name": "바게트", "price": 4000},
	"bagel": {"name": "베이글", "price": 2500},
}
const BREAD_ORDER := ["toast", "croissant", "baguette", "bagel"]

const GRADES := [
	{"g": "S", "min": 90, "m": 1.5, "color": Color(0.83, 0.63, 0.09)},
	{"g": "A", "min": 75, "m": 1.2, "color": Color(0.31, 0.60, 0.36)},
	{"g": "B", "min": 55, "m": 1.0, "color": Color(0.29, 0.50, 0.69)},
	{"g": "C", "min": 30, "m": 0.7, "color": Color(0.54, 0.49, 0.42)},
	{"g": "F", "min": 0, "m": 0.3, "color": Color(0.23, 0.23, 0.23)},
]

const PHASES := [
	{"id": "bake1", "start": 300, "end": 480, "name": "새벽 빵 만들기", "loc": "kitchen"},
	{"id": "sale1", "start": 480, "end": 660, "name": "오전 영업", "loc": "bakery"},
	{"id": "break", "start": 660, "end": 780, "name": "쉬는 시간", "loc": "kitchen"},
	{"id": "bake2", "start": 780, "end": 900, "name": "오후 빵 만들기", "loc": "kitchen"},
	{"id": "sale2", "start": 900, "end": 1080, "name": "오후 영업", "loc": "bakery"},
]
const SECRET_MINUTE := 960    # 오후 영업 16:00 에 비밀스러운 손님 등장

# ---------------------------------------------------------------- 손님
const SKIN_1 := Color(0.98, 0.86, 0.74)
const SKIN_2 := Color(0.90, 0.72, 0.56)
const SKIN_3 := Color(0.72, 0.52, 0.36)
const SKIN_4 := Color(0.45, 0.30, 0.20)

## 외형: h(키 비율) skin hair style(short/long/bob/bun/curly/bald/pigtails) cloth acc(hijab/turban/cap/hat/wheelchair/cane/tie)
const PROFILES := [
	{"name": "김순자 할머니", "desc": "70대 · 단골", "skin": SKIN_1, "hair": Color(0.78, 0.78, 0.80), "style": "bun", "h": 0.9, "cloth": Color(0.55, 0.40, 0.65), "acc": "cane"},
	{"name": "다니엘", "desc": "30대 · 회사원", "skin": SKIN_4, "hair": Color(0.10, 0.08, 0.08), "style": "short", "h": 1.05, "cloth": Color(0.20, 0.25, 0.40), "acc": "tie"},
	{"name": "아이샤", "desc": "20대 · 대학원생", "skin": SKIN_3, "hair": Color(0.15, 0.10, 0.08), "style": "short", "h": 0.95, "cloth": Color(0.85, 0.75, 0.55), "acc": "hijab"},
	{"name": "지호", "desc": "9살 · 초등학생", "skin": SKIN_1, "hair": Color(0.12, 0.10, 0.10), "style": "short", "h": 0.62, "cloth": Color(0.95, 0.80, 0.25), "acc": "cap"},
	{"name": "마리아", "desc": "40대 · 간호사", "skin": SKIN_2, "hair": Color(0.65, 0.25, 0.12), "style": "long", "h": 0.95, "cloth": Color(0.55, 0.78, 0.85), "acc": ""},
	{"name": "라지", "desc": "50대 · 식당 사장", "skin": SKIN_3, "hair": Color(0.20, 0.15, 0.12), "style": "short", "h": 1.0, "cloth": Color(0.92, 0.92, 0.88), "acc": "turban", "beard": true},
	{"name": "박 할아버지", "desc": "80대 · 산책 중", "skin": SKIN_1, "hair": Color(0.92, 0.92, 0.92), "style": "bald", "h": 0.88, "cloth": Color(0.45, 0.42, 0.35), "acc": "", "glasses": true},
	{"name": "유키", "desc": "20대 · 유학생", "skin": SKIN_1, "hair": Color(0.08, 0.06, 0.06), "style": "bob", "h": 0.92, "cloth": Color(0.95, 0.65, 0.72), "acc": ""},
	{"name": "오마르", "desc": "30대 · 택배 기사", "skin": SKIN_2, "hair": Color(0.15, 0.10, 0.08), "style": "short", "h": 1.05, "cloth": Color(0.55, 0.38, 0.22), "acc": "cap", "beard": true},
	{"name": "소피", "desc": "6살 · 엄마랑 왔어요", "skin": SKIN_1, "hair": Color(0.95, 0.80, 0.40), "style": "pigtails", "h": 0.55, "cloth": Color(0.60, 0.80, 0.50), "acc": ""},
	{"name": "민준", "desc": "30대 · 프리랜서", "skin": SKIN_2, "hair": Color(0.30, 0.20, 0.12), "style": "short", "h": 1.0, "cloth": Color(0.35, 0.55, 0.45), "acc": "wheelchair"},
	{"name": "그레이스", "desc": "60대 · 여행자", "skin": SKIN_4, "hair": Color(0.92, 0.92, 0.92), "style": "curly", "h": 0.95, "cloth": Color(0.35, 0.60, 0.35), "acc": "hat", "glasses": true},
]
const SECRET := {"name": "검은 외투의 손님", "desc": "???"}

## 손님이 건네는 말. 반죽 손상이 높을수록 위쪽 단계(1, 2)의 대사가 나온다.
const FLAVOR := [
	[
		"여기 빵은 늘 따뜻하네요. 만드는 사람 마음이 따뜻해서 그런가?",
		"매일 같은 시간, 같은 빵. 그게 행복이지.",
		"빵은 왜 꼭 누군가에게 먹히려고 태어나는 걸까요?",
		"오늘따라 가게에 반죽 냄새가 진하네요.",
		"점원분, 손이 참 말랑해 보여요.",
		"부드러운 게 꼭 약한 건 아니더라고요.",
		"일하는 게 즐거워요? 아니면 그냥 익숙한 거예요?",
	],
	[
		"어… 손끝에 반죽 묻은 거 아니에요? 계속 붙어 있네.",
		"어제보다 좀… 말랑해지신 것 같은데. 기분 탓인가?",
		"이상하게 점원분한테서 발효 냄새가 나요.",
		"너무 열심히 하면 다 내어주게 돼요. 그럼 못 돌아가요.",
		"당신은 빵을 굽는 쪽이에요, 구워지는 쪽이에요?",
		"다들 조금씩 닳아가면서 사는 거죠, 뭐.",
	],
	[
		"혹시… 손가락이 하나 덜… 아, 아니에요. 잘못 봤나 봐요.",
		"반죽이 점원분 손을 따라 늘어나는 것 같아요.",
		"다 내어주고 나면, 그다음엔 뭐가 남는 걸까요?",
		"자기 자신을 조금씩 팔아서 사는 건 다 똑같죠.",
	],
]
const THANKS := ["감사합니다!", "잘 먹을게요~", "내일 또 올게요.", "고마워요, 수고해요.", "냄새 좋다~"]
const SAD := ["…그냥 갈게요.", "너무 오래 걸리네요.", "다음에 올게요."]

const STAFF_TALK := {
	"boss": ["좋은 빵은 좋은 마음에서 시작하지.", "허허, 손이 빠르구먼.", "정성을 들인 만큼 보답을 한다네.", "조금만 더 힘내 주게."],
	"crew": ["…적당히 해.", "오븐 너무 가까이 가지 마.", "난 3년 차야. 3년 동안… 아니야.", "반죽 숨소리 들려? …못 들었으면 됐어."],
}

# ---------------------------------------------------------------- 퇴근 후 보상 (임시)
const REWARDS := [
	{"id": "sleep", "name": "푹 자기", "cost": 0, "st": 35, "dmg": -100, "mood": 0,
		"desc": "체력 +35\n반죽 손상 완전 복구",
		"msg": "포근한 이불 속에서 손끝의 반죽이 천천히 떨어져 나갔다."},
	{"id": "youtube", "name": "유튜브 보기", "cost": 0, "st": 45, "dmg": 0, "mood": 20,
		"desc": "체력 +45 · 기분 +20\n(반죽 손상은 그대로)",
		"msg": "\"빵 굽는 영상 몰아보기\"… 왠지 남 일 같지 않다. 새벽 2시에야 잠들었다."},
	{"id": "chicken", "name": "치킨 시켜먹기", "cost": 15000, "st": 60, "dmg": -15, "mood": 30,
		"desc": "체력 +60 · 기분 +30\n반죽 손상 -15",
		"msg": "바삭한 튀김옷… 문득 이것도 원래는 반죽이었다는 생각이 든다."},
	{"id": "spa", "name": "반죽 보습 스파", "cost": 25000, "st": 70, "dmg": -100, "mood": 15,
		"desc": "체력 +70 · 기분 +15\n반죽 손상 완전 복구",
		"msg": "촉촉한 스팀 속에서 들러붙은 반죽이 스르르 녹아내렸다."},
]


static func grade_of(q: float) -> Dictionary:
	for g in GRADES:
		if q >= float(g["min"]):
			return g
	return GRADES[GRADES.size() - 1]


static func grade_info(letter: String) -> Dictionary:
	for g in GRADES:
		if g["g"] == letter:
			return g
	return GRADES[GRADES.size() - 1]


static func fmt_money(n: float) -> String:
	var v := int(round(n))
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out + "원"


static func fmt_time(m: float) -> String:
	var mi := int(floor(m))
	return "%02d:%02d" % [mi / 60, mi % 60]

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
const PROOF_SLOTS := 4
const SHAPE_SLOTS := 2
const OVEN_SLOTS := 3
const RACK_SLOTS := 4
const BATCH := 4              # 반죽 1판 = 빵 4개
const START_MONEY := 5000
const LAST_DAY := 7
const SKIP_Q := 20            # 공정을 건너뛰면 품질 상한 (= F 등급)

## 공정 이름
const STEP_NAMES := {"knead": "반죽", "proof": "발효", "shape": "성형", "proof2": "2차 발효", "bake": "굽기", "cool": "식히기"}

## 빵 단계: 해금 날짜, 공정, 소모 체력/반죽 손상, 먹었을 때 회복 체력
const TIERS := {
	1: {"name": "1단계", "unlock": 1, "steps": ["knead", "proof", "bake", "cool"],
		"st_knead": 6, "dmg_knead": 1, "st_shape": 0, "dmg_shape": 0, "dmg_oven": 1},
	2: {"name": "2단계", "unlock": 3, "steps": ["knead", "proof", "shape", "bake", "cool"],
		"st_knead": 8, "dmg_knead": 1, "st_shape": 3, "dmg_shape": 1, "dmg_oven": 1},
	3: {"name": "3단계", "unlock": 5, "steps": ["knead", "proof", "shape", "proof2", "bake", "cool"],
		"st_knead": 10, "dmg_knead": 1, "st_shape": 4, "dmg_shape": 1, "dmg_oven": 2, "levain": true},
}

## knead: 반죽 미니게임 방식 (timing = 타이밍 누르기 / rub = 문질러 치대기)
## shape: 성형 미니게임에서 따라 그릴 모양
const BREADS := {
	"cream": {"name": "크림빵", "tier": 1, "price": 2500, "knead": "timing"},
	"redbean": {"name": "단팥빵", "tier": 1, "price": 2500, "knead": "rub"},
	"choco": {"name": "초코소라빵", "tier": 1, "price": 2800, "knead": "timing"},
	"soboro": {"name": "소보루빵", "tier": 1, "price": 2300, "knead": "rub"},
	"sausage": {"name": "소시지빵", "tier": 2, "price": 3800, "knead": "timing", "shape": "zigzag"},
	"croquette": {"name": "고로케", "tier": 2, "price": 3500, "knead": "rub", "shape": "oval"},
	"sandwich": {"name": "샌드위치", "tier": 2, "price": 4500, "knead": "timing", "shape": "square"},
	"ciabatta": {"name": "치아바타", "tier": 3, "price": 5000, "knead": "rub", "shape": "fold"},
	"baguette": {"name": "바게트", "tier": 3, "price": 5500, "knead": "timing", "shape": "slash"},
	"wholewheat": {"name": "통밀빵", "tier": 3, "price": 6000, "knead": "rub", "shape": "circle"},
}
const BREAD_ORDER := ["cream", "redbean", "choco", "soboro", "sausage", "croquette", "sandwich", "ciabatta", "baguette", "wholewheat"]

## 진열대에서 먹을 빵이 없을 때 사 먹는 가게 재고 빵
const STAFF_BREAD := {"name": "사장님 빵 (가게 재고)", "price": 3000}
const EAT_WON_PER_ST := 125.0   # 빵값 125원당 체력 +1 (비싼 빵일수록 많이 회복)
const EAT_ST_RANGE := Vector2i(10, 60)

# ---------------------------------------------------------------- 손님 / 배달
## 빨리 건네면 팁: 손님 대기 게이지가 이만큼 이상 남아 있으면 빵값의 일정 비율을 팁으로
const FAST_TIPS := [
	{"pat": 0.8, "rate": 0.3, "msg": "와, 엄청 빠르네요! 팁이에요."},
	{"pat": 0.6, "rate": 0.15, "msg": "빨리 주셔서 고마워요. 팁이에요."},
]
const SOLD_OUT_PENALTY := 5000   # 손님이 찾는 빵이 진열대에 없어서 그냥 돌아가면 일당에서 차감
const LATE_PENALTY := 3000       # 빵은 있었는데 늦게 줘서 손님이 기다리다 떠나면 일당에서 차감
const MOOD_GOOD := 50.0          # 기분이 이보다 낮으면 미니게임 판정이 좁아지고 손님이 덜 온다
const MOOD_BAD := 30.0           # 이보다 낮으면 더 심하게
const MOOD_ENDING := 40.0        # '나만의 빵' 엔딩에 필요한 7일 평균 기분
const WRONG_PAT := 0.3        # 빵을 잘못 주면 손님 인내심 -30%
const WRONG_MOOD := 3         # 기분 -3
const WRONG_LIMIT := 3        # 같은 손님에게 3번 틀리면 화내고 나감
const DELIVERY_START := 3     # 배달 주문이 시작되는 날
const DELIVERY_FEE := 0.3     # 배달 수수료 30%
const DELIVERY_PAT := 45.0    # 배달 주문 대기 시간(초)

const GRADES := [
	{"g": "S", "min": 90, "m": 1.6, "color": Color(0.83, 0.63, 0.09)},
	{"g": "A", "min": 75, "m": 1.3, "color": Color(0.31, 0.60, 0.36)},
	{"g": "B", "min": 55, "m": 1.0, "color": Color(0.29, 0.50, 0.69)},
	{"g": "C", "min": 30, "m": 0.7, "color": Color(0.54, 0.49, 0.42)},
	{"g": "F", "min": 0, "m": 0.4, "color": Color(0.23, 0.23, 0.23)},
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
const SECRET_LINES := {
	1: {"line": "……", "req": "아무 빵이나 하나. 당신이 만든 걸로."},
	2: {"line": "또 보는군. 손이 벌써 말랑해지기 시작했어.", "req": "오늘도 아무 빵이나. 당신이 만든 걸로."},
	3: {"line": "그 병, 잘 먹이고 있나? 하루 한 번, 밀가루와 물.", "req": "빵 하나. 오늘은 당신 걸로."},
	4: {"line": "명부를 봤다면 알겠지. 여기선 다들 '조금만 더'를 듣는다.", "req": "아무 빵이나."},
	5: {"line": "당신의 발효종으로 구운 빵 냄새가 나는군. 그건 당신 거야.", "req": "르방으로 구운 걸 보고 싶군."},
	6: {"line": "이틀 남았어. 그 사람은 마지막 날에 부탁을 하지.", "req": "아무 빵이나 하나."},
	7: {"line": "오늘이 마지막이야. 무엇을 남길지는 당신이 정해.", "req": "마지막 빵을 주시오."},
}
const THANKS := ["감사합니다!", "잘 먹을게요~", "내일 또 올게요.", "고마워요, 수고해요.", "냄새 좋다~"]
const SAD := ["…그냥 갈게요.", "너무 오래 걸리네요.", "다음에 올게요."]

const STAFF_TALK := {
	"boss": ["좋은 빵은 좋은 마음에서 시작하지.", "허허, 손이 빠르구먼.", "정성을 들인 만큼 보답을 한다네.", "조금만 더 힘내 주게."],
	"crew": ["…적당히 해.", "오븐 너무 가까이 가지 마.", "난 3년 차야. 3년 동안… 아니야.", "반죽 숨소리 들려? …못 들었으면 됐어."],
}

# ---------------------------------------------------------------- 퇴근 후 보상 (임시)
const REWARDS := [
	{"id": "sleep", "name": "푹 자기", "cost": 0, "st": 35, "dmg": -40, "mood": 0,
		"desc": "체력 +35\n반죽 손상 -40",
		"msg": "포근한 이불 속에서 손끝의 반죽이 조금씩 떨어져 나갔다. 전부는 아니었다."},
	{"id": "youtube", "name": "유튜브 보기", "cost": 0, "st": 45, "dmg": 0, "mood": 20,
		"desc": "체력 +45 · 기분 +20\n(반죽 손상은 그대로)",
		"msg": "\"빵 굽는 영상 몰아보기\"… 왠지 남 일 같지 않다. 새벽 2시에야 잠들었다."},
	{"id": "chicken", "name": "치킨 시켜먹기", "cost": 30000, "st": 60, "dmg": -20, "mood": 30,
		"desc": "체력 +60 · 기분 +30\n반죽 손상 -20",
		"msg": "바삭한 튀김옷… 문득 이것도 원래는 반죽이었다는 생각이 든다."},
	{"id": "spa", "name": "반죽 보습 스파", "cost": 100000, "st": 70, "dmg": -60, "mood": 15,
		"desc": "체력 +70 · 기분 +15\n반죽 손상 -60",
		"msg": "촉촉한 스팀 속에서 들러붙은 반죽이 꽤 녹아내렸다. 하지만 손끝 한 마디는 끝내 말랑한 채였다."},
]


static func tier_of(type: String) -> int:
	return int(BREADS[type].tier)


static func tier_unlocked(tier: int, day: int) -> bool:
	return day >= int(TIERS[tier].unlock)


## 오늘 만들 수 있는(해금된) 빵 종류. 3단계는 발효종이 있어야 만들 수 있지만 목록에는 들어간다.
static func unlocked_breads(day: int) -> Array:
	return BREAD_ORDER.filter(func(t: String) -> bool: return tier_unlocked(tier_of(t), day))


static func max_tier(day: int) -> int:
	var m := 1
	for t in TIERS:
		if tier_unlocked(t, day):
			m = maxi(m, t)
	return m


## 손님 인내심 게이지 길이(초). 날이 갈수록 짧아진다.
static func patience(day: int) -> float:
	return maxf(9.0, 13.0 - (day - 1) * 0.6)


static func spawn_interval(day: int) -> Vector2:
	return Vector2(maxf(2.0, 3.5 - day * 0.2), maxf(3.5, 5.5 - day * 0.3))


## 영업 시간대 하나당 배달 주문 수
static func deliveries_per_phase(day: int) -> int:
	if day < DELIVERY_START:
		return 0
	return 1 if day <= 4 else (2 if day <= 6 else 3)


## 빵을 먹었을 때 오르는 체력: 빵값에 비례 (등급이 높고 비싼 빵일수록 많이)
static func eat_stamina(cost: int) -> int:
	return clampi(int(round(cost / EAT_WON_PER_ST)), EAT_ST_RANGE.x, EAT_ST_RANGE.y)


## 빨리 건넸을 때의 팁 (게이지 남은 비율 pat 기준). 없으면 {}.
static func fast_tip(pat: float) -> Dictionary:
	for t in FAST_TIPS:
		if pat >= float(t.pat):
			return t
	return {}


## "S ×1.6 · A ×1.3 · …" 등급별 가격 배율 안내
static func grade_price_text() -> String:
	var parts := []
	for g in GRADES:
		parts.append("%s×%s" % [g.g, str(g.m)])
	return " ".join(parts)


## 기분에 따른 미니게임 판정 배율 (1.0 = 보통, 작을수록 판정 구간이 좁다)
static func mood_skill(mood: float) -> float:
	if mood >= MOOD_GOOD:
		return 1.0
	return 0.85 if mood >= MOOD_BAD else 0.7


## 기분에 따른 손님 등장 간격 배율 (클수록 손님이 덜 온다)
static func mood_spawn(mood: float) -> float:
	if mood >= MOOD_GOOD:
		return 1.0
	return 1.25 if mood >= MOOD_BAD else 1.6


static func sale_price(type: String, grade: String) -> int:
	return int(round(BREADS[type].price * float(grade_info(grade).m) / 100.0)) * 100


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

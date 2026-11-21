extends RefCounted
## 빵 공정 규칙 (순수 함수 모음).
## 반죽 한 판(item) = {"type", "k"(반죽 점수), "ps"(발효), "ss"(성형), "ps2"(2차 발효), "skip"(공정 생략 여부), ...}
## 점수가 -1 이면 아직 그 공정을 거치지 않은 것.

const D = preload("res://scripts/systems/game_data.gd")


static func new_item(type: String, knead_score: float) -> Dictionary:
	return {"type": type, "k": knead_score, "ps": -1.0, "ss": -1.0, "ps2": -1.0, "skip": false,
		"stage": "proof", "p": 0.0, "shaped": false}


static func steps(type: String) -> Array:
	return D.TIERS[D.tier_of(type)].steps


static func needs(type: String, step: String) -> bool:
	return steps(type).has(step)


static func done(it: Dictionary, step: String) -> bool:
	match step:
		"knead":
			return float(it.get("k", -1)) >= 0.0
		"proof":
			return float(it.get("ps", -1)) >= 0.0
		"shape":
			return float(it.get("ss", -1)) >= 0.0
		"proof2":
			return float(it.get("ps2", -1)) >= 0.0
	return false


## 굽기 전에 남은 다음 공정 ("proof" / "shape" / "proof2" / "bake")
static func next_step(it: Dictionary) -> String:
	for st in steps(it.type):
		if st == "bake" or st == "cool":
			break
		if not done(it, st):
			return st
	return "bake"


## 아직 안 거친 공정 이름들 (건너뛰기 경고용)
static func missing_before_bake(it: Dictionary) -> Array:
	var out := []
	for st in steps(it.type):
		if st == "bake" or st == "cool":
			break
		if not done(it, st):
			out.append(D.STEP_NAMES[st])
	return out


## 최종 품질: 거친 공정 점수의 평균. 공정을 하나라도 건너뛰었으면 최하(F)로 제한.
static func quality(it: Dictionary, bake_score: float) -> int:
	var sum := bake_score
	var n := 1
	for key in ["k", "ps", "ss", "ps2"]:
		var v := float(it.get(key, -1))
		if v >= 0.0:
			sum += v
			n += 1
	var q := int(round(sum / n))
	if it.get("skip", false):
		q = mini(q, D.SKIP_Q)
	return q


static func proof_score(p: float) -> float:
	return clampf(100.0 - absf(p - 0.85) * 220.0, 0.0, 100.0)


static func bake_score(b: float) -> float:
	return clampf(100.0 - absf(b - 0.95) * 250.0, 0.0, 100.0)


## 공정 흐름 안내 문구 (예: "반죽 → 발효 → 성형 → 굽기 → 식히기")
static func flow_text(tier: int) -> String:
	var names := []
	for st in D.TIERS[tier].steps:
		names.append(D.STEP_NAMES[st])
	return " → ".join(names)

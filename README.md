# 반죽 (Banjuk)

> 빵을 만들수록 자신을 잃어가는 제빵사의 이야기
> 경영 시뮬레이션 + 스토리 어드벤처 + 심리 호러 · Godot 4 · 2D 픽셀아트 (현재 임시 도형 그래픽)

## 실행 방법

1. [Godot 4.3 이상](https://godotengine.org/download) 설치
2. Godot 프로젝트 매니저에서 **가져오기 → 이 폴더의 `project.godot`** 선택
3. `F5` (메인 씬: 타이틀 화면)

## 조작

| 키 | 동작 |
|---|---|
| ← → / A D | 이동 |
| E / Space / Enter | 상호작용, 대화 넘기기 |
| (반죽 미니게임) ← → / A D 번갈아 | 반죽하기 |
| (반죽 미니게임) Space 누르고 있기 | 온 힘을 다해 반죽 (품질↑, 대가↑) |

## 현재 구현 범위 (v0.1)

- 타이틀 화면 → 빵집 1일 차 → 하루 마감 화면
- 1일 차 흐름: 인트로 → 사장에게 업무 받기 → **반죽 미니게임** → 꼬마 손님 응대 → 사장에게 보고(일당) → 퇴근
- 크루(동료) 대화, 오븐 조사 등 선택 상호작용
- 능력치: 돈 / 체력 / 기억 / 신체 / 반죽 오염도
- 빵 품질과 '온 힘을 다한 정도'에 따라 대사·능력치·주인공 외형(손에 붙은 반죽)이 달라짐

## 폴더 구조

```
assets/        에셋 (현재는 폰트 설정만, 그래픽은 코드로 그린 임시 도형)
data/dialogues 날짜별 대사 JSON (day1.json) - 코드 수정 없이 대사 편집 가능
scenes/        main(타이틀·마감), bakery, minigames
scripts/       systems(GameState 등), bakery, characters, dialogue, minigames, main
tests/         자동 스모크 테스트
docs/          개발 로그, 기획 메모
```

## 자동 테스트

타이틀부터 1일 차 마감까지 자동으로 플레이해 오류 없이 끝나는지 확인합니다.

```bash
godot --headless --fixed-fps 60 --path . -s res://tests/smoke_test.gd
```

`SMOKE OK: day end reached...` 가 출력되면 통과입니다.

## 참고

- Windows 빌드로 내보낼 때는 내보내기 설정의 **리소스 → 리소스가 아닌 파일 포함 필터**에 `*.json` 을 추가해야 대사 파일이 포함됩니다.
- 한글 표시는 현재 시스템 폰트(맑은 고딕)를 사용합니다. 픽셀 폰트는 무료 OFL 폰트인 Galmuri / DungGeunMo 등을 `assets/ui/` 에 넣고 `default_font.tres` 를 교체하면 됩니다.

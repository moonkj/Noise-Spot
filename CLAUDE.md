# Cafe Vibe (카페바이브) — CLAUDE.md

## Project Overview
실시간 소음 수치(dB)와 스티커 평가를 결합한 지도 기반 로컬 소음 정보 공유 플랫폼.
**슬로건**: 시끄러운 도시 속, 나만의 고요한 카페 찾기
**브랜드 콘셉트**: Frequency of Calm — 거친 파형 → 부드러운 곡선 → 점(Spot)으로 수렴
**구현컨셉 context.md 참조**
**코딩 진행시 컨셉 유지 할 것**
---

## Project Structure

```
cafe_vibe/
├── lib/
│   ├── main.dart                          # 앱 진입점 (Supabase 초기화)
│   ├── app.dart                           # CafeVibeApp (MaterialApp.router)
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart            # Mint→SkyBlue 팔레트, dB 색상 맵
│   │   │   ├── app_strings.dart           # 고정 문구 (개인정보 고지 포함)
│   │   │   └── map_constants.dart         # 반경 3km/5km, 줌 임계값, debounce 300ms
│   │   ├── theme/app_theme.dart           # ThemeData (Material 3)
│   │   ├── router/app_router.dart         # go_router 라우트 정의
│   │   ├── utils/
│   │   │   ├── db_classifier.dart         # dB → 색상/레이블 변환
│   │   │   ├── ema_calculator.dart        # EMA: (old×0.7)+(new×0.3)
│   │   │   ├── bounds_cache.dart          # 지도 bounds 5분 TTL 캐시
│   │   │   └── noise_filter.dart          # 120dB+ 무효화, 이상치 필터
│   │   └── services/
│   │       ├── supabase_service.dart      # Supabase 클라이언트 싱글턴
│   │       ├── location_service.dart      # GPS 획득, 100m 반경 검증
│   │       └── calibration_service.dart   # 최초 실행 3초 마이크 캘리브레이션
│   └── features/
│       ├── auth/                          # 온보딩 + Apple/Google 로그인
│       ├── map/                           # 지도 화면 + 마커 + 필터 + debounce
│       ├── report/                        # dB 측정 + 스티커 선택 (음성 미저장)
│       ├── profile/                       # 통계 카드 + trust 등급
│       └── settings/                      # 권한 관리 + 개인정보 안내
├── supabase/migrations/
│   └── 001_initial_schema.sql             # PostGIS + RPC + RLS 전체 스키마
└── assets/
    ├── icon/app_icon.png                  # Concept 2 "Frequency of Calm" 아이콘
    └── animations/                        # Lottie 애니메이션 파일
```

---

## Tech Stack

| 항목 | 기술 | 버전 |
|------|------|------|
| Framework | Flutter (iOS/iPad) | 3.41.2 |
| State Management | flutter_riverpod (StateNotifier) | 3.2.1 |
| Navigation | go_router | 14.8.1 |
| Backend | supabase_flutter | 2.12.0 |
| Maps | google_maps_flutter | 2.14.2 |
| Location | geolocator | 14.0.2 |
| Permissions | permission_handler | 12.0.0 |
| dB Measurement | noise_meter | 5.1.0 |
| Animation | flutter_animate | 4.5.2 |

---

## Testing Platform (필수)

**⚠️ 모든 테스트는 iOS 시뮬레이터에서 실행해야 합니다**

```bash
# 사용 가능한 시뮬레이터 목록
flutter devices

# 특정 시뮬레이터에서 실행
flutter run -d "iPhone 16 Pro"
flutter run -d "iPad Pro (12.9-inch)"

# 테스트 실행 (iOS 시뮬레이터)
flutter test

# 커버리지 포함 테스트
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## TDD Approach (Recommended)

### RED → GREEN → REFACTOR Cycle

1. 🔴 **RED**: 테스트 먼저 작성 → 실행 → 실패 확인 (iOS에서 실행)
2. 🟢 **GREEN**: 테스트를 통과하는 최소한의 코드 작성 (iOS에서 검증)
3. 🔵 **REFACTOR**: 테스트가 통과된 상태에서 코드 품질 개선 (iOS에서 재검증)

### Coverage Target: 80%+

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### 테스트 우선순위

| 우선순위 | 대상 | 이유 |
|----------|------|------|
| 🔴 필수 | `EmaCalculator` | 핵심 비즈니스 로직 |
| 🔴 필수 | `NoiseFilter` | 120dB 무효화 로직 |
| 🔴 필수 | `DbClassifier` | 색상/레이블 매핑 |
| 🔴 필수 | `LocationService.isWithinReportRadius()` | 100m 게이트 |
| 🟡 권장 | `BoundsCache` | 5분 TTL 캐시 |
| 🟡 권장 | `MapController` | debounce + 줌 레벨 로직 |
| 🟡 권장 | `ReportController` | dB 측정 상태 전환 |

---

## Core Business Rules (절대 변경 금지)

### 개인정보 보호
- 마이크 음성 데이터는 절대 저장하지 않음 (스트림 메모리 처리 후 즉시 휘발)
- DB에는 오직 숫자(dB)만 저장
- 모든 측정 화면에 고정 표기: `"음성은 저장되지 않으며 소음 수치(dB)만 기록됩니다."`

### 위치 제한
- 앱 포그라운드 상태에서만 측정 허용
- 리포팅은 반드시 현재 위치 반경 **100m 이내** 장소만 가능
- 전국 단위 데이터 조회 금지 (최대 5km 제한)

### 서버 최적화
- `onCameraIdle` + **300ms debounce** 후 서버 요청
- 동일 bounds **5분간 캐싱** (재요청 금지)
- Zoom **11 미만**: 데이터 로딩 완전 중단
- 이미지 업로드 기능 추가 금지

### 데이터 무결성
- 120dB 이상 측정값 자동 무효 처리
- EMA 공식: `NewAvg = (OldAvg × 0.7) + (CurrentdB × 0.3)`
- Hybrid DB Strategy: Google Places API는 신규 장소 등록 시 **1회만** 호출

---

## API Keys 설정 방법

### 빌드 시 dart-define 사용 (절대 하드코딩 금지)
```bash
flutter build ios \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key
```

### Google Maps API Key
```swift
// ios/Runner/AppDelegate.swift
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
```

---

## Supabase 설정 체크리스트

- [ ] Supabase 프로젝트 생성
- [ ] Extensions 탭에서 **PostGIS** 활성화
- [ ] SQL Editor에서 `supabase/migrations/001_initial_schema.sql` 실행
- [ ] Authentication → Providers에서 **Apple** 활성화
- [ ] Authentication → Providers에서 **Google** 활성화

---

## Google Cloud Console 체크리스트

- [ ] **Maps SDK for iOS** 활성화
- [ ] **Places API** 활성화
- [ ] API 키 생성 → 번들 ID `com.cafevibe` 제한 설정
- [ ] `AppDelegate.swift`에 키 입력

---

## 앱 아이콘 설정

1. Concept 2 "Frequency of Calm" PNG (1024×1024) → `assets/icon/app_icon.png` 저장
2. 아이콘 생성 실행:
```bash
dart run flutter_launcher_icons
```

---

## 브랜드 디자인 원칙

- 메인 컬러: Mint Green `#5BC8AC` → Sky Blue `#78C5E8` 그라데이션
- 고채도 색상, 강한 대비 사용 금지
- 불필요한 시각 효과 금지 (미니멀 라인 아트 기반)
- dB 수치 색상: Mint(매우조용) → Blue(조용) → Yellow → Orange → Red
- Trust Score 표현: 마커 **테두리 굵기**로만 표현 (Bronze/Silver/Gold)

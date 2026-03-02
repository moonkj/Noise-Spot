# Cafe Vibe — 개발 진행 현황 (Process Log)

마지막 업데이트: 2026-03-02 (GitHub 저장소명 변경 Noise-Spot→Vibe-cafe ✅, 프로필 대표뱃지 ✅, 측정횟수 실시간 반영 ✅, 랭킹 명칭 변경 ✅)

---

## 전체 진행률

```
Phase 1: 프로젝트 초기화     ████████████ 100% ✅
Phase 2: Core 레이어         ████████████ 100% ✅
Phase 3: Auth Feature         ████████████ 100% ✅
Phase 4: Map Feature          ████████████ 100% ✅
Phase 5: Report Feature       ████████████ 100% ✅
Phase 6: Profile Feature      ████████████ 100% ✅ (레벨/포인트/뱃지 시스템 추가)
Phase 7: Settings Feature     ████████████ 100% ✅ (전면 재설계 완료)
Phase 8: DB 마이그레이션      ████████████ 100% ✅ (001~007 Supabase 적용완료)
Phase 9: 테스트               ████████████ 100% ✅ (71/71 통과)
Phase 10: 실제 API 연동       ████████████ 100% ✅
Phase 11: 앱 아이콘 & 빌드    ████████████ 100% ✅
Phase 12: UI 폴리시           ████████████ 100% ✅ (마커버그수정 ✅, lint 0 ✅)
Phase 14: UI 전면 개편         ████████████ 100% ✅ (4탭 네비, 탐색/랭킹 신규, 프로필/설정 재설계)
Phase 15: 버그 수정 & 안정화   ████████████ 100% ✅ (랭킹 영구로딩 수정, 프로필 실데이터, crash 방지)
Phase 16: 기능 완성           ████████████ 100% ✅ (탐색 onTap, 닉네임 서버저장, migration 002 배포)
Phase 17: SpotDetailScreen   ████████████ 100% ✅ (전체화면 상세, 시간대 차트, 바이브 태그, 최근 측정)
Phase 18: 측정화면 재설계     ████████████ 100% ✅ (원형게이지, pulse 애니메이션, idle 상태, 커스텀 타이머)
Phase 19: 카페 관리 시스템    ████████████ 100% ✅ (사용자 추가요청, 관리자 승인/등록/수정/삭제, 이메일 알림)
Phase 20: 측정/프로필 강화    ████████████ 100% ✅ (18종 스티커, XP 10레벨, 뱃지상세, 콘텐츠필터, 레벨아이콘)
Phase 21: 30종 뱃지 시스템    ████████████ 100% ✅ (6카테고리 30뱃지, 획득팝업, 레벨업애니메이션)
Phase 22: 더미 모드 & 안정화  ████████████ 100% ✅ (강남역 30개 더미, 첫바이브 랜덤닉네임, 마이크권한 네이티브채널, 탐색탭 UX개선)
Phase 23: UX 완성도           ████████████ 100% ✅ (프로필 대표뱃지, 측정횟수 실시간, 랭킹 명칭/임계값, 카페상세 커피컵 아이콘)
Phase 13: App Store 준비      ████████░░░░  65% 🔄 (GitHub Pages ✅, IPA 57.9MB ✅, TestFlight ⏳, ASC 정보 ⏳)
아키텍처: 익명인증 전환        ████████████ 100% ✅ (SecureLocalStorage ✅, 닉네임 ✅, 버그수정 ✅)
```

---

## ✅ 완료된 작업

### Phase 1: 프로젝트 초기화
- [x] `flutter create cafe_vibe --org com.cafevibe --platforms ios` 실행
- [x] `pubspec.yaml` 전체 의존성 설정 (버전 충돌 해결 포함)
  - noise_meter: 6.x → **5.1.0** 수정 (pub.dev 최신)
  - permission_handler: 11.x → **12.0.0** 수정 (noise_meter 요구)
  - freezed: 2.x → **3.2.5** 수정 (freezed_annotation 3.x와 매칭)
- [x] `flutter pub get` 성공 (171개 패키지 설치)
- [x] `.gitignore`에 API 키 파일 추가 (`.env`, `secrets.json` 등)
- [x] `ios/Runner/Info.plist` iOS 권한 문구 설정
  - `NSMicrophoneUsageDescription`
  - `NSLocationWhenInUseUsageDescription`
  - `NSLocationAlwaysAndWhenInUseUsageDescription`
  - `CFBundleURLTypes` — URL Scheme `com.cafevibe.cafevibe` (Supabase OAuth 딥링크)

### Phase 2: Core 레이어

#### constants/
- [x] `app_colors.dart` — Mint→SkyBlue 팔레트, dB 레벨별 색상(5단계), Trust Score 색상
- [x] `app_strings.dart` — 모든 고정 문구 (개인정보 고지, 필터 레이블, 카카오/애플/구글 로그인 문구)
- [x] `map_constants.dart` — 반경 3km/5km, 줌 임계값(11/13/15), debounce 300ms, TTL 300s

#### theme/
- [x] `app_theme.dart` — Material 3 기반, Mint-Blue 팔레트, 미니멀 폰트 스케일

#### router/
- [x] `app_router.dart` — go_router 라우트 정의
  - `/onboarding` → OnboardingScreen
  - `/map` → MapScreen (ShellRoute)
  - `/report?spotId=&spotName=` → ReportScreen
  - `/profile` → ProfileScreen
  - `/settings` → SettingsScreen

#### utils/
- [x] `db_classifier.dart` — dB 수치 → 색상/레이블/이모지 변환
- [x] `ema_calculator.dart` — EMA 공식: `(old×0.7) + (new×0.3)`
- [x] `bounds_cache.dart` — 지도 bounds 5분 TTL 캐시 (중복 요청 방지)
- [x] `noise_filter.dart` — 120dB+ 무효화, 이상치 통계 필터링 (sqrt 버그 수정 완료)

#### services/
- [x] `supabase_service.dart` — Supabase 싱글턴, authStateProvider, currentUserProvider
- [x] `location_service.dart` — GPS 권한 요청, Haversine 100m 게이트, currentPositionProvider
- [x] `calibration_service.dart` — 최초 실행 3초 샘플링 → mic_offset SharedPreferences 저장

### Phase 3: Auth Feature
- [x] `auth_repository.dart` — **익명 인증 모델로 전환** (Kakao/Google OAuth 제거)
  - `signInAnonymously()` — Supabase 익명 로그인 (기기 ID 기반 identity)
  - `deleteAccount()` — reports 삭제 + signOut
  - 이전: Kakao/Google browser OAuth → **MVP 이후로 보류**
- [x] `onboarding_screen.dart` — **2.6초 후 무조건 `/map` 이동** (auth gate 제거)
  - 스플래시 애니메이션만 표시 후 바로 지도로 이동
  - `_trySignInBackground()` — 이동 후 백그라운드에서 익명 로그인 재시도 (10초 주기)
  - `unawaited()` 패턴으로 fire-and-forget 처리
  - Keychain에 세션 있으면 router가 바로 `/map` fast-path
- [x] `app_router.dart` — **device-identity 모델 redirect 규칙**
  - 로그인 상태 + onboarding → `/map` fast-path
  - **비로그인 사용자는 리다이렉트 없음** (지도는 항상 접근 가능)
  - 리포트 제출만 세션 필요 (Supabase RLS)
- [x] `wave_to_spot_painter.dart` — **PathMetric 기반 완전 재작성**
  - 작은 흰 점이 경로를 따라 이동하며 잔상을 남기는 애니메이션
  - 좌측: EKG 심전도 파형 클러스터 (아이콘과 동일한 파형 형태)
  - 우측: 상향 곡률의 부드러운 QuadraticBezier 호
  - 종점 도착 시 흰 원(Spot) bloom 효과 (progress > 0.90)
  - Mint Green → White 그라데이션 트레일
  - `metric.extractPath(0, drawn)` — 잔상 유지 방식

### Phase 4: Map Feature
- [x] `spot_model.dart` — SpotModel Freezed 모델 (StickerType enum 포함)
  - `isStale` — 30일 이상 비활성 판별
  - `markerOpacity` — 비활성 스팟 투명도 0.4
  - `markerBorderWidth` — trust_score 기반 테두리 굵기
- [x] `spots_repository.dart` — PostGIS `get_spots_near` RPC 호출, `createSpot()`
- [x] `map_controller.dart` — StateNotifier 기반
  - onCameraIdle + 300ms debounce
  - BoundsCache 5분 TTL
  - Zoom 11 미만 로딩 중단
  - `SpotDisplayMode` (individual/reduced/heatmap/hidden)
  - STUDY/MEETING/RELAX 필터 토글
- [x] `map_screen.dart` — GoogleMap 전체화면 + 검색바 + 필터바 + 스팟 정보카드 + FAB
- [x] `spot_marker_widget.dart` — dB 색상 원형 마커 + SpotInfoCard (Social Proof 포함)
- [x] `filter_bar.dart` — STUDY/MEETING/RELAX 토글 칩

### Phase 5: Report Feature
- [x] `report_model.dart` — ReportModel (Supabase 응답 파싱)
- [x] `report_repository.dart` — `submitReport()` (dB만 저장, 음성 없음) + `getMyReports()` + `getMyStats()`
- [x] `report_controller.dart` — Riverpod 3.x `Notifier<ReportState>`, NoiseMeter 스트림 처리
  - `initialize(spotId, lat?, lng?)` — screen이 직접 args 전달 (StateProvider 대체)
  - `startMeasurement()` — NoiseMeter.noise 스트림 구독 (파일 저장 없음)
  - `stopMeasurement()` — 스트림 취소 + meter null 처리 (즉시 휘발)
  - 3초 안정화 후 평균 계산 → StickerSelection 단계로 전환
  - `verifyProximity()` — 100m 반경 검증
  - `submitWithSticker()` — Supabase RPC 호출 (EMA 갱신)
  - `ReportPhase`: measuring → stabilizing → stickerSelection → submitting → done/error
- [x] `report_screen.dart` — 단계별 화면 전환 (switch expression 활용)
- [x] `privacy_notice_bar.dart` — 상단 고정 개인정보 고지 바 (항상 표시)
- [x] `db_meter_widget.dart` — 실시간 dB 대형 숫자 + 반응형 파형 바 + 안정화 중 표시
- [x] `sticker_card_grid.dart` — STUDY/MEETING/RELAX 카드 3종 (flutter_animate 등장 효과)

### Phase 6: Profile Feature
- [x] `profile_screen.dart`
  - **`_ProfileHeader`** — 닉네임(또는 '익명 사용자') + 총 리포트 수 + 설정 이동 버튼
  - 총 리포트 수 / 평균 dB 통계 카드
  - Trust Grade 카드 (Bronze/Silver/Gold 진행률 바)
  - 방문 기록 리스트 (스티커 + dB + 날짜)

### Phase 7: Settings Feature
- [x] `settings_screen.dart`
  - **내 프로필 섹션** — 닉네임 표시 + 탭으로 수정 다이얼로그 (최대 20자)
  - 개인정보 처리방침 카드 (강조 표시)
  - 마이크/위치 권한 상태 표시 + 관리 버튼
  - **로그아웃 제거** (device-identity 모델 — 불필요)
  - **"데이터 초기화"** (구: 계정 삭제) — nicknameProvider.clear() + deleteAccount() + `/onboarding`
  - 닉네임 저장 버그 수정: `builder: (dialogCtx)` 사용 → `Navigator.pop(dialogCtx)`

### 익명 인증 아키텍처 전환 + 닉네임 기능 (2026-02-27)

#### 세션 영속성 — SecureLocalStorage
- [x] `lib/core/services/secure_local_storage.dart` — **iOS Keychain 기반 세션 저장** (NEW)
  - `LocalStorage` 인터페이스 구현 (`flutter_secure_storage`)
  - `IOSOptions(accessibility: KeychainAccessibility.first_unlock)` — 기기 잠금 후 첫 해제 시 접근 가능
  - 오류 시 silent catch → EmptyLocalStorage fallback
- [x] `lib/core/services/supabase_service.dart` — SecureLocalStorage 우선, 실패 시 EmptyLocalStorage fallback
  - 익명 사용자 세션이 앱 재시작 후에도 유지됨 (새 anon 유저 생성 방지)

#### 닉네임 서비스
- [x] `lib/core/services/nickname_service.dart` — **SharedPreferences 기반 닉네임 관리** (NEW)
  - `NicknameNotifier extends Notifier<String?>` (Riverpod 3.x 패턴)
  - `build()` — 초기 null 반환 후 `_load()` 비동기 로드
  - `set(name)` / `clear()` — SharedPreferences 저장/삭제 + state 즉시 업데이트
  - `nicknameProvider = NotifierProvider<NicknameNotifier, String?>`

#### LaunchScreen 업데이트
- [x] `ios/Runner/Base.lproj/LaunchScreen.storyboard`
  - 흰 배경 + 빈 imageView → **Mint Green 배경 (#A8E6CF) + "Cafe Vibe" 흰 텍스트**
  - 앱 로딩 중 브랜드 일관성 유지

#### 주요 버그 수정
- [x] **검은 화면 버그** (`settings_screen.dart` `_editNickname`)
  - 원인: `builder: (_)` → 외부 context로 `Navigator.pop(context)` → 설정 화면 자체 pop
  - 수정: `builder: (dialogCtx)` → 모든 `Navigator.pop(dialogCtx)` 사용

### Phase 6 수정: 프로필 stale cache 수정 (2026-02-27)
- [x] `profile_screen.dart` — `FutureProvider` → `FutureProvider.autoDispose` 전환
  - `_statsProvider`: autoDispose로 변경 → 화면 이탈 시 캐시 파기
  - `_myReportsProvider`: autoDispose로 변경 → 재진입 시 Supabase에서 최신 데이터 재조회
  - **원인**: 계정 삭제 후 재로그인해도 이전 유저 리포트가 표시되던 버그 수정

### Phase 10 추가 작업 (2026-02-27)
- [x] Supabase 테스트 spot 3개 삽입 (Management API SQL 실행)
  - 성수동 카페거리 (127.0557, 37.5443) — 48.5dB STUDY
  - 한강 반포지구 (126.9996, 37.5120) — 38.2dB RELAX
  - 강남역 지하상가 (127.0276, 37.4979) — 72.3dB MEETING
- [x] `reports` 테이블 RLS DELETE 정책 추가
  - `CREATE POLICY "reports_delete_own" ON reports FOR DELETE TO authenticated USING (auth.uid() = user_id)`
- [x] `auth_repository.dart` — `deleteAccount()` 메서드 구현
  - reports 테이블에서 user_id로 본인 리포트 삭제
  - Supabase Auth signOut (Supabase Edge Function 없이 MVP 수준으로 처리)
- [x] `settings_screen.dart` — 계정 삭제 AlertDialog → `authRepository.deleteAccount()` 호출 → `/onboarding` 이동
- [x] 실기기 재빌드 & 재설치 완료 (xcrun devicectl)

### Phase 8: Supabase DB 마이그레이션
- [x] `supabase/migrations/001_initial_schema.sql`
  - `CREATE EXTENSION postgis`
  - `spots` 테이블 + GIST Spatial Index + google_place_id UNIQUE 인덱스
  - `reports` 테이블 + 복합 인덱스 (spot_id, created_at DESC)
  - Row Level Security (공개 읽기, 인증 사용자 쓰기)
  - `get_spots_near()` RPC — ST_DWithin 반경 조회 + 24h 카운트
  - `update_spot_after_report()` RPC — EMA 갱신 + trust_score 계산 (FOR UPDATE 락)

### Phase 9: 단위 테스트 (완료)
- [x] `test/core/utils/ema_calculator_test.dart` — 5개 테스트 (EMA 공식, 첫 리포트, 수렴, 경계값)
- [x] `test/core/utils/noise_filter_test.dart` — 8개 테스트 (isValid, filterOutliers)
- [x] `test/core/utils/db_classifier_test.dart` — 7개 테스트 (colorFromDb, labelFromDb, formatDb)
- [x] `test/core/utils/bounds_cache_test.dart` — 7개 테스트 (히트/미스, tolerance, TTL, clear)
- [x] `test/core/services/location_service_test.dart` — 9개 테스트 (Haversine 100m 게이트, 경도 방향, 대각선, 서울→부산)
- [x] `test/features/map/map_controller_test.dart` — 17개 테스트 (displayMode 줌 경계값 11/13/15, MapState.copyWith, clearFilter/clearError)
- [x] `test/features/report/report_controller_test.dart` — 15개 테스트 (ReportState copyWith 전 단계, ReportPhase 열거형, dB 범위)
- **flutter test 결과: 71/71 통과** ✅

### iOS 실기기 빌드
- [x] iOS Deployment Target: **13.0 → 14.0** 상향 (google_maps_flutter_ios 요구사항)
  - `ios/Podfile`: `platform :ios, '14.0'`
  - `ios/Runner.xcodeproj/project.pbxproj`: `IPHONEOS_DEPLOYMENT_TARGET = 14.0`
- [x] iPhone "Moon" (iOS 26.4 beta) 릴리즈 빌드 설치 성공
  - Supabase 실제 URL/KEY로 `--dart-define` 연결
  - 온보딩 화면 및 애니메이션 정상 작동 확인

### Phase 11: 앱 아이콘 & 빌드
- [x] `assets/icon/app_icon.png` 교체 완료 (2026-02-28)
  - 출처: `/Users/kjmoon/Downloads/icon.png` → `assets/icon/app_icon.png` 복사
  - 디자인: 맵 핀 외곽선 + 내부 원 + 사운드 파형(EKG) + 아래 리플 호 3개
  - 배경: Mint(#A8E6CF) → SkyBlue(#87CEEB) 대각선 그라데이션, 흰색 아웃라인 스타일
  - 이전 v9 (노이즈 스파이크) → v10 (맵핀+파형) 로 교체
- [x] `dart run flutter_launcher_icons` 실행 — 전체 iOS 아이콘 사이즈 자동 생성 ✅
- [x] `flutter build ios --release` 성공 (41.6MB) ✅
- [x] `xcrun devicectl device install app` → iPhone "Moon" (iOS 26 beta) 설치 성공 ✅

### 로그인 화면 파형 높이 1.5배 확대
- [x] `lib/features/auth/presentation/onboarding_screen.dart`
  - `SizedBox(height: 72)` → `SizedBox(height: 108)` (1.5배)
  - `Size(double.infinity, 72)` → `Size(double.infinity, 108)` (CustomPaint)
  - `WaveToSpotPainter`의 `amp = h * 0.42`가 높이에 비례해 진폭 자동 1.5배 확대

### iOS 26 beta 실기기 설치 워크어라운드
- `flutter run --release`가 iOS 26 beta에서 CoreDevice 3002 오류 발생
- 해결: `xcrun devicectl` 명령어로 2단계 수동 설치
  ```bash
  # Step 1: 빌드
  flutter build ios --release --dart-define=SUPABASE_URL=... "--dart-define=SUPABASE_ANON_KEY=..."
  # Step 2: 설치
  xcrun devicectl device install app --device DEVICE_ID build/ios/iphoneos/Runner.app
  # Step 3: 실행
  xcrun devicectl device process launch --device DEVICE_ID com.cafevibe.cafeVibe
  ```

---

## ⏳ 남은 작업 — 상세 계획

> 우선순위: 🔴 즉시 | 🟠 단기 | 🟡 중기 | 🟢 장기

---

### ✅ Step 1: Supabase Migration 002 적용 — 완료 (2026-03-01)
- `supabase migration repair 001 --status applied` → 히스토리 등록
- `supabase db push --linked` → 002만 remote 적용
- 백필: `update_user_stats()` 기존 사용자 일괄 실행 (Management API)
- 측정왕 랭킹: 앱 재시작 후 실데이터 1명 표시 확인 ✅

---

### ✅ Step 2: 탐색 화면 카페 탭 → 상세 카드 표시 — 완료 (2026-03-01)
- `explore_screen.dart` `_CafeListTile.onTap` 구현
  - `showModalBottomSheet` → `SpotInfoCard` (spot_marker_widget.dart 재사용)
  - "지금 소음 측정하기" → `Navigator.pop` + `context.push('/report?spotId=&spotName=')`
  - `isScrollControlled: true` + `padding: EdgeInsets.only(bottom: 24)` (홈바 여백)
- `spot_marker_widget.dart` import 추가

---

### ✅ Step 3: 닉네임 서버 저장 연동 — 완료 (2026-03-01)
- `settings_screen.dart` `_saveNickname()` 메서드 신규
  - `nicknameProvider` SharedPreferences 저장
  - `upsert_user_profile` RPC 호출 (migration 002, 실패 시 조용히 무시)
- dialog 닫기 → 서버 저장 순서로 처리 (`use_build_context_synchronously` 경고 방지)
- `supabase_service.dart` import 추가
- `flutter analyze` 0 issues ✅

---

### ✅ Phase 17: SpotDetailScreen — 전체화면 카페 상세 페이지 (2026-03-01)

#### 구현 완료 내용
- [x] `lib/features/explore/presentation/spot_detail_screen.dart` — **신규 전체화면 상세 페이지**
  - `SliverAppBar` (expandedHeight:200, SkyBlue↔Mint 그라데이션 히어로)
  - `_SummaryBanner` — 평균 dB · 스티커 · 측정 횟수 3가지 요약 배너
  - `_HourlyChartCard` — 시간대별 소음 추이 (CustomPaint 베지어 라인차트, 30일 집계)
  - `_VibeTagsCard` — 분위기 해시태그 chips (dB 레벨 + 스티커 + 측정수 기반 파생)
  - `_RecentReportsCard` — 최근 10개 측정 리스트 (아바타·닉네임·시간·스티커·dB)
  - `_StickyMeasureButton` — 하단 고정 "소음 측정하기" 버튼 → `/report?spotId=...`
  - **Provider 2개**: `_hourlyNoiseProvider` / `_recentReportsProvider` (FutureProvider.autoDispose.family)
- [x] `lib/features/explore/presentation/explore_screen.dart` — 완전 재작성
  - `_CafeListTile.onTap` → `context.push('/spot/${spot.id}', extra: spot)` (바텀시트 → 풀스크린)
  - `_SpotDetailSheet`, `_DbGaugeCard`, `_MetaChip` 등 모든 시트 관련 코드 제거
- [x] `lib/core/router/app_router.dart` — `/spot/:id` 라우트 추가 (ShellRoute 내부, 바텀 탭 자동 숨김)
- [x] `lib/features/report/data/report_repository.dart` — 신규 메서드 2개
  - `getSpotRecentReports(spotId)` — 2-query 패턴 (reports → user_profiles 닉네임 batch merge)
  - `getSpotHourlyNoise(spotId)` — 최근 30일 리포트 클라이언트 집계 (by hour)

---

### ✅ Phase 18: 소음 측정 화면 재설계 (2026-03-01)

#### 구현 완료 내용
- [x] `lib/features/report/presentation/widgets/db_meter_widget.dart` — **완전 재설계**
  - **원형 아크 게이지**: 135°~405° (270° sweep), 틱 마크 24개, 배경/활성 아크 레이어
  - **Pulse 애니메이션**: `TickerProviderStateMixin` 2개 컨트롤러
    - `_pulseController` — scale 1.0↔1.045, 1400ms easeInOut, 측정 중 반복
    - `_arcController` — dB 보간 350ms easeOut (이전 값 → 새 값 smooth lerp, 렉 제거)
  - 중앙: dB 숫자(animated) + "dB" + 레벨 레이블 chip
  - idle 시 회색, 측정 중 dB 레벨 색상으로 전환 (`AnimatedContainer`)
- [x] `lib/features/report/presentation/report_controller.dart` — 업데이트
  - `ReportPhase.idle` 추가 (초기 상태)
  - `ReportState.elapsedSeconds: int` 필드 추가
  - `_elapsedTimer` (Timer.periodic 1초) — 측정 중 경과시간 추적
  - `stopMeasurement()` 공개 메서드 추가 → idle로 복귀
  - readings 임계값: 10 → **5** (측정 시간 단축, 3초 안정화 유지)
- [x] `lib/features/report/presentation/report_screen.dart` — **완전 재작성**
  - `_IdleView` — 회색 게이지 + 측정 팁 카드 ("버튼을 눌러 측정을 시작하세요")
  - `_MeasuringView` — 컬러 게이지(pulse) + 경과 타이머 배지 "측정 중 MM:SS"
  - 하단 상태별 버튼: 초록 "측정 시작" (idle) / 갈색 "측정 중지" (measuring/stabilizing)
  - 자동 시작 제거 → 사용자 수동 제어

#### 버그 수정
- [x] `lib/features/report/data/report_repository.dart` — `submitReport()` 익명 로그인 fallback 추가
  - `if (_client.auth.currentUser == null) await _client.auth.signInAnonymously()`
  - 원인: 백그라운드 로그인 미완료 상태에서 리포트 제출 시 "로그인이 필요합니다" 에러

---

---

### Phase 19: 카페 관리 시스템 — 2026-03-02

#### 지도 UI 개선
- [x] `map_screen.dart` — Cloud Map ID 적용 (`d3c574b4a49a45dc1dbda511`, Cafe Vibe 커스텀 스타일)
- [x] `map_screen.dart` — 검색 결과 핀 마커 추가 (`BitmapDescriptor.hueAzure`, Azure 파란색 핀)
- [x] `spot_marker_widget.dart` — 카페 이름 라벨 추가 (흰 pill 위에 카페명, 최대 11자 + 말줄임)
- [x] `map_screen.dart` — 3km 반경 원 표시 (사용자 위치 기준, mintGreen 반투명 원)
- [x] `map_controller.dart` — 스팟 쿼리 항상 사용자 위치 기준 (카메라 중심 → 사용자 GPS 위치)

#### 관리자 카페 직접 추가 (지도 롱프레스)
- [x] `lib/core/constants/admin_config.dart` — 신규 파일
  - `adminUserIds: ['da2a8b72-a3c2-415b-bae5-63f2fa0b92a0']`
  - `adminEmail: 'imurmkj@gmail.com'`
- [x] `map_screen.dart` — 관리자 전용 지도 롱프레스 → 카페 이름 입력 → `createSpot()` 직접 등록

#### 사용자 카페 추가 요청 + 이메일 알림
- [x] `supabase/migrations/004_cafe_requests.sql` — `cafe_requests` 테이블 + RLS 정책
  - `users can insert own requests`, `users can read own requests`, `service role full access`
- [x] `lib/features/admin/data/cafe_requests_repository.dart` — 신규
  - `CafeRequest` 모델 (id, userId, cafeName, address, note, status, createdAt)
  - `submitRequest()`, `fetchPending()`, `updateStatus()`
- [x] `settings_screen.dart` — "카페 추가 요청" 섹션 추가
  - 카페 이름 / 주소 / 메모 입력 후 Supabase 저장

#### 이메일 알림 (pg_net + Resend + Edge Function)
- [x] `supabase/migrations/005_cafe_request_webhook.sql` — pg_net 트리거
  - `CREATE EXTENSION IF NOT EXISTS pg_net`
  - `notify_cafe_request()` 트리거 함수 → `net.http_post()` → Edge Function 호출
  - `on_cafe_request_inserted` AFTER INSERT 트리거
- [x] `supabase/functions/notify-cafe-request/index.ts` — Deno Edge Function
  - Resend API (`onboarding@resend.dev`) → `imurmkj@gmail.com` 이메일 발송
  - 카페 이름 / 주소 / 메모 / 접수 시각 포함 HTML 이메일
  - 환경변수: `ADMIN_EMAIL`, `RESEND_API_KEY`

#### 관리자 요청 목록 & 승인 흐름
- [x] `supabase/migrations/006_admin_rls.sql` — 관리자 RLS 정책
  - `admin can read all requests` (SELECT)
  - `admin can update all requests` (UPDATE)
- [x] `settings_screen.dart` — 관리자 전용 "카페 추가 요청 목록" 섹션
  - `_AdminRequestsSheet` — 대기 중인 요청 목록, 거절/승인&등록 버튼
  - "승인 & 등록" → 다이얼로그: 카페 이름·주소·위도·경도 입력 → `createSpot()` + `updateStatus('approved')`
  - 주소 입력 후 **"자동" 버튼** → Google Geocoding API로 위도/경도 자동 입력

#### 관리자 카페 관리 (목록/수정/삭제)
- [x] `supabase/migrations/007_admin_spots.sql`
  - `get_admin_spots()` RPC — 수동 등록 스팟(google_place_id IS NULL)의 lat/lng 포함 목록
  - `admin can update spots` RLS (UPDATE)
  - `admin can delete spots` RLS (DELETE)
- [x] `spots_repository.dart` — 추가 메서드
  - `AdminSpot` 모델 (id, name, formattedAddress, lat, lng, reportCount, createdAt)
  - `fetchManualSpots()` → `get_admin_spots` RPC 호출
  - `updateSpot(id, name, formattedAddress, lat, lng)` — 위치·이름·주소 수정
  - `deleteSpot(id)` — 스팟 삭제 (cascade: reports도 삭제)
- [x] `places_service.dart` — `geocodeAddress(address)` 추가
  - Google Geocoding API 호출 → `PlaceLatLng` 반환
- [x] `settings_screen.dart` — 관리자 "등록된 카페 관리" 섹션
  - `_AdminSpotsSheet` — 수동 등록 카페 목록 (이름·주소·좌표·측정건수·날짜)
  - "수정" → 다이얼로그: 이름·주소·위도·경도 편집, 주소 "자동" 버튼으로 좌표 자동 채움
  - "삭제" → 확인 후 삭제

---

### Phase 20: 측정/프로필 강화 — 2026-03-02

#### 20-A: 스티커 시스템 확장 (보고 화면)
- [x] `report_screen.dart` — `_StickerView` 단순화
  - `_ModeTab` (태그 / 메모 전환) 제거 → 스티커 선택 + 메모 입력만 유지
  - `_TagTextInput` 제거 → 제출 시 `#${sticker.label}` 자동 생성
  - `_MemoInput` 유지 (공개 피드에 표시되는 메모)
- [x] `supabase/migrations/013_expand_sticker_types.sql` — 18종 스티커 CHECK 제약 확장
- [x] `spot_detail_screen.dart` — switch → if 패턴으로 비-exhaustive 스위치 버그 수정

#### 20-B: XP 기반 10레벨 시스템
- [x] `supabase/migrations/014_xp_system.sql` 신규
  - `user_stats.total_xp INTEGER NOT NULL DEFAULT 0` 컬럼 추가
  - `award_xp(p_user_id UUID, p_xp INTEGER)` RPC — UPSERT 방식 XP 적립
- [x] `app_strings.dart` — `levelNames` 10개로 확장
  - 바이브 비기너 → 바이브 루키 → 바이브 헌터 → 바이브 탐험가 → 바이브 큐레이터
  - 바이브 감정사 → 바이브 소믈리에 → 바이브 마스터 → 바이브 그랜드마스터 → 바이브 레전드
- [x] `level_service.dart` 전면 재작성
  - `UserLevel.currentXp` (구: `current`) 필드명 변경
  - XP 임계값: `[0, 30, 80, 160, 280, 450, 700, 1050, 1500, 2100]`
  - `LevelService.xpPerReport = 10` (1일 1회 제한), `xpNewCafe = 5` (첫 방문 보너스)
  - `calcPoints()` 제거 (XP 기반으로 통합)
- [x] `report_repository.dart` — `submitReport()` XP 적립 로직
  - `hasReportedToday` — 당일 00:00 UTC 기준 쿼리
  - `isNewCafe` — 동일 스팟 기존 리포트 여부
  - `xpEarned = (hasReportedToday ? 0 : 10) + (isNewCafe ? 5 : 0)` → `award_xp` RPC 호출
  - `getMyStats()` — `user_stats.total_xp` 포함 반환
- [x] `profile_screen.dart`
  - `totalXp` 기반 `LevelService.calcLevel()` 호출
  - 프로그레스 텍스트: `'다음 레벨까지 ${level.nextTarget - level.currentXp} XP'`
  - `_StatsRow`: "획득 포인트" → "누적 XP" (`'$totalXp XP'`)

#### 20-C: 지도 필터바 전면 개편
- [x] `filter_bar.dart` 완전 재작성
  - "전체" 버튼 추가 (null filter — 모든 스팟 표시)
  - `StickerType.values.map()` → 18종 스티커 칩 자동 생성
  - `StickerCardGrid.colorFor(type)` 색상 재사용
  - `type.filterLabel` + `type.emoji` 레이블 표시
  - **이전**: 다른 칩 선택 후 전체 원복 불가 → **수정**: 전체 버튼 탭으로 filter = null 복원

#### 20-D: 뱃지 상세 화면
- [x] `level_service.dart` — `BadgeInfo.condition` 필드 추가 (획득 조건 설명)
- [x] `lib/features/profile/presentation/badge_detail_sheet.dart` 신규
  - `showBadgeDetailSheet(context, badges)` 헬퍼
  - `DraggableScrollableSheet` (0.5~0.95 비율)
  - "획득한 뱃지" / "아직 잠긴 뱃지" 2섹션
  - `_BadgeCard`: 이모지 원 (민트/회색) + 레이블 + 조건 + 획득/미획득 칩
- [x] `profile_screen.dart`
  - `_BadgeSection` 헤더에 획득 수 + "전체보기" 버튼 추가
  - `_BadgeTile.onTap` → `showBadgeDetailSheet()` 호출

#### 20-E: 콘텐츠 필터 (메모 욕설/성적 표현 차단)
- [x] `lib/core/utils/content_filter.dart` 신규 — 클라이언트 사이드 한국어 차단어 목록
  - 욕설 16종 + 초성 5종 + 성적 표현 14종 (공백 정규화 + 소문자 처리)
  - `ContentFilter.validate(text)` → `String?` 오류 메시지
- [x] `lib/core/services/moderation_service.dart` 신규 — Google Cloud NL Moderate Text API
  - 키: `--dart-define=GOOGLE_MODERATION_KEY=<key>` 빌드 시 주입 (소스 미포함)
  - 차단 카테고리: Toxic / Insult / Profanity / Derogatory / Sexually Explicit (신뢰도 ≥ 0.5)
  - 네트워크 오류 → 허용 (fail-open)
- [x] `report_screen.dart` — 2단계 검증 (`_StickerViewState`)
  - Layer 1: `ContentFilter.validate()` — 실시간 (입력 중)
  - Layer 2: `ModerationService.validate()` — 제출 시 (Google NL API)
  - `_apiMemoError` 상태 필드 + `_memoError` getter (로컬 에러 우선)
  - `_MemoInput` — `errorText` 파라미터 + 빨간 테두리

#### 20-F: 레벨별 아이콘
- [x] `app_strings.dart` — `levelIcons` 리스트 추가 (10개 이모지)
  - 🌱📡🔍🧭📋🎯☕🎧👑✨ (비기너→루키→헌터→탐험가→큐레이터→감정사→소믈리에→마스터→그랜드마스터→레전드)
- [x] `level_service.dart` — `UserLevel.icon` 필드 추가, `calcLevel()`에서 자동 할당
- [x] `profile_screen.dart`
  - `_LevelCard` — 하드코딩 5개 배열 제거 → `level.icon` 사용
  - `_ProfileHeader` 레벨 뱃지 — 이모지 + 레벨명 Row 구성

#### 20-G: 권한 상태 새로고침 버그 수정
- [x] `settings_screen.dart`
  - `WidgetsBindingObserver` mixin 추가
  - `didChangeAppLifecycleState(resumed)` — **600ms 딜레이 후** `_checkPermissions()` 호출
  - 원인: `resumed` 이벤트 발생 직후 iOS가 아직 권한 상태를 앱에 전달하지 않아 stale 값 반환

---

### Phase 21: 30종 뱃지 시스템 — 2026-03-02

#### 21-A: DB 마이그레이션
- [x] `supabase/migrations/015_user_badges.sql` 신규
  - `user_badges(user_id, badge_id, earned_at)` 테이블 + RLS 정책
    - `users can insert own badges`, `users can read own badges`
  - `get_first_reporter_count(p_user_id UUID)` RPC
    - DISTINCT ON(spot_id) 패턴으로 스팟별 첫 리포터 카운트 반환

#### 21-B: 뱃지 데이터 모델 & LevelService 재작성
- [x] `lib/core/utils/level_service.dart` 전면 재작성
  - `BadgeCategory` enum 6개 (firstExperience, consistency, exploration, vibeDetection, timeContext, community) + extension (label, emoji)
  - `BadgeInfo` — `id`, `xpReward`, `category`, `copyWith()` 추가
  - `BadgeStats` — 24개 필드 클래스 (streak, franchise, location, dB range, time-of-day 등 모든 뱃지 조건 저장)
  - `LevelService.calcBadges(BadgeStats s, Set<String> earnedIds)` — 30종 뱃지 평가 함수
    - `bool e(id, condition)` 헬퍼: condition 또는 기존 획득 시 true
    - B04/B29/B30: `earnedIds.contains(id)` only (즉시 이벤트 뱃지)

#### 21-C: BadgeStats 데이터 수집 (ReportRepository)
- [x] `lib/features/report/data/report_repository.dart`
  - `getMyBadgeStats()` → `Future<(BadgeStats, Set<String>)>` 추가
    - 내 리포트 + user_badges 동시 조회 (parallel await)
    - `get_first_reporter_count` RPC 호출
    - `_computeBadgeStats()` 클라이언트 집계
  - 집계 헬퍼들: `_maxStreak()`, `_monthIn20()`, `_extractCity()`, `_extractDistrict()`, `_detectChain()`
  - 프랜차이즈 탐지: 20종 한국 커피 체인 목록 기반

#### 21-D: BadgeService (획득 체크 & DB 저장)
- [x] `lib/core/services/badge_service.dart` 신규
  - `checkAndAward({client, stats, earnedIds})` — 전체 30뱃지 평가 → 새 뱃지 INSERT → `award_xp` 호출 → 새 뱃지 목록 반환
  - `awardInstantBadge({client, badgeId})` — 즉시 이벤트 뱃지용 (이미 획득 시 null 반환)
  - `getEarnedBadgeIds(client)` — `user_badges` 조회

#### 21-E: 뱃지 획득 팝업 & 레벨업 애니메이션
- [x] `lib/features/profile/presentation/widgets/badge_earned_popup.dart` 신규
  - `showBadgeEarnedPopup(context, badge)` — 바텀시트, 3초 자동 닫힘
  - 대형 이모지(64px) elasticOut 스케일 애니메이션 (flutter_animate)
  - "🎊 뱃지 획득!" 민트 칩 + 뱃지명 + 조건 + "+N XP" 칩 (staggered delay)
- [x] `lib/features/profile/presentation/widgets/level_up_animation.dart` 신규
  - `showLevelUpAnimation(context, newLevel)` — 전체화면 다이얼로그, 2.5초 자동 닫힘
  - "LEVEL UP!" 텍스트(민트 글로우) + 레벨 아이콘(80px) + 레벨번호·이름 카드

#### 21-F: 뱃지 상세 화면 리디자인
- [x] `lib/features/profile/presentation/badge_detail_sheet.dart` 재작성
  - 전체 진행도 바 (unlockedCount / badges.length)
  - `BadgeCategory` 별 `_CategoryHeader` (emoji + label + 카운트)
  - `_BadgeCard` 오른쪽에 "+N XP" 표시 추가

#### 21-G: 각 화면에 뱃지 체크 연동
- [x] `lib/features/report/presentation/report_screen.dart`
  - `ref.listen(reportControllerProvider)` — done 전환 감지 → `_checkBadgesAfterSubmit()` 호출
  - `_checkBadgesAfterSubmit()`: `getMyBadgeStats()` → `BadgeService.checkAndAward()` → 새 뱃지 순차 팝업
- [x] `lib/features/explore/presentation/spot_detail_screen.dart`
  - `ConsumerWidget` → `ConsumerStatefulWidget` 변환
  - `initState()` postFrameCallback → `_awardB04()` (B04: 첫 카페 상세 방문)
- [x] `lib/features/settings/presentation/settings_screen.dart`
  - `_showCafeRequestDialog()` 제출 후 `BadgeService.awardInstantBadge('B29')` 호출
- [x] `lib/features/profile/presentation/profile_screen.dart`
  - `_badgeDataProvider` FutureProvider 추가
  - `ref.listen(_myStatsProvider)` — 레벨 상승 감지 → `showLevelUpAnimation()` 호출
  - `calcBadges(badgeStats, earnedIds)` 기반으로 뱃지 렌더링

#### 30종 뱃지 목록 (6 카테고리)
| 카테고리 | ID | 이름 | 획득 조건 |
|---------|-----|------|----------|
| 첫 경험 | B01 | 소음 첫 발자국 | 첫 측정 완료 |
| 첫 경험 | B02 | 말걸기 성공 | 첫 메모 작성 |
| 첫 경험 | B03 | 바이브 감별사 | 첫 스티커 선택 |
| 첫 경험 | B04 | 카페 탐정 | 카페 상세 첫 방문 |
| 첫 경험 | B05 | 소음 지도 제작자 | 5곳 측정 완료 |
| 꾸준함 | B06 | 3일 연속 측정 | 3일 streak |
| 꾸준함 | B07 | 7일 연속 측정 | 7일 streak |
| 꾸준함 | B08 | 한달 개근 | 20일+ 측정/월 |
| 꾸준함 | B09 | 측정 마니아 | 총 50회 측정 |
| 꾸준함 | B10 | 전설의 소음 파수꾼 | 총 200회 측정 |
| 탐험 | B11 | 동네 탐험가 | 3개 구/동 방문 |
| 탐험 | B12 | 도시 탐험가 | 3개 도시 방문 |
| 탐험 | B13 | 프랜차이즈 정복자 | 5개 체인 방문 |
| 탐험 | B14 | 숨은 명소 발굴자 | 5곳 비프랜차이즈 방문 |
| 탐험 | B15 | 선구자 | 첫 리포터 5곳 |
| 바이브 감지 | B16 | 고요함의 수호자 | 40dB 이하 3회 |
| 바이브 감지 | B17 | 화이트노이즈 전문가 | 60–70dB 5회 |
| 바이브 감지 | B18 | 소음 챔피언 | 80dB+ 3회 |
| 바이브 감지 | B19 | dB 전문가 | 10종 dB 범위 경험 |
| 바이브 감지 | B20 | 완벽한 측정 | 5회 연속 유효 측정 |
| 시간대 | B21 | 아침 카페 마니아 | 오전 6~9시 5회 |
| 시간대 | B22 | 점심 피크 탐험가 | 정오~2시 5회 |
| 시간대 | B23 | 심야 탐험가 | 밤 10시~새벽 2시 3회 |
| 시간대 | B24 | 주말 카페 마니아 | 주말 10회 |
| 시간대 | B25 | 평일 카페 마니아 | 평일 20회 |
| 커뮤니티 | B26 | 커뮤니티 기여자 | 총 10회 메모 |
| 커뮤니티 | B27 | 정보 공유자 | 총 30회 메모 |
| 커뮤니티 | B28 | 스티커 컬렉터 | 3종 스티커 모두 사용 |
| 커뮤니티 | B29 | 지도 확장자 | 카페 추가 요청 제출 |
| 커뮤니티 | B30 | 신뢰의 목소리 | (서버 이벤트, 추후 확장) |

- `flutter analyze` 0 issues ✅

---

### Phase 22: 관리자 더미 모드 & 안정화 — 2026-03-02

#### 22-A: 강남역 더미 데이터 모드 (`admin_dummy_service.dart` 신규)
- [x] `lib/core/services/admin_dummy_service.dart` 신규
  - 강남역 반경 1km 내 현실적인 카페 30개 데이터 (dB 분포: 조용 6 / 보통 8 / 중간 8 / 시끄러움 5 / 매우 시끄러움 3)
  - 체인·인디 카페 혼합, 카페별 리포트 3~5개, EMA 기반 평균 dB, 가상 시간대 분산
  - `google_place_id: 'DUMMY:<index>:<nickname>'` 패턴으로 더미 스팟 식별 + 첫 바이브 닉네임 인코딩
  - `_fakeNames` 30종 한국 닉네임 목록 (예: '조용한탐험가', '힐링러', '스터디킹' 등)
  - `_dbSticker()` — DB CHECK 제약(STUDY/MEETING/RELAX만 허용)에 맞게 매핑
  - `insertDummyData()` — 중복 방지 가드, 스팟 INSERT → spotId 수집 → 리포트 INSERT (50개 배치)
  - `cleanupDummyData()` — DUMMY: 패턴 + 레거시 [테스트] 패턴 두 가지 DELETE
  - `AdminDummyModeNotifier` (`AsyncNotifier<bool>`) — enable/disable 스위치

#### 22-B: 더미 모드 카메라 이동 버그 수정
- [x] `lib/features/map/presentation/map_controller.dart`
  - `setDummyLocation()` 내 `mapController?.animateCamera(...)` try/catch 래핑
  - 설정 탭 활성화 시 지도 위젯 dispose → "Bad state: GoogleMapController was used after disposed" 오류 방지

#### 22-C: 첫 바이브 닉네임 표시 (`spot_marker_widget.dart`)
- [x] `lib/features/map/presentation/widgets/spot_marker_widget.dart`
  - `_firstReporterProvider` family 키: `String` → `(String, String?)` Dart record 튜플
  - `google_place_id`가 `'DUMMY:'`로 시작하면 DB 조회 없이 인코딩된 닉네임 즉시 반환
  - `SpotInfoCard`에서 `(spot.id, spot.googlePlaceId)` 전달

#### 22-D: DB RLS DELETE 정책 추가 (migration 016)
- [x] `supabase/migrations/016_spots_delete_policy.sql`
  - `CREATE POLICY "spots_delete_admin"` — 관리자 UID OR `DUMMY:%` OR `[테스트]%` 조건 DELETE 허용
  - `supabase db push --linked`로 원격 적용

#### 22-E: UI 테스트 텍스트 제거
- [x] `lib/features/settings/presentation/settings_screen.dart`
  - `'테스트용 임시 카페'` → `'현재 위치에 임시 카페 등록'`
  - `'테스트용 카페 8개 + 측정 데이터 삽입'` → `'강남역 주변 카페 30개 + 측정 데이터 삽입'`
  - `'테스트 카페 HH:MM'` → `'임시 카페 HH:MM'`
  - `'현재 GPS 위치로 테스트용 카페를 등록합니다.'` → `'현재 GPS 위치에 임시 카페를 등록합니다.'`

#### 22-F: 마이크 권한 iOS 26 beta 네이티브 채널 수정
- [x] `ios/Runner/AppDelegate.swift`
  - `AVFoundation` import 추가
  - `FlutterMethodChannel('com.cafevibe/permissions')` 등록
  - `checkMicrophonePermission` 호출 → `AVCaptureDevice.authorizationStatus(for: .audio)` 직접 조회
  - 반환값: `"authorized"` / `"denied"` / `"restricted"` / `"notDetermined"`
- [x] `lib/features/settings/presentation/settings_screen.dart`
  - `_checkMicNative()` 메서드 추가 — MethodChannel 호출 후 `"authorized"` 여부 판단
  - `_checkPermissions()` 내 `permission_handler` 완전 우회 → 네이티브 채널 사용
  - permission_handler iOS 26 beta 버그 (`AVAudioApplication.recordPermission` stale 값) 완전 해결

---

### 🟠 Step 4: App Store 준비 (App Store Connect 설정)

#### ✅ 4-A: GitHub Pages 개인정보처리방침 URL 활성화 — 완료 (2026-03-01)
- `gh api repos/moonkj/Noise-Spot/pages --method POST -f 'source[branch]=main' -f 'source[path]=/docs'` 실행
- URL 활성화: `https://moonkj.github.io/Noise-Spot/` (빌드 완료까지 수 분 소요)
- App Store Connect 등록 URL: `https://moonkj.github.io/Noise-Spot/docs/privacy-policy.html`

#### 4-B: App Store Connect 앱 정보 입력

| 항목 | 내용 |
|------|------|
| 앱 이름 | Cafe Vibe |
| 부제목 | 카페 소음 지도 |
| 카테고리 | Travel (주), Lifestyle (부) |
| 연령 등급 | 4+ |
| 개인정보처리방침 URL | https://moonkj.github.io/Noise-Spot/docs/privacy-policy.html |
| 지원 URL | https://github.com/moonkj/Noise-Spot/issues |
| 키워드 (한) | 카페,소음,조용한카페,카페지도,소음측정 |
| 키워드 (영) | cafe,noise,quiet,map,sound |

#### 4-C: 앱 설명 (한국어 초안)

```
조용한 카페를 찾는 가장 빠른 방법, Cafe Vibe

내 주변 카페의 실시간 소음 데이터를 지도에서 바로 확인하세요.
직접 소음을 측정하고 공유하면 더 정확해집니다.

주요 기능:
• 지도에서 카페 소음 레벨 한눈에 확인 (파란색=조용, 빨간색=시끄러움)
• 스마트폰 마이크로 dB 직접 측정 (음성 저장 없음)
• 조용한 카페 TOP 랭킹
• 나만의 측정 기록 & 레벨 시스템
```

#### 4-D: 스크린샷 촬영 (필수)
- **iPhone 6.7" (iPhone 16 Pro Max)**: 1290×2796px — 필수
- **iPhone 5.5"**: 1242×2208px — 필수 (iPad 없으면 이것만으로도 가능)
- 촬영 화면: 지도 / 소음 측정 / 탐색 / 랭킹 / 프로필 (최소 3장)
- 시뮬레이터에서 촬영: `flutter run -d "iPhone 16 Pro Max"` → Cmd+S

#### 4-E: IPA 빌드 & TestFlight 업로드
```bash
# IPA 빌드 (App Store용)
flutter build ipa --release \
  --dart-define=SUPABASE_URL=https://rqlfyumzmpmhupjtroid.supabase.co \
  "--dart-define=SUPABASE_ANON_KEY=<key>"

# Transporter 앱으로 업로드 또는:
xcrun altool --upload-app --type ios -f build/ios/ipa/*.ipa \
  --apiKey <ASC_KEY_ID> --apiIssuer <ISSUER_ID>
```

---

### 🟡 Step 5: UX 개선 (앱 품질)

#### ✅ 5-A: 탐색 화면 → 지도 연동 — 완료 (2026-03-01)
- `MapFocusNotifier` + `mapFocusProvider` 추가 (`map_controller.dart`)
  - `NotifierProvider<MapFocusNotifier, LatLng?>` 패턴 사용 (StateProvider 제거됨)
  - `focus(LatLng)` / `clear()` 메서드
- `map_screen.dart`: `ref.listen(mapFocusProvider)` → `animateCamera(zoom: 16)` → `clear()`
- `spot_marker_widget.dart`: `SpotInfoCard`에 `onViewMap?` 옵션 콜백 추가
  - 탐색 탭에서만 `OutlinedButton("지도에서 보기")` 표시
- `explore_screen.dart`: 카페 상세 바텀시트에 Consumer로 ref 접근
  - `onViewMap: () { ref.read(mapFocusProvider.notifier).focus(LatLng(spot.lat, spot.lng)); context.go('/map'); }`
- `google_maps_flutter` import 추가 (`explore_screen.dart`)

#### ✅ 5-B: 리포트 완료 후 탐색 화면 새로고침 — 자동 처리 확인 (2026-03-01)
- `ShellRoute` (StatefulShellRoute 아님) → 탭 전환 시 child 위젯 재빌드
- `/report` push → pop 시 `ExploreScreen` 재생성 → `_nearbySpotsProvider.autoDispose` 자동 재조회
- 별도 invalidate 불필요

#### 5-C: 온보딩 닉네임 설정
- 최초 실행 시 닉네임 입력 화면 추가 (선택 사항, 건너뛰기 가능)
- 프로필/랭킹에 내 이름 표시

#### 5-D: 지도 마커 클러스터링
- 많은 마커 밀집 시 클러스터 표시
- `google_maps_cluster_manager` 패키지 적용

---

### 🟢 Step 6: 장기 기능 (MVP 이후)

#### 6-A: 소셜 로그인 복원
- Kakao 비즈 앱 전환 후 account_email 권한 획득
- `auth_repository.dart`에 `signInWithKakao()` 재추가
- 기기 변경 시 데이터 연속성 보장

#### 6-B: 카페 상세 페이지
- 스팟 ID 기반 상세 화면 (`/spot/:id`)
- 최근 측정 기록 리스트
- 시간대별 소음 추이 (LineChart)
- 스티커 비율 차트

#### 6-C: 찜하기 기능
- 자주 가는 카페 저장
- 탐색 화면 "찜한 카페" 필터

#### 6-D: 알림 기능 (현재 UI만 있음)
- `firebase_messaging` 패키지 추가
- 측정 알림 / 랭킹 변동 알림
- 설정 화면 토글과 실제 구독 연동

---

### Phase 9: 테스트 ✅ 완료 (71/71)

| 상태 | 파일 | 테스트 수 |
|------|------|---------|
| ✅ | `test/core/utils/ema_calculator_test.dart` | 5개 |
| ✅ | `test/core/utils/noise_filter_test.dart` | 8개 |
| ✅ | `test/core/utils/db_classifier_test.dart` | 7개 |
| ✅ | `test/core/utils/bounds_cache_test.dart` | 7개 |
| ✅ | `test/core/services/location_service_test.dart` | 9개 |
| ✅ | `test/features/map/map_controller_test.dart` | 17개 |
| ✅ | `test/features/report/report_controller_test.dart` | 15개 |
| ✅ | `test/widget_test.dart` | 3개 |

### Phase 10: 실제 API 연동

**Step 1: Supabase 설정** ✅ 완료

| 상태 | 작업 |
|------|------|
| ✅ | Supabase 프로젝트 생성 (`rqlfyumzmpmhupjtroid`) |
| ✅ | PostGIS 활성화 확인 |
| ✅ | `001_initial_schema.sql` 실행 완료 — spots/reports 테이블 + RPC 2개 생성 확인 |
| ⏳ | Auth → Providers → Apple / Google / Kakao 활성화 |

**Step 2: Google 설정**

| 상태 | 작업 |
|------|------|
| ✅ | Google Cloud Console → Maps SDK for iOS + Places API 활성화 |
| ✅ | Maps API Key: `AIzaSyBw8T-8mBCtq0a4pCcqxZnPCfpInU6umro` |
| ✅ | OAuth 2.0 Web Client ID: `51820551948-59sbjv37moqvbjc58opgt3q7h3uqnu09.apps.googleusercontent.com` |
| ✅ | OAuth 2.0 iOS Client ID: `51820551948-pn564r5lmr9r65en064piv3g3sr0m86h.apps.googleusercontent.com` |
| ✅ | `ios/Runner/Info.plist` → Google reversed client ID URL scheme 추가 |
| ✅ | Google OAuth 테스트 사용자 추가 (OAuth consent screen → 대상) |
| ✅ | **Google 로그인 실기기 테스트 성공** ✅ |

**Step 3: Kakao 설정**

| 상태 | 작업 |
|------|------|
| ✅ | developers.kakao.com → 앱 등록 (ID: 1394625) |
| ✅ | 플랫폼 키 → REST API Key: `d086d7b68c346f31586d62c6352e7954` |
| ✅ | Redirect URI 등록: `https://rqlfyumzmpmhupjtroid.supabase.co/auth/v1/callback` |
| ✅ | Supabase → Auth → Providers → Kakao 설정 완료 |
| ✅ | 카카오 로그인 활성화 ON |
| ✅ | 동의항목: 닉네임(필수), 프로필 사진(선택) 활성화 |
| ✅ | Supabase `external_kakao_email_optional: true` 설정 |
| ⏳ | **`account_email` 권한 보류** — 비즈 앱 등록 필요 (카카오 KOE205 에러) |
|   | → 해결 방법: Kakao Developers → 추가 기능 신청 → 비즈 앱 전환 후 account_email 신청 |

**Step 4: Apple Sign In**

| 상태 | 작업 |
|------|------|
| — | Apple 로그인 제거됨 (browser OAuth로 통일, Google + Kakao만 사용) |

**Step 5: 통합 테스트**

| 상태 | 작업 |
|------|------|
| ✅ | Google 로그인 → Supabase 토큰 확인 (세션 유지 확인됨) |
| ✅ | 로그아웃 → `/onboarding` 자동 리다이렉트 |
| ✅ | 계정 삭제 → reports 삭제 → signOut → `/onboarding` 이동 |
| ✅ | 재로그인 후 프로필 최신 데이터 표시 (autoDispose 적용) |
| ✅ | 지도 → 커스텀 원형 마커 + 미니멀 스타일 실기기 확인 |
| ✅ | dB 측정 → 리포팅 → Supabase reports 테이블 저장 확인 (54dB STUDY 저장 완료) |

### Phase 12: UI 폴리시

| 상태 | 우선순위 | 작업 |
|------|---------|------|
| ✅ | 높음 | Google Maps Custom Style JSON 적용 (회색 배경, POI 제거, 물 SkyBlue) |
| ✅ | 높음 | 커스텀 원형 마커 (`SpotMarkerWidget.toBitmapDescriptor`) — `ui.PictureRecorder` 방식 |
| ✅ | 중간 | 지도 빈 상태 오버레이 (스팟 0개 + 로딩 완료 시) |
| ✅ | 중간 | 프로필 빈 상태 (`_EmptyReports`) — 측정 기록 없을 때 안내 |
| ✅ | 낮음 | Heatmap 모드 (줌 11~12.9) — Circle overlay (dB 색상 반경 250m) |
| ✅ | 버그 | 마커 미표시 버그 수정 — ref.listen → addPostFrameCallback + !identical() |
| ✅ | lint | app_router.dart unnecessary_underscores 수정 (flutter analyze 0 issues) |
| ✅ | 버그 | 지도 시작 시 서울 고정 → GPS 해결 시 자동 이동 (_hasMovedToUser 추가) |
| ✅ | 설정 | Supabase 프로젝트 정정: qhimbjcl → rqlfyumzmpmhupjtroid (올바른 프로젝트) |
| ✅ | 설정 | Google OAuth Web redirect URI 업데이트, Redirect URL allowlist 추가 |
| ✅ | 설정 | GRANT EXECUTE ON FUNCTION get_spots_near TO anon 적용 |
| ✅ | 기능 | 검색 기능 (Places Autocomplete) — 구현 완료 |

### Phase 12 추가 작업 (2026-02-27)

#### Google Maps API 키 교체
- [x] `places_service.dart` — defaultValue를 새 API 키로 교체
  - 구 키: `AIzaSyBw8T-8mBCtq0a4pCcqxZnPCfpInU6umro` (REQUEST_DENIED)
  - 신 키: `AIzaSyBigJrMfUqNTkMyoy_rOli5M1PRdP2YDOU` (Google Cloud "First Project")
  - Google Cloud Console → Places API 활성화 + 결제 계정 연결 완료
- [x] `ios/Runner/AppDelegate.swift` — 동일 키로 업데이트

#### 검색 기능 (Places Autocomplete) 구현
- [x] `lib/core/services/places_service.dart` — Google Places API 서비스 추가
  - `PlacePrediction` / `PlaceLatLng` 모델
  - `autocomplete(input, lat, lng)` — `/maps/api/place/autocomplete/json` REST 호출 (한국어, 국내 한정)
  - `getDetails(placeId)` — `/maps/api/place/details/json` → lat/lng 반환
  - 5초 타임아웃, debugPrint 로깅
- [x] `lib/features/map/presentation/map_screen.dart` — `_SearchBar` 자동완성 구현
  - `StatelessWidget` → `ConsumerStatefulWidget` 전환
  - 350ms 디바운스 타이머
  - `_fetchSuggestions()` → PlacesService.autocomplete() 호출
  - `_selectPrediction()` → getDetails() → `animateCamera()` + `onCameraIdle()` 재트리거
  - ListView 드롭다운 (최대 5개 결과, 구분선 포함)
- [x] `pubspec.yaml` — `http: ^1.2.0` 추가

#### Google 로그인 버그 수정 (UIScene lifecycle 딥링크 문제)
- [x] **근본 원인 파악**: 앱이 UIScene lifecycle 사용 시 URL scheme 콜백이
  `AppDelegate.application(_:open:url:options:)`가 아닌
  `SceneDelegate.scene(_:openURLContexts:)`로 전달됨.
  기존 코드에 이 포워딩이 없어 `app_links` 플러그인이 OAuth 콜백 URL을 수신하지 못함.
- [x] `ios/Runner/SceneDelegate.swift` — `scene(_:openURLContexts:)` 오버라이드 추가
  - UIScene으로 수신한 URL을 `UIApplication.shared.delegate?.application(_:open:url:options:)`로 포워딩
  - `FlutterAppDelegate` → 등록된 플러그인 → `app_links` → supabase_flutter PKCE 코드 교환 완료
- [x] `ios/Runner/AppDelegate.swift` — 불필요한 `application(_:open:url:options:)` 오버라이드 제거
  - `FlutterImplicitEngineDelegate` 방식 유지 (UIScene 앱의 표준 플러그인 등록 방식)
- [x] **Google 로그인 실기기 최종 성공** ✅
  - Supabase 로그: `handle deeplink uri` 수신 확인
  - OAuth 완료 후 `/map` 자동 이동 확인

#### Supabase 인증 정보 기본값 설정
- [x] `main.dart` — `_supabaseUrl` / `_supabaseAnonKey` defaultValue에 실제 값 하드코딩
  - `--dart-define` 없이 `flutter run`만으로 바로 실행 가능

---

### Phase 12-F: 브랜드 카페 선표시 (2026-02-27)

#### Google Places 실시간 발견
- [x] `lib/core/services/places_service.dart`
  - `PlaceResult` 클래스 추가 (placeId, name, lat, lng)
  - `nearbyBrandCafes(lat, lng, radiusMeters=3000)` — Nearby Search API, 브랜드 키워드 15개 필터
  - `_brandKeywords` 상수 (스타벅스, 투썸플레이스, 이디야, 메가커피, 할리스 등 15종)
- [x] `lib/features/map/data/spots_repository.dart`
  - `upsertBrandSpots(List<PlaceResult>)` — `ON CONFLICT DO NOTHING`, 신규 삽입 수 반환
  - `getSpotIdByPlaceId(placeId)` — google_place_id로 기존 spotId 조회
- [x] `lib/features/map/presentation/map_controller.dart`
  - `_discoveryCache = BoundsCache(ttlSeconds: 1800)` — 30분 캐시 (Google Places 비용 절감)
  - `_discoverBrandCafes(lat, lng)` — 백그라운드 발견 + upsert + 신규 추가 시 재로드
  - `onCameraIdle()` — 발견 캐시 체크 후 `unawaited(_discoverBrandCafes())` 호출

#### JSON 번들 시드
- [x] `assets/seed/brand_cafes.json` — 번들 시드 파일 (현재 빈 상태 → 스크립트로 생성)
- [x] `lib/core/services/seed_service.dart` — 앱 최초 설치 후 1회 Supabase upsert
  - SharedPreferences `brand_cafes_seed_v1` 키로 중복 실행 방지
  - `MapController.build()`에서 `unawaited(SeedService.seedIfNeeded(...))`로 호출
- [x] `scripts/generate_seed.py` — 네이버 지역검색 API로 brand_cafes.json 생성
  - 15개 브랜드 × 16개 지역 = 240 쿼리, KATECH→WGS84 좌표 변환 (mapx/mapy × 1e-7)
  - `NAVER_CLIENT_ID` / `NAVER_CLIENT_SECRET` 환경변수 필요
- [x] `pubspec.yaml` — `assets/seed/brand_cafes.json` 등록

### Phase 12-G: 검색→측정 UX 개선 (2026-02-27)

#### 검색 결과 선택 카드
- [x] `lib/features/map/presentation/map_screen.dart`
  - `_SearchBar.onPlaceSelected` 시그니처 변경: `(LatLng, String)` → `(PlacePrediction, PlaceLatLng)`
  - `_searchPrediction` / `_searchLatLng` 상태 추가
  - 검색 결과 선택 시 `_SearchPlaceCard` 표시 (장소명 + 주소 + "이 장소 측정하기" + X)
  - `_onMeasureSearchedPlace()` — DB에 placeId 스팟 있으면 spotId로, 없으면 신규 생성 경로
  - "+" FAB 제거 (무작위 위치 추가 → 검색 기반 추가로 UX 통일)
  - `_hasBottomCard` getter로 FAB / 필터바 위치 자동 조정

#### placeId/lat/lng 파라미터 추가
- [x] `lib/core/router/app_router.dart` — `placeId`, `lat`, `lng` query param → ReportScreen 전달
- [x] `lib/features/report/presentation/report_screen.dart` — `placeId`, `lat`, `lng` 옵셔널 파라미터
- [x] `lib/features/report/presentation/report_controller.dart`
  - `_googlePlaceId` 필드 + `initialize()` `googlePlaceId` 파라미터 추가
  - `submitWithSticker()` — 저장된 lat/lng 있으면 GPS 대신 사용
  - 신규 스팟 생성 시 `googlePlaceId` 전달 → `google_place_id` 컬럼 저장

### Phase 14: UI 전면 개편 (Cafe Vibe 리브랜딩) — 2026-03-01

#### Phase A: DB 마이그레이션 SQL 작성
- [x] `supabase/migrations/002_user_stats_and_rankings.sql` 작성 완료 (**Supabase 미적용 — 수동 실행 필요**)
  - `spots.formatted_address TEXT` 컬럼 추가
  - `user_profiles` 테이블 (서버 닉네임)
  - `user_stats` 테이블 (total_reports, total_cafes)
  - `update_user_stats()` RPC (report 제출 후 client 호출)
  - `get_cafe_ranking_quiet()` / `get_user_ranking()` / `get_cafe_ranking_weekly()` RPC
  - `upsert_user_profile()` / `get_my_stats()` RPC

#### Phase B: 스티커 표시명 변경
- [x] `spot_model.dart` — StickerType.label 변경 (DB값 유지, 표시명만)
  - study → '딥 포커스' 🎧, meeting → '소셜 버즈' 💬, relax → '소프트 바이브' ☕
  - `filterLabel` getter 추가

#### Phase C: 네비게이션 구조 변경 (3탭 → 4탭)
- [x] `app_router.dart` — ShellRoute에 `/explore`, `/ranking` 추가
- [x] `_MainShell` — `_BottomNav` 4탭 포함 (지도/탐색/랭킹/프로필)
- [x] `map_screen.dart` — `_BottomNav`, `_NavItem` 제거

#### Phase D: 탐색 화면 신규
- [x] `lib/features/explore/presentation/explore_screen.dart` 신규 생성
  - `_nearbySpotsProvider` — 3km 반경 자동 탐색 (`getSpotsNear` 재사용)
  - 가로 스크롤 필터칩 (전체/딥포커스/소프트바이브/소셜버즈/가까운순/인기순)
  - `_CafeListTile` — 컬러 아바타 + 카페명 + 주소 + 스티커 태그 + 측정수
  - FAB: 카페 등록 (→ /report)

#### Phase E: 랭킹 화면 신규
- [x] `lib/features/ranking/data/ranking_repository.dart` 신규 생성
  - `QuietCafeRankItem` / `UserRankItem` / `WeeklyCafeRankItem` 모델
  - `quietCafeRankingProvider` / `userRankingProvider` / `weeklyCafeRankingProvider`
- [x] `lib/features/ranking/presentation/ranking_screen.dart` 신규 생성
  - 3탭 TabController (조용한 카페 TOP / 측정왕 TOP / 이번 주 활발한 카페)
  - `_RankCard` 공통 위젯 (금/은/동 메달 배지)

#### Phase F: 프로필 화면 재설계
- [x] `lib/core/utils/level_service.dart` 신규 — `UserLevel`, `BadgeInfo`, `LevelService`
  - 레벨 임계값: [0, 5, 10, 20, 50] → Lv1~5
  - 포인트: `totalReports × 50 + totalCafes × 70`
  - 뱃지: 첫 측정 / 조용한 발견자 / 측정 5회 / 카페 탐험가
- [x] `report_model.dart` — `spotName`, `spotAddress` 필드 추가 (spots join)
- [x] `report_repository.dart` — select `spots(name, formatted_address)` + `update_user_stats()` RPC 호출
- [x] `profile_screen.dart` 전면 재설계
  - `_ProfileHeader`: 그라데이션 원형 아바타(이니셜) + 레벨칩
  - `_LevelCard`: 이모지 + 레벨명 + 프로그레스바
  - `_StatsRow`: 총 측정 + 획득 포인트
  - `_BadgeSection`: 4개 뱃지 가로 스크롤
  - `_ReportTile`: dB 배지 + 카페명 + 스티커 레이블 + 몇 분/시간 전

#### Phase G: 설정 화면 재설계
- [x] `settings_screen.dart` 전면 재설계
  - 계정 정보 / 알림 설정 토글 (UI only) / 앱 설정 / 권한 관리 / 프리미엄 배너 / 정보 / 계정 섹션
  - 로그아웃 (→ onboarding) + 회원탈퇴 (→ deleteAccount) 분리

#### 코드 품질
- [x] `flutter analyze` — **0 issues** ✅
- [x] 테스트 파일 import `package:noise_spot/` → `package:cafe_vibe/` 업데이트

---

### Phase 15: 버그 수정 & 안정화 — 2026-03-01

#### 랭킹 탭 영구 로딩 버그 수정 (근본 원인 2개)

**원인 1: `FutureProvider.autoDispose` + TabBarView 충돌**
- 탭 전환 시 provider가 dispose → 재생성 → loading 상태 반복
- 수정: **ranking providers 모두 `autoDispose` 제거** (결과를 앱 세션 동안 캐시)
- 재조회는 `_RetryView` retry 버튼 (`ref.invalidate()`) 으로만 가능

**원인 2: 존재하지 않는 RPC 함수 호출 (migration 002 미적용)**
- `get_cafe_ranking_quiet`, `get_user_ranking`, `get_cafe_ranking_weekly` RPC 없음
- Supabase 즉시 에러 → autoDispose 재생성 루프
- 수정: **RPC 완전 제거, 직접 테이블 쿼리로 대체**

#### ranking_repository.dart 완전 재작성

| 탭 | 이전 | 이후 |
|----|------|------|
| 조용한 카페 | `get_cafe_ranking_quiet` RPC | `spots` 직접 쿼리 (report_count≥3, avg_db ASC) |
| 측정왕 | `get_user_ranking` RPC | `user_stats` 직접 쿼리 + `user_profiles` 닉네임 조인 (migration 없으면 `[]`) |
| 이번 주 | `get_cafe_ranking_weekly` RPC | `reports` 7일치 직접 조회 → Dart 집계 |

- `_EmptyMeasurerView` 추가: migration 미적용 시 "랭킹 집계 준비 중" 표시

#### 프로필 화면 실데이터 연동

- `report_repository.dart getMyStats()` 확장
  - `spots(average_db)` join 추가 → `total_cafes`, `has_quiet_cafe` 반환
  - `total_cafes` = distinct spot_id 개수
  - `has_quiet_cafe` = average_db < 50인 카페 방문 기록 여부
- `profile_screen.dart`
  - `totalCafes`, `hasQuietCafe` 하드코딩(0/false) → 실데이터 사용
  - `LevelService.calcPoints(total, totalCafes)` — 포인트 공식 반영
  - `_BadgeSection` 뱃지 잠금 실제 조건으로 해제 ("조용한 발견자", "카페 탐험가")
  - `_StatsRow` 2열 → 3열: 총 측정 / 등록 카페 / 획득 포인트

#### update_user_stats() Crash 방지
- `report_repository.dart submitReport()` 마지막 RPC 호출 try-catch 처리
  - migration 002 미적용 → RPC 없음 → 예외 → **리포트 제출 전체 실패** 버그 수정
  - 이제 리포트 삽입 + EMA 갱신은 성공, stats 갱신은 조용히 skip

---

### Phase 16: 지도 카페 발견 시스템 — 2026-03-01

#### nearbyCafes() — 브랜드 무관 전체 카페 발견
- [x] `lib/core/services/places_service.dart`
  - `PlaceResult`에 `formattedAddress: String?` 필드 추가
  - `nearbyCafes(lat, lng, radiusMeters=3000)` 추가 — 브랜드 필터 없음, `type=cafe` 페이지네이션 3페이지(2초 딜레이), `vicinity` → `formattedAddress`
  - lint 수정: `'pagetoken': ?pageToken`, 불필요한 string interpolation 중괄호 제거
- [x] `lib/features/map/data/spots_repository.dart`
  - `upsertBrandSpots()` — `formattedAddress != null`이면 `formatted_address` 컬럼 포함
- [x] `lib/features/map/presentation/map_controller.dart`
  - `_discoverBrandCafes()` → `_discoverNearbyCafes()` 이름 변경
  - `nearbyCafes()` 사용 (브랜드 15종 필터 제거)
  - `_initLocation()`에서 GPS 확정 후 `unawaited(_discoverNearbyCafes())` 즉시 호출

#### DB 수정 — Migration 003
- [x] `supabase/migrations/003_fix_place_id_constraint.sql` 신규
  - `idx_spots_place_id` partial index 제거 → `ON CONFLICT (google_place_id)` 작동 불가 원인
  - `spots_google_place_id_key` UNIQUE 제약 추가 (partial → full UNIQUE으로 교체)
  - `spots_insert_anon` RLS 정책 추가 (`FOR INSERT TO anon WITH CHECK (true)`)
    - 원인: `MapController.build()` 시 익명 인증 세션 미확립 → anon role → 기존 `spots_insert_auth` 정책이 authenticated만 허용하여 42501 RLS 에러
- [x] `supabase db push` 로 migration 003 적용 완료

#### BoundsCache 제거 — 마커 사라짐 버그
- [x] `lib/features/map/presentation/map_controller.dart`
  - `_boundsCache = BoundsCache()` 완전 제거
  - `onCameraIdle()` — bounds cache 체크 없이 매번 `_loadSpots()` 호출
  - `setFilter()` / `refreshLocation()`에서 `_boundsCache.clear()` 제거
  - **원인**: pan → 다른 영역 → spots 대체 → 원래 영역 복귀 시 캐시 hit → `_loadSpots()` 건너뜀 → 빈 state 유지
  - PostGIS 쿼리 속도가 충분히 빠르므로 캐시 불필요

---

### Phase 17: 리포트 버그 수정 — 2026-03-01

#### 근접성 검증 미작동 버그 (2개소)
**버그 1: SpotInfoCard → report 라우트에 lat/lng 누락**
- `map_screen.dart` line 217: `onReport` 콜백에 `&lat=&lng=` 미포함 → `_spotLat/Lng = null` → `verifyProximity()` 조기 반환 `true`
- [x] `&lat=${_selectedSpot!.lat}&lng=${_selectedSpot!.lng}` 추가

**버그 2: 검색 → 기존 스팟 경로에 lat/lng 누락**
- `map_screen.dart` `_onMeasureSearchedPlace()`: `existingSpotId != null` 분기에서 lat/lng 미전달
- [x] `&lat=${latLng.lat}&lng=${latLng.lng}` 추가 (latLng 파라미터 이미 있음)

#### 이전 측정 결과 유지 버그
- **원인**: `reportControllerProvider`는 전역 `NotifierProvider` — `build()` 1회 호출, `initialize()`가 state.phase를 초기화하지 않음
- [x] `report_controller.dart initialize()` — `_stopMeasurement()` + `state = const ReportState()` 추가

#### 근접성 거리 조정
- [x] `map_constants.dart` `reportMaxDistanceMeters`: 100.0 → 25.0 (최종)

---

### Phase 13: App Store 출시 준비

| 상태 | 작업 |
|------|------|
| ✅ | 개인정보처리방침 HTML 작성 (`docs/privacy-policy.html`) — GitHub Pages 배포 예정 |
| ✅ | IPA 빌드 성공 (`flutter build ipa`) |
| ✅ | GitHub Pages 활성화 — `moonkj.github.io/Noise-Spot/docs/privacy-policy.html` |
| ⏳ | App Store Connect — 앱 정보 입력 (한국어/영어) |
| ⏳ | 스크린샷 — 6.7" / 6.5" / 5.5" (지도, 리포팅, 프로필 화면) |
| ✅ | IPA 빌드 성공 — `build/ios/ipa/*.ipa` (57.9MB) |
| ⏳ | Transporter로 TestFlight 업로드 → 내부 테스트 → 심사 제출 |

---

## 알려진 이슈 & 참고사항

### 1. ~~app_router.dart `part` 지시어~~ ✅ 해결됨
`part 'app_router.g.dart';` 불필요한 줄 제거 완료 (go_router codegen 미사용)

### 2. ~~Riverpod 3.x 마이그레이션~~ ✅ 완전 해결됨
- `StateNotifier` → `Notifier<S>`, `StateNotifierProvider` → `NotifierProvider<N, S>`
- `StateProvider<ReportArgs?>` 제거 → `ReportController.initialize()` 메서드로 대체
- `ReportArgs` 클래스 제거, `_spotId`/`_spotLat`/`_spotLng` 인스턴스 필드 사용

### 3. ~~`flutter analyze` 74개 오류~~ ✅ 0 issues 달성 (2026-02-27)
- `CardTheme` → `CardThemeData`
- `background` deprecated → 제거
- `withOpacity()` → `withValues(alpha:)` (8개 파일)
- 미사용 import 제거 (`cupertino.dart`, `dart:ui`, `rendering.dart`)
- `unnecessary_brace_in_string_interps` 수정

### 4. ~~noise_filter.dart stddev 버그~~ ✅ 수정됨 (2026-02-27)
```dart
// 수정 전 (bug): final stddev = variance == 0 ? 1.0 : variance;
// 수정 후: final stddev = variance == 0 ? 1.0 : sqrt(variance);
```
- `dart:math show sqrt` import 추가

### 5. ~~Google Sign-In Client ID 미설정~~ ✅ 해결됨
- google_sign_in 패키지 제거, browser OAuth (`signInWithOAuth`)로 전환
- iOS reversed client ID URL scheme: `com.googleusercontent.apps.51820551948-pn564r5lmr9r65en064piv3g3sr0m86h` → Info.plist 등록 완료
- Google 로그인 실기기 성공 확인

### 6. Kakao / Google OAuth — MVP 이후 보류
- 익명 인증 모델로 전환하면서 OAuth 로그인 UI 제거됨
- 필요 시 `auth_repository.dart`에 `signInWithKakao()` / `signInWithGoogle()` 재추가 가능
- Kakao KOE205 (`account_email` 권한) 이슈는 비즈 앱 전환 후 해결 가능

### 11. Supabase 익명 인증 활성화 필수 ⚠️
- **현상**: `signInAnonymously()` 실패 → 리포트 제출 불가 (Supabase RLS)
- **해결**: Supabase 대시보드 → Authentication → Providers → **Anonymous Sign-Ins → Enable**
- 지도 탐색은 anon 인증 없이도 동작 (get_spots_near GRANT TO anon 적용됨)

### 10. 시드 데이터 미생성 (요청 시 처리)
- `assets/seed/brand_cafes.json` 현재 빈 파일 (`"spots": []`)
- **해결**: 네이버 클라우드 플랫폼 검색 API 발급 후 `python3 scripts/generate_seed.py` 실행
  - URL: https://developers.naver.com/apps/#/register → 검색 API → 지역 선택
  - `export NAVER_CLIENT_ID=xxx NAVER_CLIENT_SECRET=yyy && python3 scripts/generate_seed.py`
- 시드 없이도 Google Places 실시간 발견으로 브랜드 카페가 자동 추가됨 (지도 이동 시)

### 8. SpotInfoCard Lazy Loading
- 현재 마커 탭 시 이미 로드된 SpotModel 데이터만 표시
- 상세 정보(오늘 방문자 수, 1시간 평균 dB)는 추가 RPC 호출 필요
- 향후 `get_spot_detail(spot_id)` RPC 추가 권장

### 9. 구글 지도 Custom Style
- 현재 기본 지도 스타일 사용
- 미니멀 Custom Map Style JSON 적용 권장 (연한 회색 배경, POI 최소화)
- Google Cloud Console → Map Styles에서 JSON 생성 후 `GoogleMap(style:)` 파라미터 적용

---

## 빠른 시작 명령어

```bash
# 프로젝트 디렉토리
cd "/Users/kjmoon/Noise Spot/noise_spot"

# 의존성 설치
flutter pub get

# iOS 시뮬레이터 실행
flutter run -d "iPhone 16 Pro"

# 분석 (lint 체크)
flutter analyze

# 단위 테스트 실행
flutter test test/core/utils/

# 전체 테스트 실행
flutter test

# 아이콘 생성 (assets/icon/app_icon.png 추가 후)
dart run flutter_launcher_icons

# 실기기 릴리즈 빌드 & 설치 (iPhone "Moon")
flutter run --release \
  -d 00008150-001128391EF0401C \
  --dart-define=SUPABASE_URL=https://rqlfyumzmpmhupjtroid.supabase.co \
  "--dart-define=SUPABASE_ANON_KEY=<your_anon_key>"

# iOS 빌드
flutter build ios \
  --dart-define=SUPABASE_URL=https://rqlfyumzmpmhupjtroid.supabase.co \
  "--dart-define=SUPABASE_ANON_KEY=<your_anon_key>"

# ─── iOS 26 beta 실기기 설치 워크어라운드 ─────────────────────────────────────
# flutter run CoreDevice 3002 오류 시 → xcrun devicectl 사용
# DEVICE_ID: 00008150-001128391EF0401C  (iPhone "Moon")

# 1. 빌드 (위 flutter build ios 명령어 먼저 실행)

# 2. 설치
xcrun devicectl device install app \
  --device 835A5E84-05B4-520C-B52C-E69BBEE38FED \
  build/ios/iphoneos/Runner.app

# 3. 실행
xcrun devicectl device process launch \
  --device 835A5E84-05B4-520C-B52C-E69BBEE38FED \
  com.cafevibe.cafeVibe
```

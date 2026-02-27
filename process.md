# Noise Spot — 개발 진행 현황 (Process Log)

마지막 업데이트: 2026-02-27 (브랜드 카페 선표시 ✅, 검색→측정 UX 개선 ✅, JSON 시드 인프라 ✅)

---

## 전체 진행률

```
Phase 1: 프로젝트 초기화     ████████████ 100% ✅
Phase 2: Core 레이어         ████████████ 100% ✅
Phase 3: Auth Feature         ████████████ 100% ✅
Phase 4: Map Feature          ████████████ 100% ✅
Phase 5: Report Feature       ████████████ 100% ✅
Phase 6: Profile Feature      ████████████ 100% ✅
Phase 7: Settings Feature     ████████████ 100% ✅
Phase 8: DB 마이그레이션      ████████████ 100% ✅
Phase 9: 테스트               ████████████ 100% ✅ (71/71 통과)
Phase 10: 실제 API 연동       ████████████ 100% ✅
Phase 11: 앱 아이콘 & 빌드    ████████████ 100% ✅
Phase 12: UI 폴리시           ████████████ 100% ✅ (마커버그수정 ✅, lint 0 ✅, 검색은 MVP이후)
```

---

## ✅ 완료된 작업

### Phase 1: 프로젝트 초기화
- [x] `flutter create noise_spot --org com.noisespot --platforms ios` 실행
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
  - `CFBundleURLTypes` — URL Scheme `com.noisespot.noisespot` (Supabase OAuth 딥링크)

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
- [x] `auth_repository.dart` — Supabase Auth Kakao/Google OAuth (browser 방식)
  - `signInWithKakao()` — `OAuthProvider.kakao` + `redirectTo` + `LaunchMode.externalApplication`
  - `signInWithGoogle()` — `OAuthProvider.google` + `redirectTo` + `LaunchMode.externalApplication`
  - Apple 로그인 제거 (sign_in_with_apple → browser OAuth로 통일)
  - google_sign_in 패키지 제거 (nonce 불일치 이슈로 browser OAuth 전환)
- [x] `onboarding_screen.dart` — 그라데이션 배경, 로그인 버튼 2종
  - 카카오 (노란색 #FEE500, 검정 텍스트) — 첫 번째
  - Google (아웃라인, 커스텀 G 아이콘)
  - `didChangeDependencies()` — authStateProvider 리스너로 OAuth 콜백 감지 → `/map` 이동
- [x] `app_router.dart` — 인증 상태 기반 자동 리다이렉트 추가
  - 로그인 상태 → 앱 실행 시 바로 `/map` (온보딩 스킵)
  - 로그아웃 → 자동으로 `/onboarding` 복귀
  - `refreshListenable`: authStateProvider 변경 감지
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
  - 총 리포트 수 / 평균 dB 통계 카드
  - Trust Grade 카드 (Bronze/Silver/Gold 진행률 바)
  - 방문 기록 리스트 (스티커 + dB + 날짜)

### Phase 7: Settings Feature
- [x] `settings_screen.dart`
  - 개인정보 처리방침 카드 (강조 표시)
  - 마이크/위치 권한 상태 표시 + 관리 버튼
  - 로그아웃 / 계정 삭제 (실제 구현 완료)

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
- [x] `assets/icon/app_icon.png` 저장 완료 (1024×1024 PNG)
  - 생성 스크립트: `/tmp/draw_icon_v9.py` (aggdraw AGG 라이브러리 사용)
  - **4개 불규칙 노이즈 스파이크**: tiny burst (±45px) / tall sharp (±190px) / medium double-top (±130px) / medium-tall (±165px)
  - **선 두께**: 27px (1024px 기준) — aggdraw Pen으로 완벽한 안티앨리어싱
  - **렌더링**: 2048px 그린 후 Lanczos 1024px 다운스케일 (슈퍼샘플링)
  - **배경**: Mint(168,230,207) 좌하 → SkyBlue(135,206,235) 우상 대각선 그라데이션
  - **흰 원**: center(887,455), r=55 (1024px 기준)
- [x] `dart run flutter_launcher_icons` 실행 — 전체 iOS 아이콘 사이즈 자동 생성
- [x] iPhone "Moon" (iOS 26 beta) 재설치 성공 (아이콘 반영 확인)

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
  xcrun devicectl device process launch --device DEVICE_ID com.noisespot.noiseSpot
  ```

---

## ⏳ 남은 작업

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

### Phase 13: App Store 출시 준비

| 상태 | 작업 |
|------|------|
| ⏳ | App Store Connect — 앱 정보 입력 (한국어/영어) |
| ⏳ | 스크린샷 — 6.7" / 6.5" / 5.5" (지도, 리포팅, 프로필 화면) |
| ⏳ | 개인정보처리방침 URL (간단한 웹페이지 필요) |
| ⏳ | TestFlight 내부 테스트 → 외부 테스트 → 심사 제출 |

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

### 6. Kakao KOE205 에러 — 비즈 앱 등록 보류
- **현상**: `account_email` scope 권한 없음 → Kakao가 요청 자체를 거부
- **원인**: 개인 앱은 `account_email` 사용 불가, 비즈 앱 전환 필요
- **해결 방법**: Kakao Developers → 앱 설정 → 추가 기능 신청 → 비즈 앱 등록 후 account_email 권한 신청
- **임시 상태**: 카카오 버튼은 UI에 유지, 로그인 시 KOE205 에러 발생
- **우회**: Google 로그인으로 테스트 가능

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
  com.noisespot.noiseSpot
```

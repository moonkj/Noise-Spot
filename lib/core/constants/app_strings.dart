class AppStrings {
  AppStrings._();

  // App Info
  static const String appName = 'Cafe Vibe';
  static const String appSlogan = '시끄러운 도시 속, 나만의 고요한 카페 찾기';

  // Privacy — fixed notice (displayed on all measurement & settings screens)
  static const String privacyNoticeMeasure =
      '음성은 저장되지 않으며 소음 수치(dB)만 기록됩니다.';
  static const String privacyNoticeSettings =
      '소음은 수치(dB)만 추출하며 절대 저장되지 않습니다.';

  // Onboarding
  // Onboarding — login buttons
  static const String loginWithKakao = '카카오로 로그인';
  static const String loginWithGoogle = 'Google로 로그인';

  // Map Filters (DB keys — unchanged)
  static const String filterStudy = 'STUDY';
  static const String filterMeeting = 'MEETING';
  static const String filterRelax = 'RELAX';

  // Sticker Labels (새 Cafe Vibe 브랜딩)
  static const String stickerStudyLabel = '딥 포커스';
  static const String stickerMeetingLabel = '소셜 버즈';
  static const String stickerRelaxLabel = '소프트 바이브';

  // Explore screen
  static const String exploreTitle = '탐색';
  static const String exploreFilterAll = '전체';
  static const String exploreSortNearest = '가까운순';
  static const String exploreSortPopular = '인기순';
  static const String exploreAddCafe = '카페 등록';
  static const String exploreEmpty = '주변 3km 내 카페가 없어요';
  static String exploreCafeCount(int count) => '$count개의 카페';

  // Ranking screen
  static const String rankingTitle = '랭킹';
  static const String rankingTabQuiet = '잔잔한 카페 TOP';
  static const String rankingTabMeasurers = '바이브 탐험가 TOP';
  static const String rankingTabWeekly = '이번 주 인기 바이브 카페';

  // Level names (Lv.1 ~ Lv.10, XP-based)
  static const List<String> levelNames = [
    '바이브 비기너',      // Lv.1  (0 XP)
    '바이브 루키',        // Lv.2  (30 XP)
    '바이브 헌터',        // Lv.3  (80 XP)
    '바이브 탐험가',      // Lv.4  (160 XP)
    '바이브 큐레이터',    // Lv.5  (280 XP)
    '바이브 감정사',      // Lv.6  (450 XP)
    '바이브 소믈리에',    // Lv.7  (700 XP)
    '바이브 마스터',      // Lv.8  (1050 XP)
    '바이브 그랜드마스터', // Lv.9  (1500 XP)
    '바이브 레전드',      // Lv.10 (2100 XP)
  ];

  // Level icons (parallel to levelNames)
  static const List<String> levelIcons = [
    '🌱', // Lv.1  비기너    — 새싹, 막 시작한 탐험
    '📡', // Lv.2  루키      — 바이브 신호 포착 시작
    '🔍', // Lv.3  헌터      — 조용한 카페 찾아다님
    '🧭', // Lv.4  탐험가    — 나침반, 방향을 개척
    '📋', // Lv.5  큐레이터  — 데이터 정리·큐레이션
    '🎯', // Lv.6  감정사    — 정확한 바이브 감정
    '☕', // Lv.7  소믈리에  — 커피 향처럼 섬세한 귀
    '🎧', // Lv.8  마스터    — 소음 마스터
    '👑', // Lv.9  그랜드마스터 — 왕관
    '✨', // Lv.10 레전드    — 빛나는 전설
  ];

  // dB Labels
  static const String dbVeryQuiet = '마음이 내려앉는 고요';
  static const String dbQuiet = '편안히 머물기 좋은 소리';
  static const String dbModerate = '기분 좋은 활기가 도는';
  static const String dbLoud = '대화가 겹치는 소란함';
  static const String dbVeryLoud = '귀와 머리가 붕 뜨는 소음';

  // Reporting
  static const String reportTooFar =
      '카페 50m 이내에서만 리포팅 가능합니다.';
  static const String reportBackground =
      '앱이 활성화된 상태에서만 측정 가능합니다.';
  static const String reportInvalidDb = '측정값이 유효하지 않습니다.';
  static const String reportSuccess = '리포트가 등록되었습니다!';
  static const String measuring = '측정 중...';
  static const String measureStabilizing = '3초 안정화 중...';

  // Proximity dialogs
  static const String proximityDialogTitle = '위치 확인 필요';
  static const String proximityDialogMeasure =
      '카페 50m 이내에서만 측정 가능합니다.\n카페 근처로 이동해 주세요.\n\n💡 카페 안에서는 GPS 신호가 유리·벽에 반사되어 위치가 다르게 잡힐 수 있어요.';
  static const String proximityDialogSubmit =
      '카페 50m 이내에서만 리포팅 가능합니다.\n카페 근처로 이동 후 다시 시도해 주세요.\n\n💡 카페 안에서는 GPS 신호가 유리·벽에 반사되어 위치가 다르게 잡힐 수 있어요.';

  // Calibration
  static const String calibrationTitle = '마이크 초기 설정';
  static const String calibrationDesc = '3초간 주변 소음을 측정해 기기를 최적화합니다.';

  // Trust Score
  static const String trustBronze = 'Bronze';
  static const String trustSilver = 'Silver';
  static const String trustGold = 'Gold';

  // Profile
  static const String totalReports = '총 리포트';
  static const String avgDb = '평균 dB';
  static const String quietestSpot = '가장 조용한 스팟';

  // Settings
  static const String micPermission = '마이크 권한';
  static const String locationPermission = '위치 권한';
  static const String privacyPolicy = '개인정보 처리방침';
  static const String logout = '로그아웃';
  static const String deleteAccount = '계정 삭제';

  // Data Freshness
  static const String dataInsufficient = '데이터 부족';
  static const String dataStale = '오래된 정보';

  // Social Proof
  static String recentReports(int count) => '최근 30분 $count명 리포팅';
  static String todayVisitors(int count) => '오늘 방문자 $count명';
  static String lastHourAvg(String db) => '최근 1시간 평균 ${db}dB';
}

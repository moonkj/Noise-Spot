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
  static const String rankingTabQuiet = '조용한 카페 TOP';
  static const String rankingTabMeasurers = '측정왕 TOP';
  static const String rankingTabWeekly = '이번 주 활발한 카페';

  // Level names
  static const List<String> levelNames = [
    '카페 탐험가',   // Lv.1
    '소음 감지사',   // Lv.2
    '카페 고수',     // Lv.3
    '카페 마스터',   // Lv.4
    '카페온도 레전드', // Lv.5
  ];

  // dB Labels
  static const String dbVeryQuiet = '매우 조용';
  static const String dbQuiet = '조용함';
  static const String dbModerate = '보통';
  static const String dbLoud = '시끄러움';
  static const String dbVeryLoud = '매우 시끄러움';

  // Reporting
  static const String reportTooFar =
      '카페 25m 이내에서만 리포팅 가능합니다.';
  static const String reportBackground =
      '앱이 활성화된 상태에서만 측정 가능합니다.';
  static const String reportInvalidDb = '측정값이 유효하지 않습니다.';
  static const String reportSuccess = '리포트가 등록되었습니다!';
  static const String measuring = '측정 중...';
  static const String measureStabilizing = '3초 안정화 중...';

  // Proximity dialogs
  static const String proximityDialogTitle = '위치 확인 필요';
  static const String proximityDialogMeasure =
      '카페 25m 이내에서만 측정 가능합니다.\n카페 근처로 이동해 주세요.';
  static const String proximityDialogSubmit =
      '카페 25m 이내에서만 리포팅 가능합니다.\n카페 근처로 이동 후 다시 시도해 주세요.';

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

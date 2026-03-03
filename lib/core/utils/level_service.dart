import '../constants/app_strings.dart';

// ──────────────────────────────────────────────────────────────
// Badge Category
// ──────────────────────────────────────────────────────────────

enum BadgeCategory {
  firstExperience,
  consistency,
  exploration,
  vibeDetection,
  timeContext,
  community,
}

extension BadgeCategoryX on BadgeCategory {
  String get label => const {
    BadgeCategory.firstExperience: '첫 바이브',
    BadgeCategory.consistency:    '꾸준함',
    BadgeCategory.exploration:    '탐험',
    BadgeCategory.vibeDetection:  '바이브 감별',
    BadgeCategory.timeContext:    '시간대 & 상황',
    BadgeCategory.community:      '기여 & 커뮤니티',
  }[this]!;

  String get emoji => const {
    BadgeCategory.firstExperience: '🌟',
    BadgeCategory.consistency:     '📅',
    BadgeCategory.exploration:     '🗺️',
    BadgeCategory.vibeDetection:   '🎵',
    BadgeCategory.timeContext:     '⏰',
    BadgeCategory.community:       '🤝',
  }[this]!;
}

// ──────────────────────────────────────────────────────────────
// BadgeInfo
// ──────────────────────────────────────────────────────────────

class BadgeInfo {
  final String id;          // 'B01' … 'B30'
  final String emoji;
  final String label;
  final String condition;   // displayed description
  final int xpReward;
  final BadgeCategory category;
  final bool unlocked;

  const BadgeInfo({
    required this.id,
    required this.emoji,
    required this.label,
    required this.condition,
    required this.xpReward,
    required this.category,
    required this.unlocked,
  });

  BadgeInfo copyWith({bool? unlocked}) => BadgeInfo(
    id: id,
    emoji: emoji,
    label: label,
    condition: condition,
    xpReward: xpReward,
    category: category,
    unlocked: unlocked ?? this.unlocked,
  );
}

// ──────────────────────────────────────────────────────────────
// BadgeStats — all computed data needed to evaluate 30 badges
// ──────────────────────────────────────────────────────────────

class BadgeStats {
  final int totalReports;
  final int totalCafes;
  final bool hasFirstMemo;           // tag_text != null at least once
  final bool hasFirstSticker;        // selected_sticker != null at least once
  final int maxStreakDays;           // max consecutive report days
  final bool monthIn20Reports;       // 20+ reports in any calendar month
  final int maxNeighborhoodCafes;    // max distinct spots in same district
  final int maxFranchiseCafes;       // max distinct spots of same chain
  final int indieCafeCount;          // non-franchise spots
  final int firstReporterCount;      // spots where user was first to measure
  final int uniqueCityCount;         // distinct cities in spot addresses
  final int quietCafe50Count;        // spots with avg_db < 50
  final int goldenCafeCount;         // spots with avg_db 50–65
  final int highCafeCount;           // spots with avg_db > 70
  final int quietSpotMeasuredCount;  // distinct spots user measured < 50 dB
  final int midSpotMeasuredCount;    // distinct spots user measured 50–70 dB
  final int loudSpotMeasuredCount;   // distinct spots user measured > 70 dB
  final int veryQuietCafe40Count;    // spots with avg_db < 40
  final Map<String, int> dbRangeSpotCount; // key: '<40','40-55','55-70','70-85','85+'
  final int morningReportCount;      // reports before 9 AM
  final int nightReportCount;        // reports at or after 9 PM
  final int weekendReportCount;      // reports on Sat/Sun
  final int maxCafesOneDay;          // max distinct spots in one calendar day
  final int totalStickerCount;       // reports with sticker selected
  final int memoReportCount;         // reports with tag_text
  final int uniqueDistrictCount;     // distinct districts (구) explored

  const BadgeStats({
    required this.totalReports,
    required this.totalCafes,
    required this.hasFirstMemo,
    required this.hasFirstSticker,
    required this.maxStreakDays,
    required this.monthIn20Reports,
    required this.maxNeighborhoodCafes,
    required this.maxFranchiseCafes,
    required this.indieCafeCount,
    required this.firstReporterCount,
    required this.uniqueCityCount,
    required this.quietCafe50Count,
    required this.goldenCafeCount,
    required this.highCafeCount,
    required this.quietSpotMeasuredCount,
    required this.midSpotMeasuredCount,
    required this.loudSpotMeasuredCount,
    required this.veryQuietCafe40Count,
    required this.dbRangeSpotCount,
    required this.morningReportCount,
    required this.nightReportCount,
    required this.weekendReportCount,
    required this.maxCafesOneDay,
    required this.totalStickerCount,
    required this.memoReportCount,
    required this.uniqueDistrictCount,
  });

  factory BadgeStats.empty() => const BadgeStats(
    totalReports: 0,
    totalCafes: 0,
    hasFirstMemo: false,
    hasFirstSticker: false,
    maxStreakDays: 0,
    monthIn20Reports: false,
    maxNeighborhoodCafes: 0,
    maxFranchiseCafes: 0,
    indieCafeCount: 0,
    firstReporterCount: 0,
    uniqueCityCount: 0,
    quietCafe50Count: 0,
    goldenCafeCount: 0,
    highCafeCount: 0,
    quietSpotMeasuredCount: 0,
    midSpotMeasuredCount: 0,
    loudSpotMeasuredCount: 0,
    veryQuietCafe40Count: 0,
    dbRangeSpotCount: {},
    morningReportCount: 0,
    nightReportCount: 0,
    weekendReportCount: 0,
    maxCafesOneDay: 0,
    totalStickerCount: 0,
    memoReportCount: 0,
    uniqueDistrictCount: 0,
  );
}

// ──────────────────────────────────────────────────────────────
// UserLevel
// ──────────────────────────────────────────────────────────────

class UserLevel {
  final int level;       // 1~10
  final String name;     // 바이브 비기너 등
  final String icon;     // 레벨 아이콘 (이모지)
  final int currentXp;   // 누적 XP
  final int nextTarget;  // 다음 레벨 누적 XP 목표 (-1 if max)
  final double progress; // 0.0~1.0 (구간 내 진행률)

  const UserLevel({
    required this.level,
    required this.name,
    required this.icon,
    required this.currentXp,
    required this.nextTarget,
    required this.progress,
  });

  bool get isMax => level >= 10;
}

// ──────────────────────────────────────────────────────────────
// LevelService
// ──────────────────────────────────────────────────────────────

abstract class LevelService {
  /// Cumulative XP thresholds for Lv1~Lv10
  static const _xpThresholds = [0, 30, 80, 160, 280, 450, 700, 1050, 1500, 2100];

  static const int xpPerReport = 10;
  static const int xpNewCafe = 5;

  static UserLevel calcLevel(int totalXp) {
    int lv = 1;
    for (int i = _xpThresholds.length - 1; i >= 0; i--) {
      if (totalXp >= _xpThresholds[i]) {
        lv = i + 1;
        break;
      }
    }
    lv = lv.clamp(1, 10);

    final int nextTarget;
    final double progress;

    if (lv >= 10) {
      nextTarget = -1;
      progress = 1.0;
    } else {
      final levelStart = _xpThresholds[lv - 1];
      final levelEnd = _xpThresholds[lv];
      nextTarget = levelEnd;
      progress = ((totalXp - levelStart) / (levelEnd - levelStart)).clamp(0.0, 1.0);
    }

    return UserLevel(
      level: lv,
      name: AppStrings.levelNames[lv - 1],
      icon: AppStrings.levelIcons[lv - 1],
      currentXp: totalXp,
      nextTarget: nextTarget,
      progress: progress,
    );
  }

  /// Evaluate all 30 badges.
  ///
  /// [earnedIds]: badge IDs already recorded in user_badges (from Supabase).
  /// Used for:
  ///   - Server-granted badges (B30)
  ///   - Instant-award badges triggered by UI events (B04, B29)
  ///   - Ensuring already-earned badges stay unlocked even if stats regressed
  static List<BadgeInfo> calcBadges(BadgeStats s, Set<String> earnedIds) {
    // Helper: unlocked if condition is true OR badge was previously earned
    bool e(String id, bool condition) => condition || earnedIds.contains(id);

    return [
      // ── Cat 1: 첫 경험 (B01–B04) ──────────────────────────
      BadgeInfo(
        id: 'B01', emoji: '🔰', label: '데시벨 입문자',
        condition: '첫 번째 바이브 측정 완료', xpReward: 5,
        category: BadgeCategory.firstExperience,
        unlocked: e('B01', s.totalReports >= 1),
      ),
      BadgeInfo(
        id: 'B02', emoji: '📝', label: '첫 발자국',
        condition: '첫 카페 리뷰/메모 작성', xpReward: 5,
        category: BadgeCategory.firstExperience,
        unlocked: e('B02', s.hasFirstMemo),
      ),
      BadgeInfo(
        id: 'B03', emoji: '🌱', label: '태그 데뷔',
        condition: '첫 태그 스티커 선택', xpReward: 5,
        category: BadgeCategory.firstExperience,
        unlocked: e('B03', s.hasFirstSticker),
      ),
      BadgeInfo(
        id: 'B04', emoji: '📍', label: '지도 위의 나',
        condition: '카페 상세 페이지 첫 방문', xpReward: 5,
        category: BadgeCategory.firstExperience,
        unlocked: earnedIds.contains('B04'), // instant-award only
      ),

      // ── Cat 2: 꾸준함 (B05–B10) ───────────────────────────
      BadgeInfo(
        id: 'B05', emoji: '📊', label: '측정 5회',
        condition: '누적 5회 이상 측정', xpReward: 5,
        category: BadgeCategory.consistency,
        unlocked: e('B05', s.totalReports >= 5),
      ),
      BadgeInfo(
        id: 'B06', emoji: '🔥', label: '바이브 루틴',
        condition: '3일 연속 측정', xpReward: 10,
        category: BadgeCategory.consistency,
        unlocked: e('B06', s.maxStreakDays >= 3),
      ),
      BadgeInfo(
        id: 'B07', emoji: '📆', label: '위클리 체커',
        condition: '7일 연속 측정', xpReward: 10,
        category: BadgeCategory.consistency,
        unlocked: e('B07', s.maxStreakDays >= 7),
      ),
      BadgeInfo(
        id: 'B08', emoji: '🗓️', label: '한 달의 기록',
        condition: '한 달간 20회 이상 측정', xpReward: 20,
        category: BadgeCategory.consistency,
        unlocked: e('B08', s.monthIn20Reports),
      ),
      BadgeInfo(
        id: 'B09', emoji: '⚡', label: '바이브 스트리커',
        condition: '30일 연속 측정', xpReward: 50,
        category: BadgeCategory.consistency,
        unlocked: e('B09', s.maxStreakDays >= 30),
      ),
      BadgeInfo(
        id: 'B10', emoji: '💯', label: '100회 돌파',
        condition: '누적 측정 100회', xpReward: 50,
        category: BadgeCategory.consistency,
        unlocked: e('B10', s.totalReports >= 100),
      ),

      // ── Cat 3: 탐험 (B11–B16) ─────────────────────────────
      BadgeInfo(
        id: 'B11', emoji: '🧭', label: '카페 탐험가',
        condition: '2곳 이상 카페 방문', xpReward: 5,
        category: BadgeCategory.exploration,
        unlocked: e('B11', s.totalCafes >= 2),
      ),
      BadgeInfo(
        id: 'B12', emoji: '🏘️', label: '동네 바이브 지도',
        condition: '같은 동·구에서 5곳 측정', xpReward: 10,
        category: BadgeCategory.exploration,
        unlocked: e('B12', s.maxNeighborhoodCafes >= 5),
      ),
      BadgeInfo(
        id: 'B13', emoji: '☕', label: '체인 헌터',
        condition: '같은 프랜차이즈 5지점 측정', xpReward: 10,
        category: BadgeCategory.exploration,
        unlocked: e('B13', s.maxFranchiseCafes >= 5),
      ),
      BadgeInfo(
        id: 'B14', emoji: '🎨', label: '인디 감성 수집가',
        condition: '개인 카페(비프랜차이즈) 10곳 측정', xpReward: 20,
        category: BadgeCategory.exploration,
        unlocked: e('B14', s.indieCafeCount >= 10),
      ),
      BadgeInfo(
        id: 'B15', emoji: '🚀', label: '개척자',
        condition: '아무도 측정 안 한 카페 3곳 최초 기록', xpReward: 20,
        category: BadgeCategory.exploration,
        unlocked: e('B15', s.firstReporterCount >= 3),
      ),
      BadgeInfo(
        id: 'B16', emoji: '🌏', label: '도시 정복자',
        condition: '서로 다른 3개 도시에서 측정', xpReward: 50,
        category: BadgeCategory.exploration,
        unlocked: e('B16', s.uniqueCityCount >= 3),
      ),
      BadgeInfo(
        id: 'B31', emoji: '🗺️', label: '지역 탐험가',
        condition: '서로 다른 3개 동네에서 측정', xpReward: 15,
        category: BadgeCategory.exploration,
        unlocked: e('B31', s.uniqueDistrictCount >= 3),
      ),
      BadgeInfo(
        id: 'B32', emoji: '🏙️', label: '서울 탐험가',
        condition: '서로 다른 8개 동네에서 측정', xpReward: 30,
        category: BadgeCategory.exploration,
        unlocked: e('B32', s.uniqueDistrictCount >= 8),
      ),

      // ── Cat 4: 바이브 감별 (B17–B22) ─────────────────────
      BadgeInfo(
        id: 'B17', emoji: '🤫', label: '조용한 발견자',
        condition: '평균 50dB 미만 카페 발견', xpReward: 10,
        category: BadgeCategory.vibeDetection,
        unlocked: e('B17', s.quietCafe50Count >= 1),
      ),
      BadgeInfo(
        id: 'B18', emoji: '✨', label: '골든 바이브',
        condition: '50~65dB 카페 5곳 기록', xpReward: 10,
        category: BadgeCategory.vibeDetection,
        unlocked: e('B18', s.goldenCafeCount >= 5),
      ),
      BadgeInfo(
        id: 'B19', emoji: '🏄', label: '에너지 서퍼',
        condition: '70dB 이상 카페 3곳 기록', xpReward: 10,
        category: BadgeCategory.vibeDetection,
        unlocked: e('B19', s.highCafeCount >= 3),
      ),
      BadgeInfo(
        id: 'B20', emoji: '🎵', label: '바이브 감정사',
        condition: '조용/적당/시끄러운 카페 각 5곳씩 기록', xpReward: 20,
        category: BadgeCategory.vibeDetection,
        unlocked: e('B20',
          s.quietSpotMeasuredCount >= 5 &&
          s.midSpotMeasuredCount >= 5 &&
          s.loudSpotMeasuredCount >= 5),
      ),
      BadgeInfo(
        id: 'B21', emoji: '🌙', label: '고요의 수집가',
        condition: '40dB 미만 카페 3곳 발견', xpReward: 20,
        category: BadgeCategory.vibeDetection,
        unlocked: e('B21', s.veryQuietCafe40Count >= 3),
      ),
      BadgeInfo(
        id: 'B22', emoji: '📚', label: '바이브 백과사전',
        condition: '5개 dB 구간 각 3곳 이상', xpReward: 50,
        category: BadgeCategory.vibeDetection,
        unlocked: e('B22',
          (s.dbRangeSpotCount['<40'] ?? 0) >= 3 &&
          (s.dbRangeSpotCount['40-55'] ?? 0) >= 3 &&
          (s.dbRangeSpotCount['55-70'] ?? 0) >= 3 &&
          (s.dbRangeSpotCount['70-85'] ?? 0) >= 3 &&
          (s.dbRangeSpotCount['85+'] ?? 0) >= 3),
      ),

      // ── Cat 5: 시간대 & 상황 (B23–B26) ───────────────────
      BadgeInfo(
        id: 'B23', emoji: '🌅', label: '모닝 바이브',
        condition: '오전 9시 이전에 5회 측정', xpReward: 10,
        category: BadgeCategory.timeContext,
        unlocked: e('B23', s.morningReportCount >= 5),
      ),
      BadgeInfo(
        id: 'B24', emoji: '🌃', label: '나이트 바이브',
        condition: '오후 9시 이후에 5회 측정', xpReward: 10,
        category: BadgeCategory.timeContext,
        unlocked: e('B24', s.nightReportCount >= 5),
      ),
      BadgeInfo(
        id: 'B25', emoji: '🎉', label: '주말 카페러',
        condition: '토·일요일에 10회 측정', xpReward: 10,
        category: BadgeCategory.timeContext,
        unlocked: e('B25', s.weekendReportCount >= 10),
      ),
      BadgeInfo(
        id: 'B26', emoji: '🌪️', label: '폭풍 측정 데이',
        condition: '하루에 다른 카페 3곳 측정', xpReward: 20,
        category: BadgeCategory.timeContext,
        unlocked: e('B26', s.maxCafesOneDay >= 3),
      ),

      // ── Cat 6: 기여 & 커뮤니티 (B27–B30) ─────────────────
      BadgeInfo(
        id: 'B27', emoji: '🏷️', label: '태그 마스터',
        condition: '태그 스티커 누적 30회 선택', xpReward: 10,
        category: BadgeCategory.community,
        unlocked: e('B27', s.totalStickerCount >= 30),
      ),
      BadgeInfo(
        id: 'B28', emoji: '✍️', label: '리뷰어',
        condition: '측정 시 메모 10회 이상 작성', xpReward: 10,
        category: BadgeCategory.community,
        unlocked: e('B28', s.memoReportCount >= 10),
      ),
      BadgeInfo(
        id: 'B29', emoji: '💌', label: '피드백 파트너',
        condition: '앱 내 피드백/건의 1회 이상', xpReward: 5,
        category: BadgeCategory.community,
        unlocked: earnedIds.contains('B29'), // instant-award only
      ),
      BadgeInfo(
        id: 'B30', emoji: '🎪', label: '시즌 한정',
        condition: '기간 한정 이벤트 달성', xpReward: 20,
        category: BadgeCategory.community,
        unlocked: earnedIds.contains('B30'), // server-granted only
      ),
    ];
  }
}

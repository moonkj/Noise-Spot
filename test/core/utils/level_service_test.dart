import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_vibe/core/utils/level_service.dart';

// ──────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────

/// XP thresholds (mirrors LevelService._xpThresholds)
const _xp = [0, 30, 80, 160, 280, 450, 700, 1050, 1500, 2100];

BadgeStats _emptyStats() => BadgeStats.empty();

BadgeStats _statsWith({
  int totalReports = 0,
  int totalCafes = 0,
  bool hasFirstMemo = false,
  bool hasFirstSticker = false,
  int maxStreakDays = 0,
  bool monthIn20Reports = false,
  int maxNeighborhoodCafes = 0,
  int maxFranchiseCafes = 0,
  int indieCafeCount = 0,
  int firstReporterCount = 0,
  int uniqueCityCount = 0,
  int quietCafe50Count = 0,
  int goldenCafeCount = 0,
  int highCafeCount = 0,
  int quietSpotMeasuredCount = 0,
  int midSpotMeasuredCount = 0,
  int loudSpotMeasuredCount = 0,
  int veryQuietCafe40Count = 0,
  Map<String, int> dbRangeSpotCount = const {},
  int morningReportCount = 0,
  int nightReportCount = 0,
  int weekendReportCount = 0,
  int maxCafesOneDay = 0,
  int totalStickerCount = 0,
  int memoReportCount = 0,
  int uniqueDistrictCount = 0,
}) =>
    BadgeStats(
      totalReports: totalReports,
      totalCafes: totalCafes,
      hasFirstMemo: hasFirstMemo,
      hasFirstSticker: hasFirstSticker,
      maxStreakDays: maxStreakDays,
      monthIn20Reports: monthIn20Reports,
      maxNeighborhoodCafes: maxNeighborhoodCafes,
      maxFranchiseCafes: maxFranchiseCafes,
      indieCafeCount: indieCafeCount,
      firstReporterCount: firstReporterCount,
      uniqueCityCount: uniqueCityCount,
      quietCafe50Count: quietCafe50Count,
      goldenCafeCount: goldenCafeCount,
      highCafeCount: highCafeCount,
      quietSpotMeasuredCount: quietSpotMeasuredCount,
      midSpotMeasuredCount: midSpotMeasuredCount,
      loudSpotMeasuredCount: loudSpotMeasuredCount,
      veryQuietCafe40Count: veryQuietCafe40Count,
      dbRangeSpotCount: dbRangeSpotCount,
      morningReportCount: morningReportCount,
      nightReportCount: nightReportCount,
      weekendReportCount: weekendReportCount,
      maxCafesOneDay: maxCafesOneDay,
      totalStickerCount: totalStickerCount,
      memoReportCount: memoReportCount,
      uniqueDistrictCount: uniqueDistrictCount,
    );

// ──────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────

void main() {
  // ── LevelService.calcLevel ─────────────────────────────────
  group('LevelService.calcLevel — 레벨 계산', () {
    test('0 XP → Lv.1 바이브 비기너', () {
      final result = LevelService.calcLevel(0);
      expect(result.level, 1);
      expect(result.name, '바이브 비기너');
      expect(result.currentXp, 0);
      expect(result.progress, 0.0);
      expect(result.isMax, isFalse);
    });

    test('각 레벨 최소 XP에서 정확한 레벨 반환', () {
      for (int lv = 1; lv <= 10; lv++) {
        final result = LevelService.calcLevel(_xp[lv - 1]);
        expect(result.level, lv, reason: 'XP=${_xp[lv - 1]} → Lv.$lv 기대');
      }
    });

    test('Lv.2 최소 XP(30) 직전(29) → 여전히 Lv.1', () {
      final result = LevelService.calcLevel(29);
      expect(result.level, 1);
    });

    test('Lv.5(280 XP) → 진행률 0.0', () {
      final result = LevelService.calcLevel(280);
      expect(result.level, 5);
      expect(result.progress, 0.0);
    });

    test('Lv.5 중간 XP → 0 < progress < 1', () {
      // Lv.5: 280~449, 중간 = 364
      final result = LevelService.calcLevel(364);
      expect(result.level, 5);
      expect(result.progress, greaterThan(0.0));
      expect(result.progress, lessThan(1.0));
    });

    test('Lv.10 최소 XP(2100) → isMax=true, progress=1.0, nextTarget=-1', () {
      final result = LevelService.calcLevel(2100);
      expect(result.level, 10);
      expect(result.isMax, isTrue);
      expect(result.progress, 1.0);
      expect(result.nextTarget, -1);
    });

    test('Lv.10 초과 XP(9999) → 여전히 Lv.10', () {
      final result = LevelService.calcLevel(9999);
      expect(result.level, 10);
      expect(result.isMax, isTrue);
    });

    test('xpPerReport=10, xpNewCafe=5 상수 확인', () {
      expect(LevelService.xpPerReport, 10);
      expect(LevelService.xpNewCafe, 5);
    });

    test('nextTarget은 다음 레벨의 XP 임계값', () {
      final result = LevelService.calcLevel(50); // Lv.2 (30~79)
      expect(result.nextTarget, 80); // Lv.3 임계값
    });
  });

  // ── LevelService.calcBadges — 32개 뱃지 ───────────────────
  group('LevelService.calcBadges — 뱃지 개수 & 구조', () {
    test('항상 32개 뱃지를 반환한다 (B01~B30 + B31/B32)', () {
      final badges = LevelService.calcBadges(_emptyStats(), {});
      expect(badges.length, 32);
    });

    test('B01~B30 + B31 + B32 ID가 모두 존재한다', () {
      final badges = LevelService.calcBadges(_emptyStats(), {});
      final ids = badges.map((b) => b.id).toSet();
      for (int i = 1; i <= 30; i++) {
        final id = 'B${i.toString().padLeft(2, '0')}';
        expect(ids.contains(id), isTrue, reason: '$id 누락');
      }
      expect(ids.contains('B31'), isTrue, reason: 'B31 누락');
      expect(ids.contains('B32'), isTrue, reason: 'B32 누락');
    });

    test('모든 뱃지에 emoji, label, condition이 있다', () {
      final badges = LevelService.calcBadges(_emptyStats(), {});
      for (final b in badges) {
        expect(b.emoji.isNotEmpty, isTrue, reason: '${b.id} emoji 누락');
        expect(b.label.isNotEmpty, isTrue, reason: '${b.id} label 누락');
        expect(b.condition.isNotEmpty, isTrue, reason: '${b.id} condition 누락');
      }
    });

    test('초기 상태(빈 stats)에서 모든 뱃지는 locked', () {
      final badges = LevelService.calcBadges(_emptyStats(), {});
      for (final b in badges) {
        expect(b.unlocked, isFalse, reason: '${b.id} 잠금 상태여야 함');
      }
    });
  });

  group('LevelService.calcBadges — Cat 1: 첫 경험', () {
    test('B01: totalReports>=1 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(totalReports: 1),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B01').unlocked, isTrue);
    });

    test('B01: totalReports=0 → 잠금', () {
      final badges = LevelService.calcBadges(_emptyStats(), {});
      expect(badges.firstWhere((b) => b.id == 'B01').unlocked, isFalse);
    });

    test('B02: hasFirstMemo=true → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(hasFirstMemo: true),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B02').unlocked, isTrue);
    });

    test('B03: hasFirstSticker=true → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(hasFirstSticker: true),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B03').unlocked, isTrue);
    });

    test('B04: stats로 해제 불가, earnedIds에 있어야 해제 (instant-award)', () {
      // stats 값으로는 절대 해제 안 됨
      final notEarned = LevelService.calcBadges(_statsWith(totalReports: 100), {});
      expect(notEarned.firstWhere((b) => b.id == 'B04').unlocked, isFalse);

      // earnedIds에 있으면 해제
      final earned = LevelService.calcBadges(_emptyStats(), {'B04'});
      expect(earned.firstWhere((b) => b.id == 'B04').unlocked, isTrue);
    });
  });

  group('LevelService.calcBadges — Cat 2: 꾸준함', () {
    test('B05: totalReports>=5 → 해제', () {
      final badges = LevelService.calcBadges(_statsWith(totalReports: 5), {});
      expect(badges.firstWhere((b) => b.id == 'B05').unlocked, isTrue);
    });

    test('B05: totalReports=4 → 잠금', () {
      final badges = LevelService.calcBadges(_statsWith(totalReports: 4), {});
      expect(badges.firstWhere((b) => b.id == 'B05').unlocked, isFalse);
    });

    test('B06: maxStreakDays>=3 → 해제', () {
      final badges = LevelService.calcBadges(_statsWith(maxStreakDays: 3), {});
      expect(badges.firstWhere((b) => b.id == 'B06').unlocked, isTrue);
    });

    test('B07: maxStreakDays>=7 → 해제', () {
      final badges = LevelService.calcBadges(_statsWith(maxStreakDays: 7), {});
      expect(badges.firstWhere((b) => b.id == 'B07').unlocked, isTrue);
    });

    test('B08: monthIn20Reports=true → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(monthIn20Reports: true),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B08').unlocked, isTrue);
    });

    test('B09: maxStreakDays>=30 → 해제', () {
      final badges = LevelService.calcBadges(_statsWith(maxStreakDays: 30), {});
      expect(badges.firstWhere((b) => b.id == 'B09').unlocked, isTrue);
    });

    test('B10: totalReports>=100 → 해제', () {
      final badges = LevelService.calcBadges(_statsWith(totalReports: 100), {});
      expect(badges.firstWhere((b) => b.id == 'B10').unlocked, isTrue);
    });

    test('B10: totalReports=99 → 잠금', () {
      final badges = LevelService.calcBadges(_statsWith(totalReports: 99), {});
      expect(badges.firstWhere((b) => b.id == 'B10').unlocked, isFalse);
    });
  });

  group('LevelService.calcBadges — Cat 3: 탐험', () {
    test('B11: totalCafes>=2 → 해제', () {
      final badges = LevelService.calcBadges(_statsWith(totalCafes: 2), {});
      expect(badges.firstWhere((b) => b.id == 'B11').unlocked, isTrue);
    });

    test('B12: maxNeighborhoodCafes>=5 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(maxNeighborhoodCafes: 5),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B12').unlocked, isTrue);
    });

    test('B13: maxFranchiseCafes>=5 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(maxFranchiseCafes: 5),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B13').unlocked, isTrue);
    });

    test('B14: indieCafeCount>=10 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(indieCafeCount: 10),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B14').unlocked, isTrue);
    });

    test('B15: firstReporterCount>=3 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(firstReporterCount: 3),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B15').unlocked, isTrue);
    });

    test('B16: uniqueCityCount>=3 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(uniqueCityCount: 3),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B16').unlocked, isTrue);
    });

    // B31/B32 — uniqueDistrictCount 기반 (탐험 카테고리 확장)
    test('B31: uniqueDistrictCount>=3 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(uniqueDistrictCount: 3),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B31').unlocked, isTrue);
    });

    test('B31: uniqueDistrictCount=2 → 잠금', () {
      final badges = LevelService.calcBadges(
        _statsWith(uniqueDistrictCount: 2),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B31').unlocked, isFalse);
    });

    test('B32: uniqueDistrictCount>=8 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(uniqueDistrictCount: 8),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B32').unlocked, isTrue);
    });

    test('B32: uniqueDistrictCount=7 → 잠금', () {
      final badges = LevelService.calcBadges(
        _statsWith(uniqueDistrictCount: 7),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B32').unlocked, isFalse);
    });

    test('B31 달성 시 B32는 아직 잠금 (3개 동네 < 8개)', () {
      final badges = LevelService.calcBadges(
        _statsWith(uniqueDistrictCount: 3),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B31').unlocked, isTrue);
      expect(badges.firstWhere((b) => b.id == 'B32').unlocked, isFalse);
    });

    test('B31/B32: earnedIds 우선 적용', () {
      final badges = LevelService.calcBadges(_emptyStats(), {'B31', 'B32'});
      expect(badges.firstWhere((b) => b.id == 'B31').unlocked, isTrue);
      expect(badges.firstWhere((b) => b.id == 'B32').unlocked, isTrue);
    });
  });

  group('LevelService.calcBadges — Cat 4: 바이브 감별', () {
    test('B17: quietCafe50Count>=1 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(quietCafe50Count: 1),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B17').unlocked, isTrue);
    });

    test('B18: goldenCafeCount>=5 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(goldenCafeCount: 5),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B18').unlocked, isTrue);
    });

    test('B19: highCafeCount>=3 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(highCafeCount: 3),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B19').unlocked, isTrue);
    });

    test('B20: 세 구간 모두 5곳 이상 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(
          quietSpotMeasuredCount: 5,
          midSpotMeasuredCount: 5,
          loudSpotMeasuredCount: 5,
        ),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B20').unlocked, isTrue);
    });

    test('B20: 하나라도 4곳이면 잠금', () {
      final badges = LevelService.calcBadges(
        _statsWith(
          quietSpotMeasuredCount: 5,
          midSpotMeasuredCount: 4, // 부족
          loudSpotMeasuredCount: 5,
        ),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B20').unlocked, isFalse);
    });

    test('B21: veryQuietCafe40Count>=3 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(veryQuietCafe40Count: 3),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B21').unlocked, isTrue);
    });

    test('B22: 5개 구간 각 3곳 이상 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(
          dbRangeSpotCount: {
            '<40': 3, '40-55': 3, '55-70': 3, '70-85': 3, '85+': 3,
          },
        ),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B22').unlocked, isTrue);
    });

    test('B22: 한 구간이 2곳이면 잠금', () {
      final badges = LevelService.calcBadges(
        _statsWith(
          dbRangeSpotCount: {
            '<40': 3, '40-55': 2, '55-70': 3, '70-85': 3, '85+': 3,
          },
        ),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B22').unlocked, isFalse);
    });
  });

  group('LevelService.calcBadges — Cat 5: 시간대 & 상황', () {
    test('B23: morningReportCount>=5 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(morningReportCount: 5),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B23').unlocked, isTrue);
    });

    test('B24: nightReportCount>=5 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(nightReportCount: 5),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B24').unlocked, isTrue);
    });

    test('B25: weekendReportCount>=10 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(weekendReportCount: 10),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B25').unlocked, isTrue);
    });

    test('B26: maxCafesOneDay>=3 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(maxCafesOneDay: 3),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B26').unlocked, isTrue);
    });
  });

  group('LevelService.calcBadges — Cat 6: 기여 & 커뮤니티', () {
    test('B27: totalStickerCount>=30 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(totalStickerCount: 30),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B27').unlocked, isTrue);
    });

    test('B28: memoReportCount>=10 → 해제', () {
      final badges = LevelService.calcBadges(
        _statsWith(memoReportCount: 10),
        {},
      );
      expect(badges.firstWhere((b) => b.id == 'B28').unlocked, isTrue);
    });

    test('B29: earnedIds에만 존재 (instant-award)', () {
      final notEarned = LevelService.calcBadges(_statsWith(memoReportCount: 100), {});
      expect(notEarned.firstWhere((b) => b.id == 'B29').unlocked, isFalse);

      final earned = LevelService.calcBadges(_emptyStats(), {'B29'});
      expect(earned.firstWhere((b) => b.id == 'B29').unlocked, isTrue);
    });

    test('B30: server-granted only — earnedIds에 있어야 해제', () {
      final notEarned = LevelService.calcBadges(_statsWith(totalReports: 9999), {});
      expect(notEarned.firstWhere((b) => b.id == 'B30').unlocked, isFalse);

      final earned = LevelService.calcBadges(_emptyStats(), {'B30'});
      expect(earned.firstWhere((b) => b.id == 'B30').unlocked, isTrue);
    });
  });

  group('LevelService.calcBadges — earnedIds 우선 적용', () {
    test('이미 earned된 뱃지는 stats 조건 미충족이어도 unlocked=true', () {
      // B10(100회)을 stats=0인데 earnedIds에 넣으면 해제
      final badges = LevelService.calcBadges(_emptyStats(), {'B10'});
      expect(badges.firstWhere((b) => b.id == 'B10').unlocked, isTrue);
    });

    test('여러 earnedIds를 한 번에 적용할 수 있다', () {
      final badges = LevelService.calcBadges(_emptyStats(), {'B01', 'B05', 'B16'});
      expect(badges.firstWhere((b) => b.id == 'B01').unlocked, isTrue);
      expect(badges.firstWhere((b) => b.id == 'B05').unlocked, isTrue);
      expect(badges.firstWhere((b) => b.id == 'B16').unlocked, isTrue);
      // 나머지는 잠금
      expect(badges.firstWhere((b) => b.id == 'B02').unlocked, isFalse);
    });
  });

  // ── BadgeCategory 열거형 ──────────────────────────────────
  group('BadgeCategory', () {
    test('6개 카테고리가 존재한다', () {
      expect(BadgeCategory.values.length, 6);
    });

    test('각 카테고리의 label이 비어 있지 않다', () {
      for (final cat in BadgeCategory.values) {
        expect(cat.label.isNotEmpty, isTrue, reason: '${cat.name} label 누락');
      }
    });

    test('각 카테고리의 emoji가 비어 있지 않다', () {
      for (final cat in BadgeCategory.values) {
        expect(cat.emoji.isNotEmpty, isTrue, reason: '${cat.name} emoji 누락');
      }
    });
  });

  // ── BadgeInfo.copyWith ────────────────────────────────────
  group('BadgeInfo.copyWith', () {
    const badge = BadgeInfo(
      id: 'B01',
      emoji: '🔰',
      label: '데시벨 입문자',
      condition: '첫 번째 바이브 측정',
      xpReward: 5,
      category: BadgeCategory.firstExperience,
      unlocked: false,
    );

    test('unlocked=true로 변경', () {
      final updated = badge.copyWith(unlocked: true);
      expect(updated.unlocked, isTrue);
      expect(updated.id, 'B01'); // 나머지 유지
    });

    test('copyWith 호출 시 원본은 변경되지 않는다', () {
      badge.copyWith(unlocked: true);
      expect(badge.unlocked, isFalse);
    });
  });

  // ── BadgeStats.empty() ────────────────────────────────────
  group('BadgeStats.empty()', () {
    test('모든 숫자 필드는 0', () {
      final s = BadgeStats.empty();
      expect(s.totalReports, 0);
      expect(s.totalCafes, 0);
      expect(s.maxStreakDays, 0);
      expect(s.morningReportCount, 0);
      expect(s.nightReportCount, 0);
      expect(s.uniqueDistrictCount, 0);
    });

    test('모든 bool 필드는 false', () {
      final s = BadgeStats.empty();
      expect(s.hasFirstMemo, isFalse);
      expect(s.hasFirstSticker, isFalse);
      expect(s.monthIn20Reports, isFalse);
    });

    test('dbRangeSpotCount는 빈 맵', () {
      expect(BadgeStats.empty().dbRangeSpotCount, isEmpty);
    });
  });
}

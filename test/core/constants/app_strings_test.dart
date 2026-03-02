import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_vibe/core/constants/app_strings.dart';

void main() {
  // ── levelNames ────────────────────────────────────────────
  group('AppStrings.levelNames', () {
    test('정확히 10개 항목 (Lv.1~Lv.10)', () {
      expect(AppStrings.levelNames.length, 10);
    });

    test('빈 문자열 없음', () {
      for (final name in AppStrings.levelNames) {
        expect(name.isNotEmpty, isTrue, reason: '"$name" 빈 레벨명 발견');
      }
    });

    test('Lv.1 = 바이브 비기너', () {
      expect(AppStrings.levelNames[0], '바이브 비기너');
    });

    test('Lv.10 = 바이브 레전드', () {
      expect(AppStrings.levelNames[9], '바이브 레전드');
    });

    test('모든 이름이 "바이브" 를 포함한다', () {
      for (final name in AppStrings.levelNames) {
        expect(name.contains('바이브'), isTrue, reason: '"$name"에 "바이브" 없음');
      }
    });

    test('이름이 모두 고유하다', () {
      final unique = AppStrings.levelNames.toSet();
      expect(unique.length, AppStrings.levelNames.length);
    });
  });

  // ── levelIcons ────────────────────────────────────────────
  group('AppStrings.levelIcons', () {
    test('정확히 10개 항목', () {
      expect(AppStrings.levelIcons.length, 10);
    });

    test('빈 문자열 없음', () {
      for (final icon in AppStrings.levelIcons) {
        expect(icon.isNotEmpty, isTrue, reason: 'index ${AppStrings.levelIcons.indexOf(icon)} 빈 아이콘 발견');
      }
    });

    test('levelNames와 개수가 동일 (병렬 배열)', () {
      expect(AppStrings.levelIcons.length, AppStrings.levelNames.length);
    });
  });

  // ── 정적 문자열 상수 ──────────────────────────────────────
  group('AppStrings 정적 상수 — 비어 있지 않음', () {
    test('appName', () => expect(AppStrings.appName.isNotEmpty, isTrue));
    test('appSlogan', () => expect(AppStrings.appSlogan.isNotEmpty, isTrue));
    test('privacyNoticeMeasure', () => expect(AppStrings.privacyNoticeMeasure.isNotEmpty, isTrue));
    test('privacyNoticeSettings', () => expect(AppStrings.privacyNoticeSettings.isNotEmpty, isTrue));

    test('filterStudy == STUDY (DB 키 불변)', () {
      expect(AppStrings.filterStudy, 'STUDY');
    });
    test('filterMeeting == MEETING (DB 키 불변)', () {
      expect(AppStrings.filterMeeting, 'MEETING');
    });
    test('filterRelax == RELAX (DB 키 불변)', () {
      expect(AppStrings.filterRelax, 'RELAX');
    });

    test('sticker labels 비어 있지 않음', () {
      expect(AppStrings.stickerStudyLabel.isNotEmpty, isTrue);
      expect(AppStrings.stickerMeetingLabel.isNotEmpty, isTrue);
      expect(AppStrings.stickerRelaxLabel.isNotEmpty, isTrue);
    });
  });

  // ── dB 레이블 상수 ────────────────────────────────────────
  group('AppStrings dB 레이블', () {
    test('5개 레이블이 모두 비어 있지 않다', () {
      expect(AppStrings.dbVeryQuiet.isNotEmpty, isTrue);
      expect(AppStrings.dbQuiet.isNotEmpty, isTrue);
      expect(AppStrings.dbModerate.isNotEmpty, isTrue);
      expect(AppStrings.dbLoud.isNotEmpty, isTrue);
      expect(AppStrings.dbVeryLoud.isNotEmpty, isTrue);
    });

    test('5개 레이블이 모두 고유하다', () {
      final labels = {
        AppStrings.dbVeryQuiet,
        AppStrings.dbQuiet,
        AppStrings.dbModerate,
        AppStrings.dbLoud,
        AppStrings.dbVeryLoud,
      };
      expect(labels.length, 5);
    });
  });

  // ── 포맷 함수 ────────────────────────────────────────────
  group('AppStrings 포맷 함수', () {
    test('exploreCafeCount — 숫자 포함', () {
      expect(AppStrings.exploreCafeCount(5), contains('5'));
      expect(AppStrings.exploreCafeCount(0), contains('0'));
      expect(AppStrings.exploreCafeCount(100), contains('100'));
    });

    test('recentReports — 카운트와 30분 포함', () {
      final result = AppStrings.recentReports(3);
      expect(result, contains('3'));
      expect(result, contains('30분'));
    });

    test('todayVisitors — 카운트 포함', () {
      final result = AppStrings.todayVisitors(10);
      expect(result, contains('10'));
    });

    test('lastHourAvg — dB 값 포함', () {
      final result = AppStrings.lastHourAvg('52.3');
      expect(result, contains('52.3'));
      expect(result, contains('dB'));
    });

    test('exploreCafeCount(1) ≠ exploreCafeCount(2)', () {
      expect(
        AppStrings.exploreCafeCount(1),
        isNot(equals(AppStrings.exploreCafeCount(2))),
      );
    });
  });

  // ── Report / Settings 문자열 ──────────────────────────────
  group('AppStrings Report/Settings 상수', () {
    test('reportTooFar 비어 있지 않음', () => expect(AppStrings.reportTooFar.isNotEmpty, isTrue));
    test('reportSuccess 비어 있지 않음', () => expect(AppStrings.reportSuccess.isNotEmpty, isTrue));
    test('measuring 비어 있지 않음', () => expect(AppStrings.measuring.isNotEmpty, isTrue));
    test('logout 비어 있지 않음', () => expect(AppStrings.logout.isNotEmpty, isTrue));
    test('deleteAccount 비어 있지 않음', () => expect(AppStrings.deleteAccount.isNotEmpty, isTrue));
  });

  // ── Trust 레이블 ──────────────────────────────────────────
  group('AppStrings Trust 레이블', () {
    test('Bronze / Silver / Gold 정확', () {
      expect(AppStrings.trustBronze, 'Bronze');
      expect(AppStrings.trustSilver, 'Silver');
      expect(AppStrings.trustGold, 'Gold');
    });
  });
}

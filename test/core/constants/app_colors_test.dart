import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_vibe/core/constants/app_colors.dart';
import 'package:cafe_vibe/core/utils/db_classifier.dart';

void main() {
  // ── AppColors.dbColor 경계값 ───────────────────────────────
  group('AppColors.dbColor — 5단계 경계값', () {
    test('0.0 dB → dbVeryQuiet (Mint Green)', () {
      expect(AppColors.dbColor(0.0), AppColors.dbVeryQuiet);
    });

    test('39.9 dB → dbVeryQuiet', () {
      expect(AppColors.dbColor(39.9), AppColors.dbVeryQuiet);
    });

    test('40.0 dB → dbQuiet (Sky Blue)', () {
      expect(AppColors.dbColor(40.0), AppColors.dbQuiet);
    });

    test('54.9 dB → dbQuiet', () {
      expect(AppColors.dbColor(54.9), AppColors.dbQuiet);
    });

    test('55.0 dB → dbModerate (Yellow)', () {
      expect(AppColors.dbColor(55.0), AppColors.dbModerate);
    });

    test('69.9 dB → dbModerate', () {
      expect(AppColors.dbColor(69.9), AppColors.dbModerate);
    });

    test('70.0 dB → dbLoud (Orange)', () {
      expect(AppColors.dbColor(70.0), AppColors.dbLoud);
    });

    test('84.9 dB → dbLoud', () {
      expect(AppColors.dbColor(84.9), AppColors.dbLoud);
    });

    test('85.0 dB → dbVeryLoud (Red)', () {
      expect(AppColors.dbColor(85.0), AppColors.dbVeryLoud);
    });

    test('119.9 dB → dbVeryLoud', () {
      expect(AppColors.dbColor(119.9), AppColors.dbVeryLoud);
    });
  });

  // ── AppColors.dbColor ↔ DbClassifier.colorFromDb 일치 ─────
  group('AppColors.dbColor ↔ DbClassifier.colorFromDb 일관성', () {
    const testValues = [0.0, 20.0, 39.9, 40.0, 50.0, 54.9, 55.0, 65.0, 69.9, 70.0, 80.0, 84.9, 85.0, 100.0];

    for (final db in testValues) {
      test('${db}dB → 두 함수가 동일한 색상 반환', () {
        expect(
          AppColors.dbColor(db),
          DbClassifier.colorFromDb(db),
          reason: '${db}dB에서 불일치',
        );
      });
    }
  });

  // ── 5개 dB 색상이 모두 다르다 ─────────────────────────────
  group('AppColors dB 색상 구별성', () {
    test('5개 dB 컬러가 모두 고유하다', () {
      final colors = {
        AppColors.dbVeryQuiet,
        AppColors.dbQuiet,
        AppColors.dbModerate,
        AppColors.dbLoud,
        AppColors.dbVeryLoud,
      };
      expect(colors.length, 5);
    });

    test('dbVeryQuiet ≠ dbQuiet', () {
      expect(AppColors.dbVeryQuiet, isNot(equals(AppColors.dbQuiet)));
    });

    test('dbQuiet ≠ dbModerate', () {
      expect(AppColors.dbQuiet, isNot(equals(AppColors.dbModerate)));
    });

    test('dbModerate ≠ dbLoud', () {
      expect(AppColors.dbModerate, isNot(equals(AppColors.dbLoud)));
    });

    test('dbLoud ≠ dbVeryLoud', () {
      expect(AppColors.dbLoud, isNot(equals(AppColors.dbVeryLoud)));
    });
  });

  // ── 브랜드 색상 상수 검증 ─────────────────────────────────
  group('AppColors 브랜드 색상', () {
    test('mintGreen은 Color 인스턴스', () {
      expect(AppColors.mintGreen, isA<Color>());
    });

    test('skyBlue는 Color 인스턴스', () {
      expect(AppColors.skyBlue, isA<Color>());
    });

    test('mintGreen ≠ skyBlue', () {
      expect(AppColors.mintGreen, isNot(equals(AppColors.skyBlue)));
    });

    test('mintLight ≠ mintGreen (연한 버전)', () {
      expect(AppColors.mintLight, isNot(equals(AppColors.mintGreen)));
    });

    test('텍스트 색상: textPrimary는 완전 불투명 (alpha=255)', () {
      expect(AppColors.textPrimary.alpha, 255);
    });

    test('textPrimary ≠ textSecondary', () {
      expect(AppColors.textPrimary, isNot(equals(AppColors.textSecondary)));
    });
  });

  // ── 배경 그라디언트 ───────────────────────────────────────
  group('AppColors 그라디언트', () {
    test('bgGradient는 2개 색상을 가진다', () {
      expect(AppColors.bgGradient.colors.length, 2);
    });

    test('bgGradient 색상은 mintLight와 skyLight', () {
      expect(AppColors.bgGradient.colors[0], AppColors.mintLight);
      expect(AppColors.bgGradient.colors[1], AppColors.skyLight);
    });

    test('brandGradient는 2개 색상을 가진다', () {
      expect(AppColors.brandGradient.colors.length, 2);
    });

    test('brandGradient 색상은 mintGreen과 skyBlue', () {
      expect(AppColors.brandGradient.colors[0], AppColors.mintGreen);
      expect(AppColors.brandGradient.colors[1], AppColors.skyBlue);
    });
  });

  // ── Trust 색상 ────────────────────────────────────────────
  group('AppColors Trust Score 색상', () {
    test('3가지 trust 색상이 모두 고유하다', () {
      final trustColors = {
        AppColors.trustBronze,
        AppColors.trustSilver,
        AppColors.trustGold,
      };
      expect(trustColors.length, 3);
    });
  });

  // ── 스티커 색상 (18개 StickerType 대응) ──────────────────
  group('AppColors 스티커 색상', () {
    test('포커스 계열 4색이 모두 고유하다', () {
      final focus = {
        AppColors.stickerStudy,
        AppColors.stickerWork,
        AppColors.stickerStudyZone,
        AppColors.stickerNomad,
      };
      expect(focus.length, 4);
    });

    test('소셜 계열 4색이 모두 고유하다', () {
      final social = {
        AppColors.stickerMeeting,
        AppColors.stickerVibe,
        AppColors.stickerDate,
        AppColors.stickerGathering,
      };
      expect(social.length, 4);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// The WCAG 2.1 relative-contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('SpectraColors', () {
    test('both schemes derive from the same brand accent', () {
      expect(SpectraColors.light.accent, SpectraColors.accent);
      expect(SpectraColors.dark.accent, SpectraColors.accentBright);
    });

    test('light and dark invert the neutral scale', () {
      expect(SpectraColors.light.background, SpectraColors.neutral50);
      expect(SpectraColors.light.textPrimary, SpectraColors.neutral900);
      expect(SpectraColors.dark.background, SpectraColors.neutral1000);
      expect(SpectraColors.dark.textPrimary, SpectraColors.neutral50);
    });

    test('every semantic role is present in both schemes', () {
      for (final scheme in <SpectraColorScheme>[
        SpectraColors.light,
        SpectraColors.dark,
      ]) {
        expect(scheme.success, isNot(scheme.warning));
        expect(scheme.warning, isNot(scheme.danger));
        expect(scheme.danger, isNot(scheme.connected));
      }
    });

    test('body text on the background clears WCAG AA contrast', () {
      expect(
        contrast(
          SpectraColors.light.textPrimary,
          SpectraColors.light.background,
        ),
        greaterThan(4.5),
      );
      expect(
        contrast(SpectraColors.dark.textPrimary, SpectraColors.dark.background),
        greaterThan(4.5),
      );
    });

    test('borderStrong clears WCAG 1.4.11 on every surface it can sit on', () {
      for (final SpectraColorScheme scheme in <SpectraColorScheme>[
        SpectraColors.light,
        SpectraColors.dark,
      ]) {
        for (final Color under in <Color>[
          scheme.surface,
          scheme.surfaceRaised,
          scheme.background,
        ]) {
          expect(
            contrast(scheme.borderStrong, under),
            greaterThanOrEqualTo(3.0),
            reason: 'borderStrong on $under',
          );
        }
      }
    });

    test('borderStrong is stronger than the decorative border', () {
      for (final SpectraColorScheme scheme in <SpectraColorScheme>[
        SpectraColors.light,
        SpectraColors.dark,
      ]) {
        expect(
          contrast(scheme.borderStrong, scheme.surface),
          greaterThan(contrast(scheme.border, scheme.surface)),
        );
      }
    });
  });

  test('SpectraSpacing is a 4-point scale', () {
    expect(
      <double>[
        SpectraSpacing.xs,
        SpectraSpacing.sm,
        SpectraSpacing.md,
        SpectraSpacing.lg,
        SpectraSpacing.xl,
        SpectraSpacing.xxl,
      ],
      <double>[4, 8, 12, 16, 24, 32],
    );
  });

  test('SpectraMotion has three durations and two curves', () {
    expect(SpectraMotion.fast, const Duration(milliseconds: 120));
    expect(SpectraMotion.medium, const Duration(milliseconds: 220));
    expect(SpectraMotion.slow, const Duration(milliseconds: 400));
    expect(SpectraMotion.standard, Curves.easeOutCubic);
    expect(SpectraMotion.emphasized, Curves.easeInOutCubic);
  });
}

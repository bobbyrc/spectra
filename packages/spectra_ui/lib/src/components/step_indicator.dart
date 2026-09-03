import 'package:material_ui/material_ui.dart';

import '../../l10n/spectra_ui_localizations.dart';
import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Position within a fixed sequence of named steps, such as a DFU run.
class SpectraStepIndicator extends StatelessWidget {
  const SpectraStepIndicator({
    required this.steps,
    required this.currentIndex,
    this.failed = false,
    super.key,
  }) : assert(currentIndex >= 0, 'currentIndex must not be negative');

  final List<String> steps;
  final int currentIndex;

  /// The current step failed: it and its dot turn danger-coloured.
  final bool failed;

  @override
  Widget build(BuildContext context) {
    assert(steps.isNotEmpty, 'a step indicator needs at least one step');
    assert(
      currentIndex < steps.length,
      'currentIndex must index into steps (const construction keeps the '
      'upper bound out of the constructor assert)',
    );
    // Clamped so a release build with a stray index still renders the last
    // step instead of throwing a RangeError out of the render tree.
    final int index = currentIndex.clamp(0, steps.length - 1);
    final SpectraTheme theme = SpectraTheme.of(context);
    final SpectraUiLocalizations l10n = SpectraUiLocalizations.of(context);
    final Color currentColor = failed
        ? theme.colors.danger
        : theme.colors.accent;
    return Semantics(
      label: l10n.stepProgress(index + 1, steps.length),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.stepProgress(index + 1, steps.length),
            style: SpectraTypography.label.copyWith(
              color: theme.colors.textSecondary,
            ),
          ),
          const SizedBox(height: SpectraSpacing.sm),
          Row(
            children: <Widget>[
              for (int i = 0; i < steps.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: SpectraSpacing.sm),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: switch (i) {
                      _ when i < index => theme.colors.success,
                      _ when i == index => currentColor,
                      _ => theme.colors.border,
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: SpectraSpacing.sm),
          Text(
            steps[index],
            style: SpectraTypography.body.copyWith(
              color: failed ? theme.colors.danger : theme.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

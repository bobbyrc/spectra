import 'package:material_ui/material_ui.dart';

import '../../l10n/spectra_ui_localizations.dart';
import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'button.dart';
import 'button_variant.dart';

/// A labelled progress bar for a long operation, with optional cancellation.
class SpectraProgressIndicator extends StatelessWidget {
  const SpectraProgressIndicator({
    required this.label,
    this.value,
    this.detail,
    this.onCancel,
    super.key,
  }) : assert(
         value == null || (value >= 0 && value <= 1),
         'value must be a fraction between 0 and 1',
       );

  final String label;

  /// 0..1, or null for an indeterminate operation.
  final double? value;

  final String? detail;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final SpectraUiLocalizations l10n = SpectraUiLocalizations.of(context);
    // Asserted in the constructor; clamped so a release build with a stray
    // value still renders a bar rather than throwing in the render tree.
    final double? fraction = value?.clamp(0.0, 1.0);
    return Semantics(
      label: detail == null ? label : '$label, $detail',
      value: fraction == null ? null : '${(fraction * 100).round()}%',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: SpectraTypography.body.copyWith(
              color: theme.colors.textPrimary,
            ),
          ),
          const SizedBox(height: SpectraSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(SpectraSpacing.xs),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: theme.colors.surfaceRaised,
              color: theme.colors.accent,
            ),
          ),
          if (detail != null) ...<Widget>[
            const SizedBox(height: SpectraSpacing.xs),
            Text(
              detail!,
              style: SpectraTypography.bodySmall.copyWith(
                color: theme.colors.textSecondary,
              ),
            ),
          ],
          if (onCancel != null) ...<Widget>[
            const SizedBox(height: SpectraSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: SpectraButton(
                label: l10n.cancel,
                variant: SpectraButtonVariant.secondary,
                onPressed: onCancel,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

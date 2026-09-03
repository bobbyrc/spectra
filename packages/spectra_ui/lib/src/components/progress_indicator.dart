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
  });

  final String label;

  /// 0..1, or null for an indeterminate operation.
  final double? value;

  final String? detail;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final SpectraUiLocalizations l10n = SpectraUiLocalizations.of(context);
    return Semantics(
      label: detail == null ? label : '$label, $detail',
      value: value == null ? null : '${(value! * 100).round()}%',
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
              value: value,
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

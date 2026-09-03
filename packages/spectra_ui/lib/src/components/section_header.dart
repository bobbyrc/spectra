import 'package:material_ui/material_ui.dart';

import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// A group title with one optional trailing action.
class SpectraSectionHeader extends StatelessWidget {
  const SpectraSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SpectraSpacing.md,
        vertical: SpectraSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: SpectraTypography.label.copyWith(
                color: theme.colors.textSecondary,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            Semantics(
              button: true,
              label: actionLabel,
              child: GestureDetector(
                onTap: onAction,
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: Text(
                      actionLabel!,
                      style: SpectraTypography.label.copyWith(
                        color: theme.colors.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

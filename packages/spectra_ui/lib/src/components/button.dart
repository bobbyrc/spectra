import 'package:material_ui/material_ui.dart';

import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'button_variant.dart';

/// A Spectra button. Takes a plain label, never a device type.
class SpectraButton extends StatelessWidget {
  const SpectraButton({
    required this.label,
    required this.onPressed,
    this.variant = SpectraButtonVariant.primary,
    this.icon,
    this.busy = false,
    this.semanticsLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final SpectraButtonVariant variant;
  final IconData? icon;

  /// Shows a spinner in place of the label and ignores taps.
  final bool busy;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final bool enabled = onPressed != null && !busy;
    final Color background = switch (variant) {
      SpectraButtonVariant.primary => theme.colors.accent,
      SpectraButtonVariant.secondary => theme.colors.surface,
      SpectraButtonVariant.danger => theme.colors.danger,
    };
    final Color foreground = switch (variant) {
      SpectraButtonVariant.primary => theme.colors.onAccent,
      SpectraButtonVariant.secondary => theme.colors.textPrimary,
      SpectraButtonVariant.danger => theme.colors.onAccent,
    };
    final Color border = variant == SpectraButtonVariant.secondary
        ? theme.colors.border
        : background;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel ?? label,
      excludeSemantics: semanticsLabel != null,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: enabled ? background : theme.colors.surfaceRaised,
            border: Border.all(color: enabled ? border : theme.colors.border),
            borderRadius: BorderRadius.circular(SpectraSpacing.sm),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpectraSpacing.lg,
                vertical: SpectraSpacing.md,
              ),
              child: Center(
                child: busy
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: foreground,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (icon != null) ...<Widget>[
                            Icon(
                              icon,
                              size: 18,
                              color: enabled
                                  ? foreground
                                  : theme.colors.textDisabled,
                            ),
                            const SizedBox(width: SpectraSpacing.sm),
                          ],
                          Text(
                            label,
                            style: SpectraTypography.label.copyWith(
                              color: enabled
                                  ? foreground
                                  : theme.colors.textDisabled,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

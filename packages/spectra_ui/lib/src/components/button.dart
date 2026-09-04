import 'package:material_ui/material_ui.dart';

import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'button_variant.dart';
import 'tappable.dart';

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

  /// The minimum tap target, per spec 6.2's 48px rule.
  static const double minTargetSize = 48;

  /// The icon and the busy spinner are sized against the label, not the
  /// target: both stay optically inside the 12px vertical padding.
  static const double iconSize = 18;
  static const double spinnerSize = 20;
  static const double spinnerStrokeWidth = 2;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final bool enabled = onPressed != null && !busy;
    final Color background = switch (variant) {
      SpectraButtonVariant.primary => theme.colors.accent,
      // A raised fill, not the page surface: the secondary button has to read
      // as a control even where it sits directly on a card.
      SpectraButtonVariant.secondary => theme.colors.surfaceRaised,
      SpectraButtonVariant.danger => theme.colors.danger,
    };
    final Color foreground = switch (variant) {
      SpectraButtonVariant.primary => theme.colors.onAccent,
      SpectraButtonVariant.secondary => theme.colors.textPrimary,
      SpectraButtonVariant.danger => theme.colors.onAccent,
    };
    // The secondary variant is the only one whose outline carries the
    // affordance, so it uses the 3:1 borderStrong role rather than the
    // decorative border.
    final Color border = variant == SpectraButtonVariant.secondary
        ? theme.colors.borderStrong
        : background;
    final BorderRadius radius = BorderRadius.circular(SpectraSpacing.sm);

    return SpectraTappable(
      onTap: onPressed,
      enabled: enabled,
      semanticsLabel: semanticsLabel ?? label,
      excludeSemantics: semanticsLabel != null,
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: enabled ? background : theme.colors.surfaceRaised,
          border: Border.all(color: enabled ? border : theme.colors.border),
          borderRadius: radius,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: minTargetSize,
            minWidth: minTargetSize,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpectraSpacing.lg,
              vertical: SpectraSpacing.md,
            ),
            child: Center(
              child: busy
                  ? SizedBox(
                      width: spinnerSize,
                      height: spinnerSize,
                      child: CircularProgressIndicator(
                        strokeWidth: spinnerStrokeWidth,
                        color: foreground,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (icon != null) ...<Widget>[
                          Icon(
                            icon,
                            size: iconSize,
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
    );
  }
}

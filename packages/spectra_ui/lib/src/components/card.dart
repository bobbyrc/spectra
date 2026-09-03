import 'package:material_ui/material_ui.dart';

import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import 'tappable.dart';

/// A raised surface. Tappable only when [onTap] is given.
///
/// The 48px minimum tap target is implicit in the default [padding]: a card
/// given a smaller padding and an [onTap] is the caller's to size.
class SpectraCard extends StatelessWidget {
  const SpectraCard({
    required this.child,
    this.padding = const EdgeInsets.all(SpectraSpacing.lg),
    this.onTap,
    this.semanticsLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final BorderRadius radius = BorderRadius.circular(SpectraSpacing.md);
    final Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border.all(color: theme.colors.border),
        borderRadius: radius,
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) {
      return semanticsLabel == null
          ? surface
          : Semantics(label: semanticsLabel, child: surface);
    }
    return SpectraTappable(
      onTap: onTap,
      semanticsLabel: semanticsLabel,
      // The card's content is its own label; keep it audible.
      excludeSemantics: false,
      borderRadius: radius,
      child: surface,
    );
  }
}

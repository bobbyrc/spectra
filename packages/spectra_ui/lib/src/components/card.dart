import 'package:material_ui/material_ui.dart';

import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';

/// A raised surface. Tappable only when [onTap] is given.
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
    final Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border.all(color: theme.colors.border),
        borderRadius: BorderRadius.circular(SpectraSpacing.md),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) {
      return semanticsLabel == null
          ? surface
          : Semantics(label: semanticsLabel, child: surface);
    }
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(onTap: onTap, child: surface),
    );
  }
}

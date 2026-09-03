import 'package:flutter/widgets.dart';

import '../tokens/color_scheme.dart';

/// Carries the brightness-resolved Spectra tokens down the tree.
///
/// Spacing, motion and type do not vary by brightness, so they stay static on
/// their token classes; only the colours and the brightness are inherited.
class SpectraTheme extends InheritedWidget {
  const SpectraTheme({
    required this.colors,
    required this.brightness,
    required super.child,
    super.key,
  });

  final SpectraColorScheme colors;
  final Brightness brightness;

  static SpectraTheme? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SpectraTheme>();

  static SpectraTheme of(BuildContext context) {
    final SpectraTheme? theme = maybeOf(context);
    assert(theme != null, 'No SpectraTheme found. Wrap the app in SpectraApp.');
    return theme!;
  }

  @override
  bool updateShouldNotify(SpectraTheme oldWidget) =>
      oldWidget.brightness != brightness || oldWidget.colors != colors;
}

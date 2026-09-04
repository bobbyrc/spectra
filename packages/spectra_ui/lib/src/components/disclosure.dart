import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/spectra_ui_localizations.dart';
import '../theme/spectra_theme.dart';
import '../tokens/motion.dart';
import '../tokens/spacing.dart';
import 'tappable.dart';

/// A summary row that expands to expert detail: the progressive-disclosure
/// primitive every expert affordance in Spectra sits behind.
///
/// Testing note: expanding runs a `flutter_animate` fade, which leaves a
/// pending timer if the test ends immediately after the tap. Do not use
/// `pumpAndSettle` after toggling — pump a bounded amount instead, e.g.
/// `await tester.pump(); await tester.pump(SpectraMotion.medium);`.
class SpectraDisclosure extends StatefulWidget {
  const SpectraDisclosure({
    required this.summary,
    required this.detail,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    super.key,
  });

  final Widget summary;
  final Widget detail;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  /// The minimum tap target, per spec 6.2's 48px rule.
  static const double minTargetSize = 48;

  @override
  State<SpectraDisclosure> createState() => _SpectraDisclosureState();
}

class _SpectraDisclosureState extends State<SpectraDisclosure> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    widget.onExpansionChanged?.call(_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final SpectraUiLocalizations l10n = SpectraUiLocalizations.of(context);
    final String affordance = _expanded
        ? l10n.disclosureHide
        : l10n.disclosureShow;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SpectraTappable(
          onTap: _toggle,
          semanticsLabel: affordance,
          expanded: _expanded,
          excludeSemantics: false,
          borderRadius: BorderRadius.circular(SpectraSpacing.sm),
          child: Row(
            children: <Widget>[
              Expanded(child: widget.summary),
              SizedBox(
                width: SpectraDisclosure.minTargetSize,
                height: SpectraDisclosure.minTargetSize,
                child: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: theme.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(top: SpectraSpacing.sm),
            child: widget.detail.animate().fadeIn(
              duration: SpectraMotion.medium,
              curve: SpectraMotion.standard,
            ),
          ),
      ],
    );
  }
}

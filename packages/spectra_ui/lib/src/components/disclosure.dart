import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/spectra_ui_localizations.dart';
import '../theme/spectra_theme.dart';
import '../tokens/motion.dart';
import '../tokens/spacing.dart';

/// A summary row that expands to expert detail: the progressive-disclosure
/// primitive every expert affordance in Spectra sits behind.
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
        GestureDetector(
          onTap: _toggle,
          child: Row(
            children: <Widget>[
              Expanded(child: widget.summary),
              Semantics(
                button: true,
                container: true,
                label: affordance,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colors.textSecondary,
                  ),
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

import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// A warning-coloured line: an icon, a sentence, and optionally a second,
/// smaller one under it.
///
/// Not an error — [ProblemView] is for those. This is the shape three card
/// sheets already drew by hand for something that went less than perfectly
/// but is still a choice the user can make: a partial read on the way to
/// the library, and the unread sector trailers both write paths ask about
/// (review M4).
///
/// `spectra_ui` has no callout component, so this stays an app widget for
/// now; promoting it to the design system is a design-system decision, not
/// a fix-wave one.
class WarningCallout extends StatelessWidget {
  const WarningCallout({required this.title, this.body, super.key});

  /// The headline sentence.
  final String title;

  /// An optional second line, in the smaller body style.
  final String? body;

  @override
  Widget build(BuildContext context) {
    final Color warning = SpectraTheme.of(context).colors.warning;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.warning_amber_rounded, color: warning, size: 20),
        const SizedBox(width: SpectraSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: SpectraTypography.body.copyWith(color: warning),
              ),
              if (body case final String detail) ...<Widget>[
                const SizedBox(height: SpectraSpacing.xs),
                Text(
                  detail,
                  style: SpectraTypography.bodySmall.copyWith(color: warning),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

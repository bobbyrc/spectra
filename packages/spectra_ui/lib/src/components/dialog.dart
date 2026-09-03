import 'package:material_ui/material_ui.dart';

import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// A Spectra modal dialog. [show] presents it and returns the popped value.
class SpectraDialog extends StatelessWidget {
  const SpectraDialog({
    required this.title,
    required this.content,
    required this.actions,
    super.key,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    required List<Widget> Function(BuildContext context) actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (BuildContext context) => SpectraDialog(
        title: title,
        content: content,
        actions: actions(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    return Dialog(
      backgroundColor: theme.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SpectraSpacing.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SpectraSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: SpectraTypography.title.copyWith(
                color: theme.colors.textPrimary,
              ),
            ),
            const SizedBox(height: SpectraSpacing.lg),
            // Long content scrolls inside the dialog rather than overflowing
            // it: `Flexible` lets the column give the content whatever height
            // is left once the title and the action row have taken theirs.
            Flexible(child: SingleChildScrollView(child: content)),
            const SizedBox(height: SpectraSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                for (final (int i, Widget action)
                    in actions.indexed) ...<Widget>[
                  if (i > 0) const SizedBox(width: SpectraSpacing.sm),
                  action,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

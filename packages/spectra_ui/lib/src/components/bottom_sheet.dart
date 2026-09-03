import 'package:material_ui/material_ui.dart';

import '../../l10n/spectra_ui_localizations.dart';
import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// A titled modal sheet. [show] presents it and returns the popped value.
class SpectraBottomSheet extends StatelessWidget {
  const SpectraBottomSheet({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) =>
          SpectraBottomSheet(title: title, child: builder(context)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final SpectraUiLocalizations l10n = SpectraUiLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SpectraSpacing.lg),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(SpectraSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: SpectraTypography.title.copyWith(
                        color: theme.colors.textPrimary,
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: l10n.close,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.close,
                          color: theme.colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpectraSpacing.lg),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

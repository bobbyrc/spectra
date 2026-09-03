import 'package:material_ui/material_ui.dart';

import '../../l10n/spectra_ui_localizations.dart';
import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// One of the device's eight slots. Tag types arrive as display strings, so
/// the kit never depends on the SDK's tag enums.
class SpectraSlotTile extends StatelessWidget {
  const SpectraSlotTile({
    required this.number,
    required this.enabled,
    this.nickname,
    this.tagTypes = const <String>[],
    this.active = false,
    this.onTap,
    super.key,
  });

  /// One-based slot number as the device labels it.
  final int number;

  final bool enabled;
  final String? nickname;
  final List<String> tagTypes;

  /// True for the slot the device currently emulates.
  final bool active;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final SpectraUiLocalizations l10n = SpectraUiLocalizations.of(context);
    final Color primaryText = enabled
        ? theme.colors.textPrimary
        : theme.colors.textDisabled;
    final Color secondaryText = enabled
        ? theme.colors.textSecondary
        : theme.colors.textDisabled;
    final String? statusLabel = !enabled
        ? l10n.slotTileDisabled
        : active
        ? l10n.slotTileActive
        : null;
    final String title = nickname ?? l10n.slotTileEmpty;

    final Widget body = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border.all(
          color: active ? theme.colors.accent : theme.colors.border,
          width: active ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(SpectraSpacing.md),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.all(SpectraSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.slotLabel(number),
                      style: SpectraTypography.label.copyWith(
                        color: secondaryText,
                      ),
                    ),
                  ),
                  if (statusLabel != null)
                    Text(
                      statusLabel,
                      style: SpectraTypography.label.copyWith(
                        color: active ? theme.colors.accent : secondaryText,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: SpectraSpacing.xs),
              Text(
                title,
                style: SpectraTypography.title.copyWith(color: primaryText),
              ),
              if (tagTypes.isNotEmpty) ...<Widget>[
                const SizedBox(height: SpectraSpacing.xs),
                Wrap(
                  spacing: SpectraSpacing.sm,
                  runSpacing: SpectraSpacing.xs,
                  children: <Widget>[
                    for (final String type in tagTypes)
                      Text(
                        type,
                        style: SpectraTypography.bodySmall.copyWith(
                          color: secondaryText,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final String semantics = <String>[
      l10n.slotLabel(number),
      title,
      ?statusLabel,
      ...tagTypes,
    ].join(', ');

    if (onTap == null) {
      return Semantics(label: semantics, excludeSemantics: true, child: body);
    }
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: body,
      ),
    );
  }
}

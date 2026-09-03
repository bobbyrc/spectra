import 'package:material_ui/material_ui.dart';

import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// One row of a list: title, optional subtitle, optional leading and trailing.
class SpectraListTile extends StatelessWidget {
  const SpectraListTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SpectraSpacing.md,
          vertical: SpectraSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[
              IconTheme(
                data: IconThemeData(color: theme.colors.textSecondary),
                child: leading!,
              ),
              const SizedBox(width: SpectraSpacing.md),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: SpectraTypography.body.copyWith(
                      color: theme.colors.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: SpectraTypography.bodySmall.copyWith(
                        color: theme.colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: SpectraSpacing.md),
              IconTheme(
                data: IconThemeData(color: theme.colors.textSecondary),
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title, $subtitle',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: row,
      ),
    );
  }
}

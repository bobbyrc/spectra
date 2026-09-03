import 'package:chameleon/chameleon.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../state/connect_row.dart';

/// One device: its name, its transport badges, and either connect or, for a
/// device sitting in its bootloader, recover (spec 5.5).
///
/// [ConnectRow.isPreselected] (spec 7.4 — the device whose link just
/// dropped) renders as this tile's selected state: an accent border plus
/// `Semantics(selected: true)`, since `SpectraListTile` has no selection
/// variant of its own (ruling 6).
///
/// [onConnect] and [onRecover] are nullable so the page can disable every
/// row while a connect attempt is in flight (finding 3, fix round 2):
/// `null` disables both this tile's `onTap` and, for a bootloader row, its
/// Recover button, so a second row cannot open a second transport under the
/// first attempt.
class ConnectRowTile extends StatelessWidget {
  const ConnectRowTile({
    required this.row,
    required this.onConnect,
    required this.onRecover,
    super.key,
  });

  final ConnectRow row;
  final VoidCallback? onConnect;
  final VoidCallback? onRecover;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SpectraTheme theme = SpectraTheme.of(context);
    final String subtitle = <String>[
      if (row.isBootloader) l10n.connectBootloaderBadge,
      for (final TransportKind kind in row.kinds) _kindLabel(l10n, kind),
    ].join(' · ');

    final Widget tile = SpectraListTile(
      title: row.name,
      subtitle: subtitle,
      leading: Icon(row.isBootloader ? Icons.build_circle : Icons.memory),
      trailing: row.isBootloader
          ? SpectraButton(
              label: l10n.connectRecover,
              onPressed: onRecover,
              variant: SpectraButtonVariant.secondary,
            )
          : const Icon(Icons.chevron_right),
      onTap: row.isBootloader ? onRecover : onConnect,
    );

    if (!row.isPreselected) return tile;
    return Semantics(
      selected: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colors.accent, width: 2),
          borderRadius: BorderRadius.circular(SpectraSpacing.md),
        ),
        child: tile,
      ),
    );
  }

  static String _kindLabel(AppLocalizations l10n, TransportKind kind) =>
      switch (kind) {
        TransportKind.usb => l10n.connectKindUsb,
        TransportKind.ble => l10n.connectKindBle,
        TransportKind.fake => l10n.connectKindFake,
      };
}

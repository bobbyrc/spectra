import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/format/tag_labels.dart';
import '../../../core/routing/routes.dart';
import '../../../data/data.dart';
import '../../../l10n/app_localizations.dart';
import '../state/card_codec.dart';
import '../state/cards_filter.dart';
import '../state/saved_cards_provider.dart';
import 'card_import_sheet.dart';

/// The card library (spec 7.7 step 4): search, folder filter, sort, and the
/// read entry point. Layout only — the filtering rule is [filterCards].
class CardsPage extends ConsumerWidget {
  const CardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<SavedCard> all =
        ref.watch(savedCardsProvider).value ?? const <SavedCard>[];
    final CardsFilter filter = ref.watch(cardsFilterStateProvider);
    final CardsFilterState filterState = ref.read(
      cardsFilterStateProvider.notifier,
    );
    final List<SavedCard> shown = filterCards(all, filter);
    final List<String> folders = foldersOf(all);

    return ListView(
      padding: const EdgeInsets.all(SpectraSpacing.lg),
      children: <Widget>[
        SpectraButton(
          label: l10n.cardsReadAction,
          icon: Icons.nfc,
          onPressed: () => GoRouter.of(context).go(AppRoutes.cardRead),
        ),
        const SizedBox(height: SpectraSpacing.md),
        SpectraButton(
          label: l10n.cardsImport,
          icon: Icons.file_download_outlined,
          variant: SpectraButtonVariant.secondary,
          onPressed: () => _import(context),
        ),
        const SizedBox(height: SpectraSpacing.lg),
        SpectraTextField(
          label: l10n.cardsSearch,
          onChanged: filterState.setQuery,
        ),
        const SizedBox(height: SpectraSpacing.md),
        Wrap(
          spacing: SpectraSpacing.sm,
          runSpacing: SpectraSpacing.sm,
          children: <Widget>[
            _Chip(
              label: l10n.cardsAllFolders,
              selected: filter.folder == null,
              onTap: () => filterState.setFolder(null),
            ),
            for (final String folder in folders)
              _Chip(
                label: folder,
                selected: filter.folder == folder,
                onTap: () => filterState.setFolder(folder),
              ),
            _Chip(
              label: l10n.cardsSortRecent,
              selected: filter.sort == CardsSort.recent,
              onTap: () => filterState.setSort(CardsSort.recent),
            ),
            _Chip(
              label: l10n.cardsSortName,
              selected: filter.sort == CardsSort.name,
              onTap: () => filterState.setSort(CardsSort.name),
            ),
          ],
        ),
        const SizedBox(height: SpectraSpacing.lg),
        if (all.isEmpty)
          SpectraCard(child: Text(l10n.cardsEmpty))
        else if (shown.isEmpty)
          SpectraCard(child: Text(l10n.cardsNoMatches))
        else
          for (final SavedCard card in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: SpectraSpacing.sm),
              child: SpectraListTile(
                title: card.name,
                subtitle: _subtitle(card, l10n),
                leading: Icon(
                  Icons.circle,
                  color: card.color == null
                      ? SpectraTheme.of(context).colors.border
                      : Color(card.color!),
                ),
                onTap: () => GoRouter.of(context).go(AppRoutes.card(card.id)),
              ),
            ),
      ],
    );
  }

  /// Opens the import sheet and, on a successful import, tells the user how
  /// many cards landed (`cardsImported`, spec 7.3). The sheet itself shows
  /// its own failures inline, so a null result here is just a dismissal —
  /// nothing to report.
  Future<void> _import(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final int? count = await showCardImportSheet(context);
    if (count == null) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.cardsImported(count))));
  }

  /// [Ruling 20]: a folderless card renders just the tag type, never
  /// "…MIFARE Classic 1K · " with a dangling separator.
  String _subtitle(SavedCard card, AppLocalizations l10n) {
    final String type = tagTypeLabel(tagTypeFromName(card.tagType), l10n);
    final String? folder = card.folder;
    return folder == null
        ? l10n.cardsSubtitleNoFolder(type)
        : l10n.cardsSubtitle(type, folder);
  }
}

/// A filter chip on the design system's own tappable, so it is focusable and
/// announces itself; `spectra_ui` has no `SpectraChip` component.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final SpectraColorScheme colors = SpectraTheme.of(context).colors;
    return SpectraTappable(
      onTap: onTap,
      semanticsLabel: label,
      borderRadius: BorderRadius.circular(SpectraSpacing.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SpectraSpacing.md,
          vertical: SpectraSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.surface,
          borderRadius: BorderRadius.circular(SpectraSpacing.md),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          label,
          style: SpectraTypography.label.copyWith(
            color: selected ? colors.onAccent : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

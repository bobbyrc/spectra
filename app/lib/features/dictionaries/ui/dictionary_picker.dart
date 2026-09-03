import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../data/data.dart';
import '../../../l10n/app_localizations.dart';
import '../state/dictionaries_provider.dart';
import 'dictionaries_page.dart';

/// **The Dictionaries feature's public API** (spec 8.3). Asks the user which
/// key list to use, and resolves to it — keys and all — or null if the sheet
/// was dismissed.
///
/// Contract for the features that call it:
///
/// - Import it as `package:spectra/features/dictionaries/dictionaries.dart`.
///   Never reach into `features/dictionaries/ui/…` or `state/…` (spec 8.4).
/// - The whole list comes back, so a caller needs no second lookup: the
///   returned `keys` are the six-byte MIFARE Classic keys a reader facade
///   takes as `candidateKeys` (spec 8.1).
/// - It resolves to null on dismissal, and callers must handle that: it is
///   the normal way out of the sheet, not an error.
/// - [isSelectable] filters what may be chosen — an unselectable list is
///   still listed and untappable, so the user can see why it is not on
///   offer.
/// - It changes nothing. Choosing is a choice; a caller that wants the
///   choice to stick calls `selectedDictionaryIdProvider.notifier.select`.
/// - The built-in list is always in it, so the sheet is never empty.
Future<KeyDictionary?> showDictionaryPicker(
  BuildContext context, {
  bool Function(KeyDictionary dictionary)? isSelectable,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<KeyDictionary>(
    context: context,
    title: l10n.dictPickerTitle,
    builder: (BuildContext context) =>
        DictionaryPicker(isSelectable: isSelectable),
  );
}

/// The picker's body, for a caller that wants it inline rather than modal.
/// Pops the enclosing route with the chosen list.
class DictionaryPicker extends ConsumerWidget {
  const DictionaryPicker({this.isSelectable, super.key});

  final bool Function(KeyDictionary dictionary)? isSelectable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<KeyDictionary> all =
        ref.watch(dictionariesProvider).value ?? const <KeyDictionary>[];
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: all.length,
        separatorBuilder: (BuildContext context, int i) =>
            const SizedBox(height: SpectraSpacing.sm),
        itemBuilder: (BuildContext context, int i) {
          final KeyDictionary dictionary = all[i];
          final bool selectable = isSelectable?.call(dictionary) ?? true;
          return SpectraListTile(
            title: dictionaryDisplayName(dictionary, l10n),
            subtitle: l10n.dictKeyCount(dictionary.keys.length),
            leading: const Icon(Icons.key),
            onTap: selectable
                ? () => Navigator.of(context).pop(dictionary)
                : null,
          );
        },
      ),
    );
  }
}

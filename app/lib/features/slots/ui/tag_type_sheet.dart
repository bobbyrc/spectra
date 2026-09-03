import 'package:chameleon/chameleon.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../state/slot_labels.dart';

/// Asks which tag type a sense should hold. Resolves to the chosen type, or
/// null when the sheet is dismissed.
///
/// The list is `selectableTypes(sense)` — derived from the SDK's own
/// [TagFamily] classification, so it can never name a type the SDK does not
/// have.
Future<TagType?> showTagTypeSheet(
  BuildContext context, {
  required Sense sense,
  required TagType current,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<TagType>(
    context: context,
    title: l10n.slotChooseType,
    builder: (BuildContext context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          for (final TagType type in selectableTypes(sense))
            SpectraListTile(
              title: tagTypeLabel(type, l10n),
              trailing: type == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(type),
            ),
        ],
      ),
    ),
  );
}

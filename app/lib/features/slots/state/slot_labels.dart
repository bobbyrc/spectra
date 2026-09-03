import 'package:chameleon/chameleon.dart';

import '../../../l10n/app_localizations.dart';
import 'slot_view.dart';

/// How a slot's SDK enums become words.
///
/// Tag-type product names are deliberately **not** in `app_en.arb`: they are
/// the names printed on the parts (proper nouns), not copy a translator
/// would ever change. Only the empty placeholder and the two sense names —
/// which are English words — go through localization (spec 7.6).
///
/// The switch is exhaustive over `TagType`, so a tag type added to the SDK
/// is a compile error here rather than a blank cell in the UI.
String tagTypeLabel(TagType type, AppLocalizations l10n) => switch (type) {
  TagType.undefined => l10n.slotTypeEmpty,
  TagType.em410x => 'EM410x',
  TagType.em410xElectra => 'EM410x Electra',
  TagType.pac => 'PAC/Stanley',
  TagType.viking => 'Viking',
  TagType.jablotron => 'Jablotron',
  TagType.hidProx => 'HID Prox',
  TagType.ioProx => 'ioProx',
  TagType.idteck => 'Idteck',
  TagType.mifareMini => 'MIFARE Classic Mini',
  TagType.mifare1k => 'MIFARE Classic 1K',
  TagType.mifare2k => 'MIFARE Classic 2K',
  TagType.mifare4k => 'MIFARE Classic 4K',
  TagType.ntag213 => 'NTAG213',
  TagType.ntag215 => 'NTAG215',
  TagType.ntag216 => 'NTAG216',
  TagType.mf0icu1 => 'Ultralight',
  TagType.mf0icu2 => 'Ultralight C',
  TagType.mf0ul11 => 'Ultralight EV1 (11)',
  TagType.mf0ul21 => 'Ultralight EV1 (21)',
  TagType.ntag210 => 'NTAG210',
  TagType.ntag212 => 'NTAG212',
  TagType.hf14a4 => 'ISO14443-4',
  TagType.seos => 'SEOS',
};

String senseLabel(Sense sense, AppLocalizations l10n) => switch (sense) {
  Sense.hf => l10n.slotSenseHf,
  Sense.lf => l10n.slotSenseLf,
  // Never rendered: `Sense.none` is the wire's "no sense named", not a
  // side of a slot the UI ever shows.
  Sense.none => l10n.slotTypeEmpty,
};

/// The tag types the user may put in a slot, derived from the SDK's own
/// families rather than a hand-typed list.
///
/// `TagFamily.iso14443_4` and `TagFamily.seos` are excluded: the SDK has no
/// emulator support for them (`FakeFirmware._dispatch` answers the whole
/// `CommandRange.iso14443_4` range with NOT_IMPLEMENTED, and
/// `FakeFirmwareConfig.defaultCapabilities` advertises none of 6000-6005),
/// so offering them would be a type the app could set but never fill.
List<TagType> selectableTypes(Sense sense) => TagType.values
    .where(
      (TagType t) =>
          t != TagType.undefined &&
          switch (sense) {
            Sense.hf =>
              t.family == TagFamily.mifareClassic ||
                  t.family == TagFamily.ultralight,
            Sense.lf => t.family == TagFamily.lf,
            Sense.none => false,
          },
    )
    .toList(growable: false);

/// The type labels a slot tile shows, HF first, empty for an empty slot.
List<String> slotTypeLabels(SlotView view, AppLocalizations l10n) => view
    .presentTypes
    .map((TagType t) => tagTypeLabel(t, l10n))
    .toList(growable: false);

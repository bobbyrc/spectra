import 'package:chameleon/chameleon.dart';

import '../../l10n/app_localizations.dart';

/// How the SDK's tag and sense enums become words.
///
/// Not a Slots-feature concern: a card, a dictionary or a dump reads the
/// same tag type, and every one of them must call it the same thing
/// (R28), so the naming lives in core rather than in whichever feature
/// happened to need it first.
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

/// The labels for the types a slot actually carries, in the order given —
/// `SlotView.presentTypes` is HF first, and empty for an empty slot.
List<String> slotTypeLabels(Iterable<TagType> types, AppLocalizations l10n) =>
    types.map((TagType t) => tagTypeLabel(t, l10n)).toList(growable: false);

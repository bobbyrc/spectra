import 'dart:convert';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';

import '../../slots/slots.dart' show slotNicknameMaxBytes;

/// What a tag type supports, on the device and on a card (spec 7.7 step 5).
///
/// Every branch in this phase reads one of these two enums, so "Spectra
/// cannot do that yet" is a typed state the UI renders rather than a null,
/// an exception or a disabled button with no explanation. Spec 8.5's
/// one-public-type rule is knowingly relaxed for this file: these are one
/// cohesive concern — what may be written where — and splitting them would
/// add files without adding clarity.

/// How a dump is loaded into an emulation slot, through `EmulatorFacade`.
enum SlotLoadMethod {
  /// `EmulatorFacade.writeMf1Blocks` plus `setAntiColl`.
  mifareClassicBlocks,

  /// `EmulatorFacade.writeNtagPages`. No anti-collision call: the firmware
  /// derives the emulated UID from pages 0-2 of the data itself.
  ultralightPages,

  /// `EmulatorFacade.setLfId(TagType.em410x, id)`.
  em410xId,

  /// The device has no emulation for this type, or the SDK has no way to
  /// fill it. A typed state, not an error.
  unsupported,
}

/// How a dump is written back onto a physical card, through `ReaderFacade`.
enum CardWriteMethod {
  /// `ReaderFacade.mf1WriteDump`.
  mifareClassicBlocks,

  /// `ReaderFacade.em410xWriteToT55xx` — the id goes onto a T55xx blank,
  /// which is what "write an EM410x" means in practice: an EM4100 itself is
  /// read-only.
  em410xT55xx,

  /// No reader write exists for this type. Ultralight is here: spec 8.1's
  /// `ReaderFacade` has no Ultralight write operation, and
  /// `EmulatorFacade.writeNtagPages` writes the *device's* emulation memory,
  /// not a card in the field. Adding one is spec 8.2's extension point —
  /// one command plus one facade method — not an app-side workaround.
  unsupported,
}

/// The emulator write for [type]'s dump, or [SlotLoadMethod.unsupported]
/// when there is none.
///
/// LF is deliberately narrower than the device: `EmulatorFacade._lfIdCommands`
/// (`packages/chameleon/lib/src/session/facades/emulator.dart`) can set an
/// id for em410x, hidProx, viking, pac, jablotron and idteck alike, but the
/// read screen only ever produces an EM410x LF dump — Spectra has no reader
/// path for the other five today, so a saved card can never actually carry
/// one. Returning `unsupported` for them is a deliberate v1 scope decision,
/// not an oversight (Phase 7 ruling 11), recorded in
/// `docs/research/DECISIONS.md`.
SlotLoadMethod slotLoadMethodFor(TagType type) => switch (type.family) {
  TagFamily.mifareClassic => SlotLoadMethod.mifareClassicBlocks,
  TagFamily.ultralight => SlotLoadMethod.ultralightPages,
  TagFamily.lf =>
    type == TagType.em410x
        ? SlotLoadMethod.em410xId
        : SlotLoadMethod.unsupported,
  TagFamily.undefined ||
  TagFamily.iso14443_4 ||
  TagFamily.seos => SlotLoadMethod.unsupported,
};

/// The reader write for [type]'s dump onto a physical card, or
/// [CardWriteMethod.unsupported] when there is none.
CardWriteMethod writeMethodFor(TagType type) => switch (type.family) {
  TagFamily.mifareClassic => CardWriteMethod.mifareClassicBlocks,
  TagFamily.lf =>
    type == TagType.em410x
        ? CardWriteMethod.em410xT55xx
        : CardWriteMethod.unsupported,
  TagFamily.ultralight ||
  TagFamily.undefined ||
  TagFamily.iso14443_4 ||
  TagFamily.seos => CardWriteMethod.unsupported,
};

/// The dump length this type's device-side memory expects, or 0 when there
/// is no known length. Both write paths check the bytes they were handed
/// against this before touching the device: a dump of the wrong size is a
/// stored row that was never valid, not a device failure.
int expectedDumpLength(TagType type) => switch (slotLoadMethodFor(type)) {
  SlotLoadMethod.mifareClassicBlocks => MifareGeometry.blockCount(type) * 16,
  SlotLoadMethod.ultralightPages => DumpFormats.ultralightPageCount(type) * 4,
  SlotLoadMethod.em410xId => 5,
  SlotLoadMethod.unsupported => 0,
};

/// A card name as a slot nickname: SET_SLOT_TAG_NICK takes at most
/// [slotNicknameMaxBytes] UTF-8 bytes and the SDK enforces that with an
/// `ArgumentError` — which is not a `ChameleonException` and would reach the
/// error catalog as "something unexpected went wrong". A card name is free
/// text, so it is truncated here rather than rejected.
///
/// Never returns an empty nickname (Phase 7 ruling 22): [cardName] is
/// trimmed first, and a blank result falls back to [fallbackLabel] — the
/// caller's tag-type label (`core/format/tag_labels.dart`'s `tagTypeLabel`),
/// the same fallback the quick-emulate path uses. This file stays pure Dart
/// with no `AppLocalizations` dependency, so the caller resolves the label
/// and hands over the plain string.
///
/// Truncation walks runes, not code units: cutting a UTF-8 sequence in half
/// would produce bytes the firmware cannot decode, and a surrogate pair
/// (every emoji) is two code units. A combining mark can still be separated
/// from its base character at the cut — a grapheme-cluster walk would need
/// `package:characters` for a case that costs one odd-looking nickname, so
/// this deliberately stops at runes.
String slotNicknameFor(String cardName, {required String fallbackLabel}) {
  final String trimmed = cardName.trim();
  final String source = trimmed.isEmpty ? fallbackLabel : trimmed;
  return _truncateUtf8(source, slotNicknameMaxBytes);
}

String _truncateUtf8(String value, int maxBytes) {
  if (utf8.encode(value).length <= maxBytes) return value;
  final StringBuffer out = StringBuffer();
  int used = 0;
  for (final int rune in value.runes) {
    final String char = String.fromCharCode(rune);
    final int size = utf8.encode(char).length;
    if (used + size > maxBytes) break;
    out.write(char);
    used += size;
  }
  return out.toString();
}

/// The anti-collision answer a MIFARE Classic dump implies.
///
/// Block 0 carries UID, BCC, SAK and ATQA in that order, which is the same
/// layout `MifareClassicFormat.describe` reads (`packages/chameleon/lib/src/
/// dump/mifare_classic.dart`): bytes 0-3 UID, 4 BCC, 5 SAK, 6-7 ATQA
/// little-endian on the wire. A 7-byte-UID card lays block 0 out
/// differently and is `hardware-validate` (checklist H1) — the same caveat
/// `MifareClassicDump.uid` already carries.
Hf14aTag antiCollForClassic(Uint8List blocks) => Hf14aTag(
  uid: Uint8List.fromList(blocks.sublist(0, 4)),
  atqa: Uint8List.fromList(<int>[blocks[7], blocks[6]]),
  sak: blocks[5],
  ats: Uint8List(0),
);

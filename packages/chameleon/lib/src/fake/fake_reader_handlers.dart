import 'dart:typed_data';

import '../codec/bytes.dart';
import '../codec/frame.dart';
import '../model/enums.dart';
import '../protocol/status.dart';
import 'fake_card.dart';
import 'fake_firmware.dart';

/// Reader commands (2000-2999 HF, 3000-3999 LF). They answer from the card
/// presented with `FakeFirmware.present`, and HF_TAG_NO / LF_TAG_NO_FOUND
/// when the field is empty.
extension FakeReaderHandlers on FakeFirmware {
  Frame handleHfReader(int cmd, ByteReader r) {
    switch (cmd) {
      case 2000:
        final c = hfCard;
        return switch (c) {
          FakeMf1Card() => okFrame(
            cmd,
            FakeFirmware.antiCollBytes(c.uid, c.atqa, c.sak, c.ats),
          ),
          FakeUltralightCard() => okFrame(
            cmd,
            FakeFirmware.antiCollBytes(
              c.uid,
              Uint8List.fromList([0x00, 0x44]),
              0x00,
              Uint8List(0),
            ),
          ),
          _ => statusFrame(cmd, Status.hfTagNo),
        };
      case 2001:
        return hfCard is FakeMf1Card
            ? okFrame(cmd)
            : statusFrame(cmd, Status.hfTagNo);
      case 2002:
        final c = hfCard;
        return c is FakeMf1Card
            ? okFrame(cmd, [c.prng.code])
            : statusFrame(cmd, Status.hfTagNo);
      case 2007:
        final c = hfCard;
        final type = KeyType.fromCode(r.u8());
        final block = r.u8();
        final key = r.bytes(6);
        if (c is! FakeMf1Card) return statusFrame(cmd, Status.hfTagNo);
        if (!c.authenticates(block, type, key)) {
          return statusFrame(cmd, Status.mfErrAuth);
        }
        return okFrame(cmd);
      case 2008:
        final c = hfCard;
        final type = KeyType.fromCode(r.u8());
        final block = r.u8();
        final key = r.bytes(6);
        if (c is! FakeMf1Card) return statusFrame(cmd, Status.hfTagNo);
        if (!c.authenticates(block, type, key)) {
          return statusFrame(cmd, Status.mfErrAuth);
        }
        final Uint8List read = c.blocks.sublist(block * 16, block * 16 + 16);
        // A real card never hands back key A: MF1_READ_ONE_BLOCK on a sector
        // trailer answers with bytes 0-5 zeroed, leaving only the access bits
        // (and whatever key B the access bits permit) meaningful. Callers get
        // the keys that actually work from `Mf1DumpReadResult.keys`.
        if (FakeMf1Card.isTrailer(block)) read.fillRange(0, 6, 0);
        return okFrame(cmd, read);
      case 2009:
        final c = hfCard;
        final type = KeyType.fromCode(r.u8());
        final block = r.u8();
        final key = r.bytes(6);
        final data = r.bytes(16);
        if (c is! FakeMf1Card) return statusFrame(cmd, Status.hfTagNo);
        if (!c.authenticates(block, type, key)) {
          return statusFrame(cmd, Status.mfErrAuth);
        }
        c.blocks.setRange(block * 16, block * 16 + 16, data);
        return okFrame(cmd);
      case 2012:
        return _checkKeys(cmd, r);
      case 2100 || 2101:
        return okFrame(cmd);
      default:
        return statusFrame(cmd, Status.notImplemented);
    }
  }

  Frame handleLfReader(int cmd, ByteReader r) {
    switch (cmd) {
      case 3000 || 3002 || 3004 || 3014:
        final c = lfCard;
        if (c is FakeLfCard && c.scanCommandId == cmd) {
          return okFrame(cmd, c.idBytes);
        }
        return statusFrame(cmd, Status.lfTagNoFound);
      case 3001:
        final id = r.bytes(5);
        r.bytes(4); // newKey: the fake keeps no password.
        final c = lfCard;
        // Only a card that answers EM410X_SCAN can be rewritten as one; a
        // field with nothing in it, or a HID/Viking/PAC card, is a miss.
        if (c is! FakeLfCard || c.scanCommandId != 3000) {
          return statusFrame(cmd, Status.lfTagNoFound);
        }
        c.idBytes.setRange(0, 5, id);
        return okFrame(cmd);
      default:
        return statusFrame(cmd, Status.notImplemented);
    }
  }

  /// MF1_CHECK_KEYS_OF_SECTORS: a 10-byte request mask of sector/key-type
  /// bits followed by candidate keys; the reply is a found mask and a
  /// 40-sector table of key A and key B.
  Frame _checkKeys(int cmd, ByteReader r) {
    final c = hfCard;
    if (c is! FakeMf1Card) return statusFrame(cmd, Status.hfTagNo);
    final mask = r.bytes(10);
    final keys = <Uint8List>[];
    while (r.remaining >= 6) {
      keys.add(r.bytes(6));
    }
    final found = Uint8List(10);
    final keyBytes = Uint8List(480);
    for (var s = 0; s < 40; s++) {
      for (final t in KeyType.values) {
        final i = s * 2 + (t == KeyType.a ? 0 : 1);
        if ((mask[i ~/ 8] & (0x80 >> (i % 8))) == 0) continue;
        for (final k in keys) {
          if (c.authenticates(s < 32 ? s * 4 : 128 + (s - 32) * 16, t, k)) {
            found[i ~/ 8] |= 0x80 >> (i % 8);
            keyBytes.setRange(i * 6, i * 6 + 6, k);
            break;
          }
        }
      }
    }
    return okFrame(cmd, ByteWriter().bytes(found).bytes(keyBytes).toBytes());
  }
}

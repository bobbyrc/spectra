# Phase 1: chameleon SDK Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `packages/chameleon`, the pure-Dart SDK: frame codec, typed command catalog, errors, models, transport interface, a firmware-faithful fake, the command dispatcher, the session state machine with cache and reader lease, domain facades, dump formats, and the Secure DFU stack, all proven by `dart test` with no hardware.

**Architecture:** Bottom-up layers, each testable alone. Codec turns bytes into `Frame`s. Commands encode and decode payloads and know their success status. `CommandDispatcher` owns one-in-flight, timeouts, cancellation and draining. `DeviceSession` runs the handshake, holds a state machine and caches, and exposes facades. `FakeFirmware` answers frames like the device; `FakeDevice` wraps it as a fragmenting `Transport`. DFU is a state machine over an abstract `DfuChannel` with a fake bootloader on the other side.

**Tech Stack:** Dart 3.13, `test`, `freezed` for models, `archive` and `crypto` for DFU packages, no Flutter.

**Spec:** `docs/superpowers/specs/2026-09-02-spectra-design.md` sections 3, 4, 8.1, 8.2, 9, 10. Wire facts: `docs/research/chameleon-protocol.md`.

## Global Constraints

- `packages/chameleon` imports only `dart:*`, `meta`, `collection`, `freezed_annotation`, `archive`, `crypto` (spec section 2). `tool/dep_lint.dart` enforces it.
- Frame: SOF 0x11, LRC1, CMD u16 BE, STATUS u16 BE, LEN u16 BE, LRC2 over bytes 2..7, DATA, LRC3 over DATA. LRC = (0x100 - (sum & 0xFF)) & 0xFF. Max DATA 4096.
- Success status: 0x68 for 1xxx, 4xxx, 5xxx; 0x00 for 2xxx; 0x40 for 3xxx; 0x00 for 6xxx pending hardware validation.
- Handshake to `ready` requires only commands 1035, 1000, 1033. Everything else is background and tolerant.
- Exactly one fake, at the transport level. Every test above it uses the real `DeviceSession`.
- Commands are internal (`lib/src/commands/`), never exported from `lib/chameleon.dart`.
- Decoders never throw raw `RangeError`; short payloads become `MalformedResponse`.
- Run tests as `cd packages/chameleon && mise x -- dart test`. Run codegen as `mise x -- dart run build_runner build --delete-conflicting-outputs`. Commit generated files.
- Commit after every task with the trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Commands whose wire format the notes mark uncertain carry `/// hardware-validate` in their doc comment and their tests are tagged `@Tags(['hardware-validate'])` so they are easy to list.

---

## File structure

```
packages/chameleon/lib/
  chameleon.dart                      public barrel (no commands exported)
  src/codec/lrc.dart                  lrc()
  src/codec/frame.dart                Frame, encode
  src/codec/frame_decoder.dart        FrameDecoder, DecodeDiagnostic
  src/codec/bytes.dart                ByteReader, ByteWriter
  src/protocol/status.dart            Status constants
  src/protocol/errors.dart            ChameleonException hierarchy
  src/protocol/command.dart           Command<R>, VoidCommand, CommandRange
  src/model/enums.dart                TagType, TagFamily, Sense, DeviceModel, DeviceMode, ...
  src/model/models.dart               freezed models (DeviceInfo, Slot, ...)
  src/commands/device.dart            1000-1040
  src/commands/hf_reader.dart         2000-2201
  src/commands/lf_reader.dart         3000-3032
  src/commands/hf_emulator.dart       4000-4044
  src/commands/lf_emulator.dart       5000-5013
  src/commands/iso14443_4.dart        6000-6005
  src/transport/transport.dart        Transport, TransportState, CloseCause, TransportKind
  src/transport/scanner.dart          DeviceScanner, DiscoveredDevice
  src/transport/frame_log.dart        FrameLog ring buffer
  src/fake/fake_firmware.dart         FakeFirmware: Frame in, Frame out
  src/fake/fake_card.dart             FakeCard for scripted reader results
  src/fake/fake_device.dart           FakeDevice: Transport around FakeFirmware
  src/fake/fake_scanner.dart          FakeScanner
  src/session/cancel_token.dart       CancelToken
  src/session/dispatcher.dart         CommandDispatcher
  src/session/state_stream.dart       StateStream<T>
  src/session/connection_state.dart   ConnectionState, DisconnectCause
  src/session/reader_lease.dart       ReaderLease
  src/session/device_session.dart     DeviceSession
  src/session/facades/device.dart     DeviceFacade
  src/session/facades/slots.dart      SlotsFacade
  src/session/facades/settings.dart   SettingsFacade
  src/session/facades/emulator.dart   EmulatorFacade
  src/session/facades/reader.dart     ReaderFacade
  src/session/facades/firmware.dart   FirmwareFacade
  src/dump/dump_format.dart           DumpFormat, CardDump, DumpField, DumpFormats
  src/dump/mifare_classic.dart        MifareClassicDump
  src/dump/ultralight.dart            UltralightDump
  src/dump/em410x.dart                Em410xDump
  src/dfu/dfu_package.dart            DfuPackage, InitPacket
  src/dfu/protobuf_reader.dart        minimal protobuf wire reader
  src/dfu/dfu_channel.dart            DfuChannel
  src/dfu/secure_dfu.dart             SecureDfu state machine, DfuProgress, DfuError
  src/dfu/fake_bootloader.dart        FakeBootloader, FakeDfuChannel
  src/dfu/dfu_orchestrator.dart       DfuOrchestrator
packages/chameleon/test/              one test file per source file, same names
```

---

### Task 1: Dependencies, LRC and frame encoding

**Files:**
- Modify: `packages/chameleon/pubspec.yaml`
- Create: `lib/src/codec/lrc.dart`, `lib/src/codec/frame.dart`, `test/codec/lrc_test.dart`, `test/codec/frame_test.dart`

**Interfaces:**
- Produces: `int lrc(Iterable<int> bytes)`; `class Frame { int command; int status; Uint8List data; Uint8List encode(); }`; constants `frameSof`, `frameHeaderLength`, `frameMaxDataLength`.

- [ ] **Step 1: Add dependencies**

Run in `packages/chameleon`:

```bash
mise x -- dart pub add meta collection freezed_annotation archive crypto
mise x -- dart pub add dev:test dev:fake_async dev:build_runner dev:freezed
```

- [ ] **Step 2: Write the failing tests**

```dart
// test/codec/lrc_test.dart
import 'package:chameleon/src/codec/lrc.dart';
import 'package:test/test.dart';

void main() {
  test('lrc of SOF is 0xEF', () => expect(lrc([0x11]), 0xEF));
  test('lrc of empty is 0x00', () => expect(lrc([]), 0x00));
  test('lrc of enter-bootloader header is 0x0B', () {
    expect(lrc([0x03, 0xF2, 0x00, 0x00, 0x00, 0x00]), 0x0B);
  });
  test('lrc wraps sums above 0xFF', () => expect(lrc([0xFF, 0x02]), 0xFF));
}
```

```dart
// test/codec/frame_test.dart
import 'dart:typed_data';

import 'package:chameleon/src/codec/frame.dart';
import 'package:test/test.dart';

void main() {
  test('encodes ENTER_BOOTLOADER exactly as documented', () {
    final bytes = Frame(command: 1010).encode();
    expect(bytes, [0x11, 0xEF, 0x03, 0xF2, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x00]);
  });

  test('encodes payload with trailing LRC', () {
    final bytes = Frame(command: 1003, data: Uint8List.fromList([0x02])).encode();
    expect(bytes.length, 11);
    expect(bytes.sublist(2, 4), [0x03, 0xEB]);
    expect(bytes.sublist(6, 8), [0x00, 0x01]);
    expect(bytes[9], 0x02);
    expect(bytes[10], 0xFE);
  });

  test('frames with equal fields are equal', () {
    final a = Frame(command: 1, status: 2, data: Uint8List.fromList([3]));
    final b = Frame(command: 1, status: 2, data: Uint8List.fromList([3]));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `mise x -- dart test test/codec`
Expected: FAIL, files not found.

- [ ] **Step 4: Implement**

```dart
// lib/src/codec/lrc.dart
/// Longitudinal redundancy check used by the Chameleon frame format:
/// `(0x100 - (sum(bytes) & 0xFF)) & 0xFF`.
int lrc(Iterable<int> bytes) {
  var sum = 0;
  for (final b in bytes) {
    sum = (sum + b) & 0xFF;
  }
  return (0x100 - sum) & 0xFF;
}
```

```dart
// lib/src/codec/frame.dart
import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'lrc.dart';

const int frameSof = 0x11;
const int frameHeaderLength = 9;
const int frameMaxDataLength = 4096;

/// One protocol frame, either direction. Requests carry status 0.
final class Frame {
  Frame({required this.command, this.status = 0, Uint8List? data})
      : data = data ?? Uint8List(0);

  final int command;
  final int status;
  final Uint8List data;

  Uint8List encode() {
    final len = data.length;
    if (len > frameMaxDataLength) {
      throw ArgumentError.value(len, 'data', 'exceeds $frameMaxDataLength');
    }
    final out = Uint8List(frameHeaderLength + len + 1);
    out[0] = frameSof;
    out[1] = lrc(const [frameSof]);
    out[2] = (command >> 8) & 0xFF;
    out[3] = command & 0xFF;
    out[4] = (status >> 8) & 0xFF;
    out[5] = status & 0xFF;
    out[6] = (len >> 8) & 0xFF;
    out[7] = len & 0xFF;
    out[8] = lrc(out.sublist(2, 8));
    out.setRange(frameHeaderLength, frameHeaderLength + len, data);
    out[frameHeaderLength + len] = lrc(data);
    return out;
  }

  static const _eq = ListEquality<int>();

  @override
  bool operator ==(Object other) =>
      other is Frame &&
      other.command == command &&
      other.status == status &&
      _eq.equals(other.data, data);

  @override
  int get hashCode => Object.hash(command, status, _eq.hash(data));

  @override
  String toString() =>
      'Frame(cmd=$command status=0x${status.toRadixString(16)} len=${data.length})';
}
```

- [ ] **Step 5: Run to verify pass**

Run: `mise x -- dart test test/codec`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add packages/chameleon pubspec.lock
git commit -m "feat(chameleon): add LRC and frame encoder

Byte-exact against the documented ENTER_BOOTLOADER frame."
```

---

### Task 2: Frame decoder

**Files:**
- Create: `lib/src/codec/frame_decoder.dart`, `test/codec/frame_decoder_test.dart`

**Interfaces:**
- Produces: `class FrameDecoder { FrameDecoder({void Function(DecodeDiagnostic)? onDiagnostic}); List<Frame> feed(List<int> bytes); }` and `sealed class DecodeDiagnostic` with `ResyncDiagnostic(droppedBytes)`, `BadLrcDiagnostic(which)`, `OversizedFrameDiagnostic(length)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/codec/frame_decoder_test.dart
import 'dart:typed_data';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/codec/frame_decoder.dart';
import 'package:chameleon/src/codec/lrc.dart';
import 'package:test/test.dart';

Uint8List bytes(List<int> l) => Uint8List.fromList(l);

void main() {
  final f1 = Frame(command: 1000, status: 0x68, data: bytes([2, 0]));
  final f2 = Frame(command: 1018, status: 0x68, data: bytes([3]));

  test('decodes one frame from one chunk', () {
    expect(FrameDecoder().feed(f1.encode()), [f1]);
  });

  test('decodes two frames from one chunk', () {
    expect(FrameDecoder().feed([...f1.encode(), ...f2.encode()]), [f1, f2]);
  });

  test('reassembles a frame fed one byte at a time', () {
    final d = FrameDecoder();
    final enc = f1.encode();
    final out = <Frame>[];
    for (final b in enc) {
      out.addAll(d.feed([b]));
    }
    expect(out, [f1]);
  });

  test('skips garbage before SOF and reports resync', () {
    final diags = <DecodeDiagnostic>[];
    final d = FrameDecoder(onDiagnostic: diags.add);
    expect(d.feed([0xAA, 0xBB, ...f1.encode()]), [f1]);
    expect(diags.single, isA<ResyncDiagnostic>().having((r) => r.droppedBytes, 'dropped', 2));
  });

  test('recovers from a corrupted header LRC', () {
    final diags = <DecodeDiagnostic>[];
    final d = FrameDecoder(onDiagnostic: diags.add);
    final bad = f1.encode()..[8] ^= 0xFF;
    expect(d.feed([...bad, ...f2.encode()]), [f2]);
    expect(diags.whereType<BadLrcDiagnostic>(), isNotEmpty);
  });

  test('drops a frame with a bad data LRC', () {
    final d = FrameDecoder();
    final bad = f1.encode();
    bad[bad.length - 1] ^= 0x01;
    expect(d.feed([...bad, ...f2.encode()]), [f2]);
  });

  test('rejects oversized LEN and resyncs', () {
    final diags = <DecodeDiagnostic>[];
    final d = FrameDecoder(onDiagnostic: diags.add);
    final enc = f1.encode();
    enc[6] = 0x20; // LEN = 0x2000
    enc[8] = lrc(enc.sublist(2, 8));
    expect(d.feed([...enc, ...f2.encode()]), [f2]);
    expect(diags.whereType<OversizedFrameDiagnostic>().single.length, 0x2000);
  });

  test('decodes a maximum-size payload', () {
    final big = Frame(command: 4008, status: 0x68, data: Uint8List(4096));
    expect(FrameDecoder().feed(big.encode()), [big]);
  });
}

```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/codec/frame_decoder_test.dart`
Expected: FAIL, file not found.

- [ ] **Step 3: Implement**

```dart
// lib/src/codec/frame_decoder.dart
import 'dart:typed_data';

import 'frame.dart';
import 'lrc.dart';

sealed class DecodeDiagnostic {
  const DecodeDiagnostic();
}

final class ResyncDiagnostic extends DecodeDiagnostic {
  const ResyncDiagnostic(this.droppedBytes);
  final int droppedBytes;
}

final class BadLrcDiagnostic extends DecodeDiagnostic {
  const BadLrcDiagnostic(this.which);

  /// 'sof', 'header' or 'data'.
  final String which;
}

final class OversizedFrameDiagnostic extends DecodeDiagnostic {
  const OversizedFrameDiagnostic(this.length);
  final int length;
}

/// Byte-stream state machine. Feed it chunks of any size; it returns the
/// complete frames found so far and keeps the remainder. It never throws on
/// bad input: it drops bytes, reports a diagnostic and resyncs on SOF.
final class FrameDecoder {
  FrameDecoder({void Function(DecodeDiagnostic)? onDiagnostic})
      : _onDiagnostic = onDiagnostic;

  final void Function(DecodeDiagnostic)? _onDiagnostic;
  final List<int> _buf = [];

  List<Frame> feed(List<int> bytes) {
    _buf.addAll(bytes);
    final frames = <Frame>[];
    while (true) {
      final sof = _buf.indexOf(frameSof);
      if (sof < 0) {
        if (_buf.isNotEmpty) {
          _report(ResyncDiagnostic(_buf.length));
          _buf.clear();
        }
        return frames;
      }
      if (sof > 0) {
        _report(ResyncDiagnostic(sof));
        _buf.removeRange(0, sof);
      }
      if (_buf.length < frameHeaderLength) return frames;
      if (_buf[1] != lrc(const [frameSof])) {
        _dropOne(const BadLrcDiagnostic('sof'));
        continue;
      }
      if (_buf[8] != lrc(_buf.sublist(2, 8))) {
        _dropOne(const BadLrcDiagnostic('header'));
        continue;
      }
      final len = (_buf[6] << 8) | _buf[7];
      if (len > frameMaxDataLength) {
        _dropOne(OversizedFrameDiagnostic(len));
        continue;
      }
      final total = frameHeaderLength + len + 1;
      if (_buf.length < total) return frames;
      final data = Uint8List.fromList(_buf.sublist(frameHeaderLength, frameHeaderLength + len));
      if (_buf[frameHeaderLength + len] != lrc(data)) {
        _dropOne(const BadLrcDiagnostic('data'));
        continue;
      }
      frames.add(Frame(
        command: (_buf[2] << 8) | _buf[3],
        status: (_buf[4] << 8) | _buf[5],
        data: data,
      ));
      _buf.removeRange(0, total);
    }
  }

  void _dropOne(DecodeDiagnostic why) {
    _report(why);
    _buf.removeAt(0);
  }

  void _report(DecodeDiagnostic d) => _onDiagnostic?.call(d);
}
```

- [ ] **Step 4: Run to verify pass**

Run: `mise x -- dart test test/codec/frame_decoder_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): add resyncing frame decoder

Fragmentation and noise are normal on BLE, so the decoder drops and
reports instead of throwing."
```

---

### Task 3: Byte helpers, status codes and the error hierarchy

**Files:**
- Create: `lib/src/codec/bytes.dart`, `lib/src/protocol/status.dart`, `lib/src/protocol/errors.dart`, `test/codec/bytes_test.dart`, `test/protocol/errors_test.dart`

**Interfaces:**
- Produces: `ByteReader(Uint8List)` with `u8() u16() u32() bytes(n) rest() utf8String(n) remaining isAtEnd`; `ByteWriter` with chainable `u8 u16 u32 bytes utf8String` and `toBytes()`; `Status` constants; sealed `ChameleonException` tree with `DeviceError.fromStatus(int)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/codec/bytes_test.dart
import 'dart:typed_data';

import 'package:chameleon/src/codec/bytes.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:test/test.dart';

void main() {
  test('reads big-endian integers in order', () {
    final r = ByteReader(Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]));
    expect(r.u8(), 0x01);
    expect(r.u16(), 0x0203);
    expect(r.u32(), 0x04050607);
    expect(r.isAtEnd, isTrue);
  });

  test('short read throws MalformedResponse', () {
    final r = ByteReader(Uint8List.fromList([0x01]));
    expect(() => r.u16(), throwsA(isA<MalformedResponse>()));
  });

  test('writer round-trips', () {
    final b = ByteWriter().u8(1).u16(0x0203).u32(0x04050607).utf8String('hi').toBytes();
    expect(b, [1, 2, 3, 4, 5, 6, 7, 0x68, 0x69]);
  });
}
```

```dart
// test/protocol/errors_test.dart
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/protocol/status.dart';
import 'package:test/test.dart';

void main() {
  test('maps every documented status to a typed error', () {
    expect(DeviceError.fromStatus(Status.hfTagNo), isA<HfTagNotFound>());
    expect(DeviceError.fromStatus(Status.hfErrCrc),
        isA<HfTagError>().having((e) => e.kind, 'kind', HfTagErrorKind.crc));
    expect(DeviceError.fromStatus(Status.mfErrAuth), isA<AuthenticationFailed>());
    expect(DeviceError.fromStatus(Status.lfTagNoFound), isA<LfTagNotFound>());
    expect(DeviceError.fromStatus(Status.lfTagLoginRequired), isA<LfLoginRequired>());
    expect(DeviceError.fromStatus(Status.parErr), isA<ParameterError>());
    expect(DeviceError.fromStatus(Status.deviceModeError), isA<DeviceModeError>());
    expect(DeviceError.fromStatus(Status.invalidCmd), isA<InvalidCommand>());
    expect(DeviceError.fromStatus(Status.notImplemented), isA<NotImplemented>());
    expect(DeviceError.fromStatus(Status.flashWriteFail), isA<FlashWriteFailed>());
    expect(DeviceError.fromStatus(Status.flashReadFail), isA<FlashReadFailed>());
    expect(DeviceError.fromStatus(Status.invalidSlotType), isA<InvalidSlotType>());
    expect(DeviceError.fromStatus(Status.memErr), isA<MemoryError>());
    expect(DeviceError.fromStatus(Status.createResponseErr), isA<CreateResponseError>());
    expect(DeviceError.fromStatus(Status.cmdErr), isA<CommandFailed>());
  });

  test('unknown status keeps its code', () {
    final e = DeviceError.fromStatus(0x99);
    expect(e, isA<UnknownDeviceError>());
    expect(e.code, 0x99);
  });

  test('every error is a ChameleonException with a message', () {
    expect(const Disconnected(), isA<ChameleonException>());
    expect(CommandTimeout(1000, const Duration(seconds: 3)).message, contains('3e8'));
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/codec/bytes_test.dart test/protocol/errors_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/src/codec/bytes.dart
import 'dart:convert';
import 'dart:typed_data';

import '../protocol/errors.dart';

/// Sequential big-endian reader. Short reads throw [MalformedResponse].
final class ByteReader {
  ByteReader(this._data);
  final Uint8List _data;
  int _offset = 0;

  int get remaining => _data.length - _offset;
  bool get isAtEnd => remaining == 0;

  int u8() {
    _need(1);
    return _data[_offset++];
  }

  int u16() {
    _need(2);
    final v = (_data[_offset] << 8) | _data[_offset + 1];
    _offset += 2;
    return v;
  }

  int u32() {
    _need(4);
    final v = (_data[_offset] << 24) |
        (_data[_offset + 1] << 16) |
        (_data[_offset + 2] << 8) |
        _data[_offset + 3];
    _offset += 4;
    return v;
  }

  Uint8List bytes(int n) {
    _need(n);
    final out = Uint8List.fromList(_data.sublist(_offset, _offset + n));
    _offset += n;
    return out;
  }

  Uint8List rest() => bytes(remaining);

  String utf8String(int n) => utf8.decode(bytes(n), allowMalformed: true);

  void _need(int n) {
    if (remaining < n) {
      throw MalformedResponse('needed $n byte(s), had $remaining');
    }
  }
}

/// Chainable big-endian writer.
final class ByteWriter {
  final BytesBuilder _b = BytesBuilder(copy: false);

  ByteWriter u8(int v) {
    _b.addByte(v & 0xFF);
    return this;
  }

  ByteWriter u16(int v) => u8(v >> 8).u8(v);

  ByteWriter u32(int v) => u16(v >> 16).u16(v);

  ByteWriter bytes(List<int> v) {
    _b.add(v);
    return this;
  }

  ByteWriter utf8String(String s) => bytes(utf8.encode(s));

  Uint8List toBytes() => _b.toBytes();
}
```

```dart
// lib/src/protocol/status.dart
/// Firmware status codes (app_status.h).
abstract final class Status {
  static const int hfTagOk = 0x00;
  static const int hfTagNo = 0x01;
  static const int hfErrStat = 0x02;
  static const int hfErrCrc = 0x03;
  static const int hfCollision = 0x04;
  static const int hfErrBcc = 0x05;
  static const int mfErrAuth = 0x06;
  static const int hfErrParity = 0x07;
  static const int hfErrAts = 0x08;
  static const int lfTagOk = 0x40;
  static const int lfTagNoFound = 0x41;
  static const int lfTagLoginRequired = 0x42;
  static const int parErr = 0x60;
  static const int deviceModeError = 0x66;
  static const int invalidCmd = 0x67;
  static const int success = 0x68;
  static const int notImplemented = 0x69;
  static const int flashWriteFail = 0x70;
  static const int flashReadFail = 0x71;
  static const int invalidSlotType = 0x72;
  static const int memErr = 0x73;
  static const int createResponseErr = 0x74;
  static const int cmdErr = 0x75;
}
```

```dart
// lib/src/protocol/errors.dart
import 'status.dart';

/// Root of every error the SDK raises.
sealed class ChameleonException implements Exception {
  const ChameleonException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// A response payload that did not match the expected shape.
final class MalformedResponse extends ChameleonException {
  const MalformedResponse(super.message);
}

final class CommandTimeout extends ChameleonException {
  CommandTimeout(this.commandId, this.timeout)
      : super('command 0x${commandId.toRadixString(16)} timed out after $timeout');
  final int commandId;
  final Duration timeout;
}

final class CommandCancelled extends ChameleonException {
  const CommandCancelled() : super('command cancelled');
}

final class SessionNotReady extends ChameleonException {
  const SessionNotReady(super.message);
}

enum UnsupportedReason { preTwoPointZero, newerMajor, legacyMustUpdate }

final class UnsupportedFirmware extends ChameleonException {
  const UnsupportedFirmware(this.reason, super.message);
  final UnsupportedReason reason;
}

sealed class TransportError extends ChameleonException {
  const TransportError(super.message);
}

final class Disconnected extends TransportError {
  const Disconnected([super.message = 'transport closed']);
}

final class PermissionDenied extends TransportError {
  const PermissionDenied([super.message = 'permission denied']);
}

final class PortBusy extends TransportError {
  const PortBusy([super.message = 'port busy']);
}

final class DeviceNotFound extends TransportError {
  const DeviceNotFound([super.message = 'device not found']);
}

final class PairingRequired extends TransportError {
  const PairingRequired([super.message = 'pairing required']);
}

final class AdapterOff extends TransportError {
  const AdapterOff([super.message = 'adapter off']);
}

enum HfTagErrorKind {
  generic(Status.hfErrStat),
  crc(Status.hfErrCrc),
  collision(Status.hfCollision),
  bcc(Status.hfErrBcc),
  parity(Status.hfErrParity),
  ats(Status.hfErrAts);

  const HfTagErrorKind(this.code);
  final int code;
}

/// A non-success status returned by the firmware.
sealed class DeviceError extends ChameleonException {
  const DeviceError(this.code, super.message);
  final int code;

  factory DeviceError.fromStatus(int code) => switch (code) {
        Status.hfTagNo => const HfTagNotFound(),
        Status.hfErrStat => const HfTagError(HfTagErrorKind.generic),
        Status.hfErrCrc => const HfTagError(HfTagErrorKind.crc),
        Status.hfCollision => const HfTagError(HfTagErrorKind.collision),
        Status.hfErrBcc => const HfTagError(HfTagErrorKind.bcc),
        Status.hfErrParity => const HfTagError(HfTagErrorKind.parity),
        Status.hfErrAts => const HfTagError(HfTagErrorKind.ats),
        Status.mfErrAuth => const AuthenticationFailed(),
        Status.lfTagNoFound => const LfTagNotFound(),
        Status.lfTagLoginRequired => const LfLoginRequired(),
        Status.parErr => const ParameterError(),
        Status.deviceModeError => const DeviceModeError(),
        Status.invalidCmd => const InvalidCommand(),
        Status.notImplemented => const NotImplemented(),
        Status.flashWriteFail => const FlashWriteFailed(),
        Status.flashReadFail => const FlashReadFailed(),
        Status.invalidSlotType => const InvalidSlotType(),
        Status.memErr => const MemoryError(),
        Status.createResponseErr => const CreateResponseError(),
        Status.cmdErr => const CommandFailed(),
        _ => UnknownDeviceError(code),
      };
}

final class HfTagNotFound extends DeviceError {
  const HfTagNotFound() : super(Status.hfTagNo, 'no HF tag found');
}

final class HfTagError extends DeviceError {
  const HfTagError(this.kind) : super(kind.code, 'HF tag error');
  final HfTagErrorKind kind;
}

final class AuthenticationFailed extends DeviceError {
  const AuthenticationFailed() : super(Status.mfErrAuth, 'authentication failed');
}

final class LfTagNotFound extends DeviceError {
  const LfTagNotFound() : super(Status.lfTagNoFound, 'no LF tag found');
}

final class LfLoginRequired extends DeviceError {
  const LfLoginRequired() : super(Status.lfTagLoginRequired, 'LF tag requires login');
}

final class ParameterError extends DeviceError {
  const ParameterError() : super(Status.parErr, 'parameter error');
}

final class DeviceModeError extends DeviceError {
  const DeviceModeError() : super(Status.deviceModeError, 'wrong device mode');
}

final class InvalidCommand extends DeviceError {
  const InvalidCommand() : super(Status.invalidCmd, 'invalid command');
}

final class NotImplemented extends DeviceError {
  const NotImplemented() : super(Status.notImplemented, 'not implemented');
}

final class FlashWriteFailed extends DeviceError {
  const FlashWriteFailed() : super(Status.flashWriteFail, 'flash write failed');
}

final class FlashReadFailed extends DeviceError {
  const FlashReadFailed() : super(Status.flashReadFail, 'flash read failed');
}

final class InvalidSlotType extends DeviceError {
  const InvalidSlotType() : super(Status.invalidSlotType, 'invalid slot type');
}

final class MemoryError extends DeviceError {
  const MemoryError() : super(Status.memErr, 'memory error');
}

final class CreateResponseError extends DeviceError {
  const CreateResponseError() : super(Status.createResponseErr, 'create response error');
}

final class CommandFailed extends DeviceError {
  const CommandFailed() : super(Status.cmdErr, 'command error');
}

final class UnknownDeviceError extends DeviceError {
  UnknownDeviceError(int code) : super(code, 'unknown status 0x${code.toRadixString(16)}');
}
```

- [ ] **Step 4: Run to verify pass**

Run: `mise x -- dart test test/codec test/protocol`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): add byte helpers, status codes and typed errors

Callers never see raw status integers (spec 3.3)."
```

---

### Task 4: Command base and ranges

**Files:**
- Create: `lib/src/protocol/command.dart`, `test/protocol/command_test.dart`

**Interfaces:**
- Produces:

```dart
enum CommandRange { device, hfReader, lfReader, hfEmulator, lfEmulator, iso14443_4; int successStatus; static CommandRange forId(int) }
abstract base class Command<R> {
  int get id; CommandRange get range; Duration get timeout; bool get idempotent; bool get expectsResponse;
  Uint8List encode(); R decode(Uint8List data); R parseResponse(Frame frame); Frame toFrame();
}
abstract base class VoidCommand extends Command<void>
```

- [ ] **Step 1: Write the failing tests**

```dart
// test/protocol/command_test.dart
import 'dart:typed_data';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/protocol/command.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:test/test.dart';

final class _Echo extends Command<int> {
  const _Echo();
  @override
  int get id => 1018;
  @override
  int decode(Uint8List data) => data[0];
}

void main() {
  test('ranges map ids to success statuses', () {
    expect(CommandRange.forId(1000).successStatus, 0x68);
    expect(CommandRange.forId(2000).successStatus, 0x00);
    expect(CommandRange.forId(3000).successStatus, 0x40);
    expect(CommandRange.forId(4000).successStatus, 0x68);
    expect(CommandRange.forId(5000).successStatus, 0x68);
    expect(CommandRange.forId(6000).successStatus, 0x00);
    expect(() => CommandRange.forId(7000), throwsArgumentError);
  });

  test('parseResponse decodes on success status', () {
    final f = Frame(command: 1018, status: 0x68, data: Uint8List.fromList([5]));
    expect(const _Echo().parseResponse(f), 5);
  });

  test('parseResponse throws a typed DeviceError on failure status', () {
    final f = Frame(command: 1018, status: 0x67);
    expect(() => const _Echo().parseResponse(f), throwsA(isA<InvalidCommand>()));
  });

  test('parseResponse rejects a frame for another command', () {
    final f = Frame(command: 1000, status: 0x68, data: Uint8List.fromList([5]));
    expect(() => const _Echo().parseResponse(f), throwsA(isA<MalformedResponse>()));
  });

  test('defaults: 3s timeout, not idempotent, expects response, empty payload', () {
    const c = _Echo();
    expect(c.timeout, const Duration(seconds: 3));
    expect(c.idempotent, isFalse);
    expect(c.expectsResponse, isTrue);
    expect(c.encode(), isEmpty);
    expect(c.toFrame(), Frame(command: 1018));
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/protocol/command_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/src/protocol/command.dart
import 'dart:typed_data';

import '../codec/frame.dart';
import 'errors.dart';

/// Firmware command ranges and the status value each treats as success.
enum CommandRange {
  device(0x68),
  hfReader(0x00),
  lfReader(0x40),
  hfEmulator(0x68),
  lfEmulator(0x68),
  iso14443_4(0x00); // hardware-validate

  const CommandRange(this.successStatus);
  final int successStatus;

  static CommandRange forId(int id) => switch (id ~/ 1000) {
        1 => device,
        2 => hfReader,
        3 => lfReader,
        4 => hfEmulator,
        5 => lfEmulator,
        6 => iso14443_4,
        _ => throw ArgumentError.value(id, 'id', 'unknown command range'),
      };
}

/// One firmware command: how to encode its request and decode its response.
abstract base class Command<R> {
  const Command();

  int get id;
  CommandRange get range => CommandRange.forId(id);
  Duration get timeout => const Duration(seconds: 3);

  /// Safe to retry once after a timeout.
  bool get idempotent => false;

  /// False for commands the firmware never answers (ENTER_BOOTLOADER).
  bool get expectsResponse => true;

  Uint8List encode() => Uint8List(0);

  R decode(Uint8List data);

  Frame toFrame() => Frame(command: id, data: encode());

  R parseResponse(Frame frame) {
    if (frame.command != id) {
      throw MalformedResponse('expected response to $id, got ${frame.command}');
    }
    if (frame.status != range.successStatus) {
      throw DeviceError.fromStatus(frame.status);
    }
    return decode(frame.data);
  }
}

/// A command whose successful response carries nothing useful.
abstract base class VoidCommand extends Command<void> {
  const VoidCommand();

  @override
  void decode(Uint8List data) {}
}
```

- [ ] **Step 4: Run to verify pass**

Run: `mise x -- dart test test/protocol`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): add Command base with per-range success status"
```

---

### Task 5: Enums and models

**Files:**
- Create: `lib/src/model/enums.dart`, `lib/src/model/models.dart` (+ generated `models.freezed.dart`), `test/model/enums_test.dart`, `test/model/models_test.dart`
- Create: `build.yaml`

**Interfaces:**
- Produces the enums `DeviceModel`, `DeviceMode`, `AnimationMode`, `ButtonFunction`, `DeviceButton`, `Sense`, `TagFamily`, `TagType`, `KeyType`, `Mf1WriteMode`, `PrngType`, each with `code` and `fromCode`; models `FirmwareVersion`, `Capabilities`, `DeviceIdentity`, `DeviceInfo`, `Slot`, `BatteryInfo`, `DeviceSettings`, `Hf14aTag`, `Mf1EmulatorConfig`, `SectorKeys`, `Mf1KeyCheckResult`, `DetectionLogEntry`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/model/enums_test.dart
import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:test/test.dart';

void main() {
  test('tag types round-trip their wire codes', () {
    for (final t in TagType.values) {
      expect(TagType.fromCode(t.code), t);
    }
    expect(TagType.mifare1k.code, 1001);
    expect(TagType.ntag215.code, 1101);
    expect(TagType.seos.code, 3001);
  });

  test('unknown tag code is undefined', () {
    expect(TagType.fromCode(9999), TagType.undefined);
  });

  test('families and senses', () {
    expect(TagType.em410x.family, TagFamily.lf);
    expect(TagType.em410x.sense, Sense.lf);
    expect(TagType.mifare4k.family, TagFamily.mifareClassic);
    expect(TagType.mifare4k.sense, Sense.hf);
    expect(TagType.mf0ul11.family, TagFamily.ultralight);
    expect(TagType.hf14a4.family, TagFamily.iso14443_4);
    expect(TagType.undefined.sense, Sense.none);
  });

  test('strict enums reject unknown codes', () {
    expect(DeviceMode.fromCode(1), DeviceMode.reader);
    expect(() => DeviceMode.fromCode(7), throwsA(isA<MalformedResponse>()));
    expect(ButtonFunction.fromCode(3), ButtonFunction.cloneUid);
    expect(DeviceButton.a.code, 0x41);
    expect(KeyType.b.code, 0x61);
  });
}
```

```dart
// test/model/models_test.dart
import 'dart:typed_data';

import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/model/models.dart';
import 'package:test/test.dart';

void main() {
  test('firmware version compares by major then minor', () {
    const a = FirmwareVersion(major: 2, minor: 0);
    const b = FirmwareVersion(major: 2, minor: 2);
    expect(a.isBefore(b), isTrue);
    expect(b.isBefore(a), isFalse);
    expect(a.label, '2.0');
    expect(a.isLegacy, isFalse);
    expect(const FirmwareVersion(major: 0, minor: 1).isLegacy, isTrue);
  });

  test('capabilities answer support questions', () {
    const c = Capabilities({1000, 1035, 2000});
    expect(c.supports(2000), isTrue);
    expect(c.hasReader, isTrue);
    expect(const Capabilities({1000}).hasReader, isFalse);
  });

  test('slots are value types with copyWith', () {
    const s = Slot(index: 0, hfType: TagType.mifare1k, lfType: TagType.em410x,
        hfEnabled: true, lfEnabled: false);
    expect(s.copyWith(hfNick: 'work'), isNot(s));
    expect(s.copyWith(hfNick: 'work').hfNick, 'work');
    expect(s.hfNick, '');
  });

  test('hf14a tag exposes uid as hex', () {
    final t = Hf14aTag(uid: Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
        atqa: Uint8List.fromList([0x00, 0x04]), sak: 0x08, ats: Uint8List(0));
    expect(t.uidHex, 'DEADBEEF');
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/model`
Expected: FAIL.

- [ ] **Step 3: Implement enums**

```dart
// lib/src/model/enums.dart
import '../protocol/errors.dart';

E _byCode<E>(List<E> values, int Function(E) code, int value, String name) {
  for (final v in values) {
    if (code(v) == value) return v;
  }
  throw MalformedResponse('unknown $name code $value');
}

enum DeviceModel {
  ultra(0),
  lite(1);

  const DeviceModel(this.code);
  final int code;
  static DeviceModel fromCode(int c) => _byCode(values, (e) => e.code, c, 'DeviceModel');
}

enum DeviceMode {
  emulator(0),
  reader(1);

  const DeviceMode(this.code);
  final int code;
  static DeviceMode fromCode(int c) => _byCode(values, (e) => e.code, c, 'DeviceMode');
}

enum AnimationMode {
  full(0),
  minimal(1),
  none(2),
  symmetric(3);

  const AnimationMode(this.code);
  final int code;
  static AnimationMode fromCode(int c) => _byCode(values, (e) => e.code, c, 'AnimationMode');
}

enum ButtonFunction {
  none(0),
  nextSlot(1),
  prevSlot(2),
  cloneUid(3),
  battery(4),
  nfcFieldGenerator(5);

  const ButtonFunction(this.code);
  final int code;
  static ButtonFunction fromCode(int c) => _byCode(values, (e) => e.code, c, 'ButtonFunction');
}

enum DeviceButton {
  a(0x41),
  b(0x42);

  const DeviceButton(this.code);
  final int code;
}

enum Sense {
  none(0),
  lf(1),
  hf(2);

  const Sense(this.code);
  final int code;
  static Sense fromCode(int c) => _byCode(values, (e) => e.code, c, 'Sense');
}

enum TagFamily { undefined, lf, mifareClassic, ultralight, iso14443_4, seos }

enum TagType {
  undefined(0, TagFamily.undefined),
  em410x(100, TagFamily.lf),
  em410xElectra(104, TagFamily.lf),
  pac(150, TagFamily.lf),
  viking(170, TagFamily.lf),
  jablotron(180, TagFamily.lf),
  hidProx(200, TagFamily.lf),
  ioProx(201, TagFamily.lf),
  idteck(310, TagFamily.lf),
  mifareMini(1000, TagFamily.mifareClassic),
  mifare1k(1001, TagFamily.mifareClassic),
  mifare2k(1002, TagFamily.mifareClassic),
  mifare4k(1003, TagFamily.mifareClassic),
  ntag213(1100, TagFamily.ultralight),
  ntag215(1101, TagFamily.ultralight),
  ntag216(1102, TagFamily.ultralight),
  mf0icu1(1103, TagFamily.ultralight),
  mf0icu2(1104, TagFamily.ultralight),
  mf0ul11(1105, TagFamily.ultralight),
  mf0ul21(1106, TagFamily.ultralight),
  ntag210(1107, TagFamily.ultralight),
  ntag212(1108, TagFamily.ultralight),
  hf14a4(3000, TagFamily.iso14443_4),
  seos(3001, TagFamily.seos);

  const TagType(this.code, this.family);
  final int code;
  final TagFamily family;

  static TagType fromCode(int c) {
    for (final t in values) {
      if (t.code == c) return t;
    }
    return undefined;
  }

  Sense get sense => switch (family) {
        TagFamily.undefined => Sense.none,
        TagFamily.lf => Sense.lf,
        _ => Sense.hf,
      };
}

enum KeyType {
  a(0x60),
  b(0x61);

  const KeyType(this.code);
  final int code;
  static KeyType fromCode(int c) => _byCode(values, (e) => e.code, c, 'KeyType');
}

enum Mf1WriteMode {
  normal(0),
  denied(1),
  deceive(2),
  shadow(3),
  shadowRequest(4);

  const Mf1WriteMode(this.code);
  final int code;
  static Mf1WriteMode fromCode(int c) => _byCode(values, (e) => e.code, c, 'Mf1WriteMode');
}

enum PrngType {
  staticNonce(0),
  weak(1),
  hard(2);

  const PrngType(this.code);
  final int code;
  static PrngType fromCode(int c) => _byCode(values, (e) => e.code, c, 'PrngType');
}
```

- [ ] **Step 4: Implement models**

```yaml
# packages/chameleon/build.yaml
targets:
  $default:
    builders:
      freezed:
        generate_for:
          - lib/src/model/models.dart
```

```dart
// lib/src/model/models.dart
import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'models.freezed.dart';

String hexOf(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();

@freezed
abstract class FirmwareVersion with _$FirmwareVersion {
  const FirmwareVersion._();
  const factory FirmwareVersion({required int major, required int minor}) = _FirmwareVersion;

  String get label => '$major.$minor';
  bool get isLegacy => major == 0 && minor == 1;
  bool isBefore(FirmwareVersion other) =>
      major < other.major || (major == other.major && minor < other.minor);
}

@freezed
abstract class Capabilities with _$Capabilities {
  const Capabilities._();
  const factory Capabilities(Set<int> commandIds) = _Capabilities;

  bool supports(int commandId) => commandIds.contains(commandId);
  bool get hasReader => supports(2000);
}

@freezed
abstract class DeviceIdentity with _$DeviceIdentity {
  const factory DeviceIdentity(String chipId) = _DeviceIdentity;
}

@freezed
abstract class DeviceInfo with _$DeviceInfo {
  const factory DeviceInfo({
    required DeviceModel model,
    required FirmwareVersion version,
    required Capabilities capabilities,
    String? gitVersion,
    DeviceIdentity? identity,
    String? bleAddress,
  }) = _DeviceInfo;
}

@freezed
abstract class Slot with _$Slot {
  const factory Slot({
    required int index,
    required TagType hfType,
    required TagType lfType,
    required bool hfEnabled,
    required bool lfEnabled,
    @Default('') String hfNick,
    @Default('') String lfNick,
  }) = _Slot;
}

@freezed
abstract class BatteryInfo with _$BatteryInfo {
  const factory BatteryInfo({required int millivolts, required int percent}) = _BatteryInfo;
}

@freezed
abstract class DeviceSettings with _$DeviceSettings {
  const factory DeviceSettings({
    required int version,
    required AnimationMode animation,
    required ButtonFunction buttonA,
    required ButtonFunction buttonB,
    required ButtonFunction longButtonA,
    required ButtonFunction longButtonB,
    required bool blePairingEnabled,
    required String blePairingKey,
    int? sleepTimeoutSeconds,
  }) = _DeviceSettings;
}

@freezed
abstract class Hf14aTag with _$Hf14aTag {
  const Hf14aTag._();
  const factory Hf14aTag({
    required Uint8List uid,
    required Uint8List atqa,
    required int sak,
    required Uint8List ats,
  }) = _Hf14aTag;

  String get uidHex => hexOf(uid);
}

@freezed
abstract class Mf1EmulatorConfig with _$Mf1EmulatorConfig {
  const factory Mf1EmulatorConfig({
    required bool detectionEnabled,
    required bool gen1a,
    required bool gen2,
    required bool blockAntiColl,
    required Mf1WriteMode writeMode,
  }) = _Mf1EmulatorConfig;
}

@freezed
abstract class SectorKeys with _$SectorKeys {
  const factory SectorKeys({required int sector, Uint8List? keyA, Uint8List? keyB}) = _SectorKeys;
}

@freezed
abstract class Mf1KeyCheckResult with _$Mf1KeyCheckResult {
  const factory Mf1KeyCheckResult(List<SectorKeys> sectors) = _Mf1KeyCheckResult;
}

/// One nonce capture from MF1 detection mode. hardware-validate.
@freezed
abstract class DetectionLogEntry with _$DetectionLogEntry {
  const factory DetectionLogEntry({
    required int block,
    required KeyType keyType,
    required bool isNested,
    required Uint8List uid,
    required int nt,
    required int nr,
    required int ar,
  }) = _DetectionLogEntry;
}
```

- [ ] **Step 5: Generate and run**

Run: `mise x -- dart run build_runner build --delete-conflicting-outputs && mise x -- dart test test/model`
Expected: `models.freezed.dart` generated; all tests pass.

- [ ] **Step 6: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): add enums and freezed models"
```

---

### Task 6: Device commands 1000-1040

**Files:**
- Create: `lib/src/commands/device.dart`, `test/commands/device_test.dart`

**Interfaces:**
- Produces one class per command below. Names used by later tasks: `GetAppVersion`, `ChangeDeviceMode`, `GetDeviceMode`, `SetActiveSlot`, `SetSlotTagType`, `SetSlotDataDefault`, `SetSlotEnable`, `SetSlotTagNick`, `GetSlotTagNick`, `SlotDataConfigSave`, `EnterBootloader`, `GetDeviceChipId`, `GetDeviceAddress`, `SaveSettings`, `ResetSettings`, `SetAnimationMode`, `GetAnimationMode`, `GetGitVersion`, `GetActiveSlot`, `GetSlotInfo`, `WipeFds`, `DeleteSlotTagNick`, `GetEnabledSlots`, `DeleteSlotSenseType`, `GetBatteryInfo`, `GetButtonPressConfig`, `SetButtonPressConfig`, `GetLongButtonPressConfig`, `SetLongButtonPressConfig`, `SetBlePairingKey`, `GetBlePairingKey`, `DeleteAllBleBonds`, `GetDeviceModel`, `GetDeviceSettings`, `GetDeviceCapabilities`, `GetBlePairingEnable`, `SetBlePairingEnable`, `GetAllSlotNicks`, `GetSleepTimeout`, `SetSleepTimeout`. Helper records: `SlotTypes(hf, lf)`, `SlotEnabled(hf, lf)`, `SlotNicks(hf, lf)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/commands/device_test.dart
import 'dart:typed_data';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/commands/device.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/model/models.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:test/test.dart';

Uint8List b(List<int> l) => Uint8List.fromList(l);
Frame ok(int cmd, List<int> data) => Frame(command: cmd, status: 0x68, data: b(data));

void main() {
  group('encode', () {
    final cases = <(Object, int, List<int>)>[
      (const GetAppVersion(), 1000, []),
      (const ChangeDeviceMode(DeviceMode.reader), 1001, [1]),
      (const SetActiveSlot(3), 1003, [3]),
      (const SetSlotTagType(2, TagType.mifare1k), 1004, [2, 0x03, 0xE9]),
      (const SetSlotDataDefault(2, TagType.em410x), 1005, [2, 0x00, 0x64]),
      (const SetSlotEnable(1, Sense.hf, true), 1006, [1, 2, 1]),
      (const SetSlotTagNick(0, Sense.lf, 'ab'), 1007, [0, 1, 0x61, 0x62]),
      (const GetSlotTagNick(4, Sense.hf), 1008, [4, 2]),
      (const EnterBootloader(), 1010, []),
      (const SetAnimationMode(AnimationMode.minimal), 1015, [1]),
      (const DeleteSlotTagNick(5, Sense.lf), 1021, [5, 1]),
      (const DeleteSlotSenseType(6, Sense.hf), 1024, [6, 2]),
      (const GetButtonPressConfig(DeviceButton.b), 1026, [0x42]),
      (const SetButtonPressConfig(DeviceButton.a, ButtonFunction.nextSlot), 1027, [0x41, 1]),
      (const SetLongButtonPressConfig(DeviceButton.b, ButtonFunction.battery), 1029, [0x42, 4]),
      (const SetBlePairingKey('123456'), 1030, [0x31, 0x32, 0x33, 0x34, 0x35, 0x36]),
      (const SetBlePairingEnable(true), 1037, [1]),
      (const SetSleepTimeout(30), 1040, [30]),
    ];
    for (final (cmd, id, payload) in cases) {
      test('$id ${cmd.runtimeType}', () {
        final c = cmd as dynamic;
        expect(c.id, id);
        expect(c.encode(), payload);
      });
    }
  });

  group('decode', () {
    test('GetAppVersion', () {
      expect(const GetAppVersion().parseResponse(ok(1000, [2, 1])),
          const FirmwareVersion(major: 2, minor: 1));
    });
    test('GetDeviceMode', () {
      expect(const GetDeviceMode().parseResponse(ok(1002, [0])), DeviceMode.emulator);
    });
    test('GetSlotTagNick decodes utf8', () {
      expect(const GetSlotTagNick(0, Sense.hf).parseResponse(ok(1008, [0xC3, 0xA9])), 'é');
    });
    test('GetDeviceChipId is upper hex', () {
      expect(const GetDeviceChipId().parseResponse(ok(1011, [1, 2, 3, 4, 5, 6, 7, 0xAB])),
          '01020304050607AB');
    });
    test('GetDeviceAddress is colon separated', () {
      expect(const GetDeviceAddress().parseResponse(ok(1012, [1, 2, 3, 4, 5, 0xFF])),
          '01:02:03:04:05:FF');
    });
    test('GetGitVersion', () {
      expect(const GetGitVersion().parseResponse(ok(1017, [0x76, 0x32])), 'v2');
    });
    test('GetActiveSlot', () {
      expect(const GetActiveSlot().parseResponse(ok(1018, [7])), 7);
    });
    test('GetSlotInfo decodes eight pairs', () {
      final data = List<int>.generate(32, (i) => 0)
        ..[0] = 0x03
        ..[1] = 0xE9
        ..[2] = 0x00
        ..[3] = 0x64;
      final info = const GetSlotInfo().parseResponse(ok(1019, data));
      expect(info.length, 8);
      expect(info[0], const SlotTypes(TagType.mifare1k, TagType.em410x));
      expect(info[7], const SlotTypes(TagType.undefined, TagType.undefined));
    });
    test('GetEnabledSlots', () {
      final data = List<int>.filled(16, 0)..[0] = 1..[3] = 1;
      final en = const GetEnabledSlots().parseResponse(ok(1023, data));
      expect(en[0], const SlotEnabled(true, false));
      expect(en[1], const SlotEnabled(false, true));
    });
    test('GetBatteryInfo', () {
      expect(const GetBatteryInfo().parseResponse(ok(1025, [0x0F, 0xA0, 85])),
          const BatteryInfo(millivolts: 4000, percent: 85));
    });
    test('GetButtonPressConfig', () {
      expect(const GetButtonPressConfig(DeviceButton.a).parseResponse(ok(1026, [2])),
          ButtonFunction.prevSlot);
    });
    test('GetBlePairingKey', () {
      expect(const GetBlePairingKey().parseResponse(ok(1031, '123456'.codeUnits)), '123456');
    });
    test('GetDeviceModel', () {
      expect(const GetDeviceModel().parseResponse(ok(1033, [1])), DeviceModel.lite);
    });
    test('GetDeviceSettings without sleep timeout', () {
      final s = const GetDeviceSettings()
          .parseResponse(ok(1034, [5, 0, 1, 2, 3, 4, 1, ...'123456'.codeUnits]));
      expect(s.version, 5);
      expect(s.animation, AnimationMode.full);
      expect(s.buttonA, ButtonFunction.nextSlot);
      expect(s.longButtonB, ButtonFunction.battery);
      expect(s.blePairingEnabled, isTrue);
      expect(s.blePairingKey, '123456');
      expect(s.sleepTimeoutSeconds, isNull);
    });
    test('GetDeviceSettings with sleep timeout and unknown trailing bytes', () {
      final s = const GetDeviceSettings()
          .parseResponse(ok(1034, [6, 0, 0, 0, 0, 0, 0, ...'000000'.codeUnits, 8, 0xFF]));
      expect(s.sleepTimeoutSeconds, 8);
    });
    test('GetDeviceCapabilities', () {
      final c = const GetDeviceCapabilities().parseResponse(ok(1035, [0x03, 0xE8, 0x07, 0xD0]));
      expect(c.commandIds, {1000, 2000});
    });
    test('GetBlePairingEnable', () {
      expect(const GetBlePairingEnable().parseResponse(ok(1036, [0])), isFalse);
    });
    test('GetAllSlotNicks', () {
      final data = <int>[];
      for (var i = 0; i < 8; i++) {
        if (i == 0) {
          data.addAll([2, 0x68, 0x69, 0]);
        } else {
          data.addAll([0, 0]);
        }
      }
      final n = const GetAllSlotNicks().parseResponse(ok(1038, data));
      expect(n[0], const SlotNicks('hi', ''));
      expect(n[5], const SlotNicks('', ''));
    });
    test('GetSleepTimeout', () {
      expect(const GetSleepTimeout().parseResponse(ok(1039, [15])), 15);
    });
    test('short payloads are MalformedResponse', () {
      expect(() => const GetAppVersion().parseResponse(ok(1000, [2])),
          throwsA(isA<MalformedResponse>()));
    });
  });

  test('EnterBootloader expects no response', () {
    expect(const EnterBootloader().expectsResponse, isFalse);
  });

  test('SetSlotTagNick rejects nicks longer than 32 bytes', () {
    expect(() => SetSlotTagNick(0, Sense.hf, 'x' * 33).encode(), throwsArgumentError);
  });

  test('reads are idempotent, writes are not', () {
    expect(const GetActiveSlot().idempotent, isTrue);
    expect(const SetActiveSlot(1).idempotent, isFalse);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/commands/device_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/src/commands/device.dart
import 'dart:convert';
import 'dart:typed_data';

import '../codec/bytes.dart';
import '../model/enums.dart';
import '../model/models.dart';
import '../protocol/command.dart';

/// Marker for read-only device commands: idempotent by default.
abstract base class _Read<R> extends Command<R> {
  const _Read();
  @override
  bool get idempotent => true;
}

final class GetAppVersion extends _Read<FirmwareVersion> {
  const GetAppVersion();
  @override
  int get id => 1000;
  @override
  FirmwareVersion decode(Uint8List data) {
    final r = ByteReader(data);
    return FirmwareVersion(major: r.u8(), minor: r.u8());
  }
}

final class ChangeDeviceMode extends VoidCommand {
  const ChangeDeviceMode(this.mode);
  final DeviceMode mode;
  @override
  int get id => 1001;
  @override
  Uint8List encode() => ByteWriter().u8(mode.code).toBytes();
}

final class GetDeviceMode extends _Read<DeviceMode> {
  const GetDeviceMode();
  @override
  int get id => 1002;
  @override
  DeviceMode decode(Uint8List data) => DeviceMode.fromCode(ByteReader(data).u8());
}

final class SetActiveSlot extends VoidCommand {
  const SetActiveSlot(this.slot);
  final int slot;
  @override
  int get id => 1003;
  @override
  Uint8List encode() => ByteWriter().u8(slot).toBytes();
}

final class SetSlotTagType extends VoidCommand {
  const SetSlotTagType(this.slot, this.type);
  final int slot;
  final TagType type;
  @override
  int get id => 1004;
  @override
  Uint8List encode() => ByteWriter().u8(slot).u16(type.code).toBytes();
}

final class SetSlotDataDefault extends VoidCommand {
  const SetSlotDataDefault(this.slot, this.type);
  final int slot;
  final TagType type;
  @override
  int get id => 1005;
  @override
  Uint8List encode() => ByteWriter().u8(slot).u16(type.code).toBytes();
}

final class SetSlotEnable extends VoidCommand {
  const SetSlotEnable(this.slot, this.sense, this.enabled);
  final int slot;
  final Sense sense;
  final bool enabled;
  @override
  int get id => 1006;
  @override
  Uint8List encode() => ByteWriter().u8(slot).u8(sense.code).u8(enabled ? 1 : 0).toBytes();
}

const int maxNickBytes = 32;

final class SetSlotTagNick extends VoidCommand {
  const SetSlotTagNick(this.slot, this.sense, this.nick);
  final int slot;
  final Sense sense;
  final String nick;
  @override
  int get id => 1007;
  @override
  Uint8List encode() {
    final bytes = utf8.encode(nick);
    if (bytes.length > maxNickBytes) {
      throw ArgumentError.value(nick, 'nick', 'longer than $maxNickBytes bytes');
    }
    return ByteWriter().u8(slot).u8(sense.code).bytes(bytes).toBytes();
  }
}

final class GetSlotTagNick extends _Read<String> {
  const GetSlotTagNick(this.slot, this.sense);
  final int slot;
  final Sense sense;
  @override
  int get id => 1008;
  @override
  Uint8List encode() => ByteWriter().u8(slot).u8(sense.code).toBytes();
  @override
  String decode(Uint8List data) => utf8.decode(data, allowMalformed: true);
}

final class SlotDataConfigSave extends VoidCommand {
  const SlotDataConfigSave();
  @override
  int get id => 1009;
}

/// The firmware reboots into the bootloader and never answers.
final class EnterBootloader extends VoidCommand {
  const EnterBootloader();
  @override
  int get id => 1010;
  @override
  bool get expectsResponse => false;
}

final class GetDeviceChipId extends _Read<String> {
  const GetDeviceChipId();
  @override
  int get id => 1011;
  @override
  String decode(Uint8List data) => hexOf(ByteReader(data).bytes(8));
}

final class GetDeviceAddress extends _Read<String> {
  const GetDeviceAddress();
  @override
  int get id => 1012;
  @override
  String decode(Uint8List data) => ByteReader(data)
      .bytes(6)
      .map((x) => x.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');
}

final class SaveSettings extends VoidCommand {
  const SaveSettings();
  @override
  int get id => 1013;
}

final class ResetSettings extends VoidCommand {
  const ResetSettings();
  @override
  int get id => 1014;
}

final class SetAnimationMode extends VoidCommand {
  const SetAnimationMode(this.mode);
  final AnimationMode mode;
  @override
  int get id => 1015;
  @override
  Uint8List encode() => ByteWriter().u8(mode.code).toBytes();
}

final class GetAnimationMode extends _Read<AnimationMode> {
  const GetAnimationMode();
  @override
  int get id => 1016;
  @override
  AnimationMode decode(Uint8List data) => AnimationMode.fromCode(ByteReader(data).u8());
}

final class GetGitVersion extends _Read<String> {
  const GetGitVersion();
  @override
  int get id => 1017;
  @override
  String decode(Uint8List data) => utf8.decode(data, allowMalformed: true);
}

final class GetActiveSlot extends _Read<int> {
  const GetActiveSlot();
  @override
  int get id => 1018;
  @override
  int decode(Uint8List data) => ByteReader(data).u8();
}

final class SlotTypes {
  const SlotTypes(this.hf, this.lf);
  final TagType hf;
  final TagType lf;
  @override
  bool operator ==(Object o) => o is SlotTypes && o.hf == hf && o.lf == lf;
  @override
  int get hashCode => Object.hash(hf, lf);
}

final class GetSlotInfo extends _Read<List<SlotTypes>> {
  const GetSlotInfo();
  @override
  int get id => 1019;
  @override
  List<SlotTypes> decode(Uint8List data) {
    final r = ByteReader(data);
    return List.generate(8, (_) => SlotTypes(TagType.fromCode(r.u16()), TagType.fromCode(r.u16())));
  }
}

final class WipeFds extends VoidCommand {
  const WipeFds();
  @override
  int get id => 1020;
}

final class DeleteSlotTagNick extends VoidCommand {
  const DeleteSlotTagNick(this.slot, this.sense);
  final int slot;
  final Sense sense;
  @override
  int get id => 1021;
  @override
  Uint8List encode() => ByteWriter().u8(slot).u8(sense.code).toBytes();
}

final class SlotEnabled {
  const SlotEnabled(this.hf, this.lf);
  final bool hf;
  final bool lf;
  @override
  bool operator ==(Object o) => o is SlotEnabled && o.hf == hf && o.lf == lf;
  @override
  int get hashCode => Object.hash(hf, lf);
}

final class GetEnabledSlots extends _Read<List<SlotEnabled>> {
  const GetEnabledSlots();
  @override
  int get id => 1023;
  @override
  List<SlotEnabled> decode(Uint8List data) {
    final r = ByteReader(data);
    return List.generate(8, (_) => SlotEnabled(r.u8() != 0, r.u8() != 0));
  }
}

final class DeleteSlotSenseType extends VoidCommand {
  const DeleteSlotSenseType(this.slot, this.sense);
  final int slot;
  final Sense sense;
  @override
  int get id => 1024;
  @override
  Uint8List encode() => ByteWriter().u8(slot).u8(sense.code).toBytes();
}

final class GetBatteryInfo extends _Read<BatteryInfo> {
  const GetBatteryInfo();
  @override
  int get id => 1025;
  @override
  BatteryInfo decode(Uint8List data) {
    final r = ByteReader(data);
    return BatteryInfo(millivolts: r.u16(), percent: r.u8());
  }
}

final class GetButtonPressConfig extends _Read<ButtonFunction> {
  const GetButtonPressConfig(this.button);
  final DeviceButton button;
  @override
  int get id => 1026;
  @override
  Uint8List encode() => ByteWriter().u8(button.code).toBytes();
  @override
  ButtonFunction decode(Uint8List data) => ButtonFunction.fromCode(ByteReader(data).u8());
}

final class SetButtonPressConfig extends VoidCommand {
  const SetButtonPressConfig(this.button, this.function);
  final DeviceButton button;
  final ButtonFunction function;
  @override
  int get id => 1027;
  @override
  Uint8List encode() => ByteWriter().u8(button.code).u8(function.code).toBytes();
}

final class GetLongButtonPressConfig extends _Read<ButtonFunction> {
  const GetLongButtonPressConfig(this.button);
  final DeviceButton button;
  @override
  int get id => 1028;
  @override
  Uint8List encode() => ByteWriter().u8(button.code).toBytes();
  @override
  ButtonFunction decode(Uint8List data) => ButtonFunction.fromCode(ByteReader(data).u8());
}

final class SetLongButtonPressConfig extends VoidCommand {
  const SetLongButtonPressConfig(this.button, this.function);
  final DeviceButton button;
  final ButtonFunction function;
  @override
  int get id => 1029;
  @override
  Uint8List encode() => ByteWriter().u8(button.code).u8(function.code).toBytes();
}

final class SetBlePairingKey extends VoidCommand {
  const SetBlePairingKey(this.key);
  final String key;
  @override
  int get id => 1030;
  @override
  Uint8List encode() {
    if (!RegExp(r'^\d{6}$').hasMatch(key)) {
      throw ArgumentError.value(key, 'key', 'must be six ASCII digits');
    }
    return ByteWriter().utf8String(key).toBytes();
  }
}

final class GetBlePairingKey extends _Read<String> {
  const GetBlePairingKey();
  @override
  int get id => 1031;
  @override
  String decode(Uint8List data) => ByteReader(data).utf8String(6);
}

final class DeleteAllBleBonds extends VoidCommand {
  const DeleteAllBleBonds();
  @override
  int get id => 1032;
}

final class GetDeviceModel extends _Read<DeviceModel> {
  const GetDeviceModel();
  @override
  int get id => 1033;
  @override
  DeviceModel decode(Uint8List data) => DeviceModel.fromCode(ByteReader(data).u8());
}

/// hardware-validate: the settings payload length differs between firmware
/// versions. Unknown trailing bytes are ignored.
final class GetDeviceSettings extends _Read<DeviceSettings> {
  const GetDeviceSettings();
  @override
  int get id => 1034;
  @override
  DeviceSettings decode(Uint8List data) {
    final r = ByteReader(data);
    final version = r.u8();
    final animation = AnimationMode.fromCode(r.u8());
    final a = ButtonFunction.fromCode(r.u8());
    final b = ButtonFunction.fromCode(r.u8());
    final la = ButtonFunction.fromCode(r.u8());
    final lb = ButtonFunction.fromCode(r.u8());
    final pairing = r.u8() != 0;
    final key = r.utf8String(6);
    final sleep = r.remaining >= 1 ? r.u8() : null;
    return DeviceSettings(
      version: version,
      animation: animation,
      buttonA: a,
      buttonB: b,
      longButtonA: la,
      longButtonB: lb,
      blePairingEnabled: pairing,
      blePairingKey: key,
      sleepTimeoutSeconds: sleep,
    );
  }
}

final class GetDeviceCapabilities extends _Read<Capabilities> {
  const GetDeviceCapabilities();
  @override
  int get id => 1035;
  @override
  Capabilities decode(Uint8List data) {
    final r = ByteReader(data);
    final ids = <int>{};
    while (r.remaining >= 2) {
      ids.add(r.u16());
    }
    return Capabilities(ids);
  }
}

final class GetBlePairingEnable extends _Read<bool> {
  const GetBlePairingEnable();
  @override
  int get id => 1036;
  @override
  bool decode(Uint8List data) => ByteReader(data).u8() != 0;
}

final class SetBlePairingEnable extends VoidCommand {
  const SetBlePairingEnable(this.enabled);
  final bool enabled;
  @override
  int get id => 1037;
  @override
  Uint8List encode() => ByteWriter().u8(enabled ? 1 : 0).toBytes();
}

final class SlotNicks {
  const SlotNicks(this.hf, this.lf);
  final String hf;
  final String lf;
  @override
  bool operator ==(Object o) => o is SlotNicks && o.hf == hf && o.lf == lf;
  @override
  int get hashCode => Object.hash(hf, lf);
}

final class GetAllSlotNicks extends _Read<List<SlotNicks>> {
  const GetAllSlotNicks();
  @override
  int get id => 1038;
  @override
  List<SlotNicks> decode(Uint8List data) {
    final r = ByteReader(data);
    return List.generate(8, (_) {
      final hf = r.utf8String(r.u8());
      final lf = r.utf8String(r.u8());
      return SlotNicks(hf, lf);
    });
  }
}

final class GetSleepTimeout extends _Read<int> {
  const GetSleepTimeout();
  @override
  int get id => 1039;
  @override
  int decode(Uint8List data) => ByteReader(data).u8();
}

final class SetSleepTimeout extends VoidCommand {
  const SetSleepTimeout(this.seconds);
  final int seconds;
  @override
  int get id => 1040;
  @override
  Uint8List encode() {
    if (seconds < 5 || seconds > 60) {
      throw ArgumentError.value(seconds, 'seconds', 'must be 5..60');
    }
    return ByteWriter().u8(seconds).toBytes();
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `mise x -- dart test test/commands/device_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): add device command catalog 1000-1040"
```

---

### Task 7: Reader commands 2xxx and 3xxx

**Files:**
- Create: `lib/src/commands/hf_reader.dart`, `lib/src/commands/lf_reader.dart`, `lib/src/commands/raw.dart`, `test/commands/hf_reader_test.dart`, `test/commands/lf_reader_test.dart`

**Interfaces:**
- Produces typed classes `Hf14aScan`, `Mf1DetectSupport`, `Mf1DetectPrng`, `Mf1AuthOneKeyBlock`, `Mf1ReadOneBlock`, `Mf1WriteOneBlock`, `Hf14aRaw`, `Mf1CheckKeysOfSectors`, `Em410xScan`, `Em410xWriteToT55xx`, `HidProxScan`, `VikingScan`, `PacScan`; and `RawCommand(id, payload, {timeout})` returning `Uint8List` for everything else.

- [ ] **Step 1: Write the failing tests**

```dart
// test/commands/hf_reader_test.dart
import 'dart:typed_data';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/commands/hf_reader.dart';
import 'package:chameleon/src/commands/raw.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:test/test.dart';

Uint8List b(List<int> l) => Uint8List.fromList(l);
Frame hfOk(int cmd, List<int> data) => Frame(command: cmd, status: 0x00, data: b(data));

final key = b([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);

void main() {
  test('Hf14aScan decodes two tags', () {
    final tags = const Hf14aScan().parseResponse(hfOk(2000, [
      4, 1, 2, 3, 4, 0x00, 0x04, 0x08, 0,
      7, 1, 2, 3, 4, 5, 6, 7, 0x00, 0x44, 0x00, 2, 0x75, 0x77,
    ]));
    expect(tags.length, 2);
    expect(tags[0].uidHex, '01020304');
    expect(tags[0].sak, 0x08);
    expect(tags[1].uid.length, 7);
    expect(tags[1].ats, [0x75, 0x77]);
  });

  test('Hf14aScan maps no-tag status to HfTagNotFound', () {
    expect(() => const Hf14aScan().parseResponse(Frame(command: 2000, status: 0x01)),
        throwsA(isA<HfTagNotFound>()));
  });

  test('Mf1DetectPrng', () {
    expect(const Mf1DetectPrng().parseResponse(hfOk(2002, [1])), PrngType.weak);
  });

  test('Mf1AuthOneKeyBlock encodes type, block, key', () {
    expect(Mf1AuthOneKeyBlock(KeyType.a, 4, key).encode(), [0x60, 4, ...key]);
  });

  test('Mf1ReadOneBlock returns 16 bytes', () {
    final data = List<int>.generate(16, (i) => i);
    expect(Mf1ReadOneBlock(KeyType.b, 1, key).parseResponse(hfOk(2008, data)), data);
    expect(Mf1ReadOneBlock(KeyType.b, 1, key).encode(), [0x61, 1, ...key]);
  });

  test('Mf1WriteOneBlock encodes 16 data bytes', () {
    final data = Uint8List(16);
    expect(Mf1WriteOneBlock(KeyType.a, 2, key, data).encode().length, 24);
    expect(() => Mf1WriteOneBlock(KeyType.a, 2, key, Uint8List(3)).encode(), throwsArgumentError);
  });

  test('Hf14aRaw encodes options, timeout, bit length', () {
    final c = Hf14aRaw(options: 0x81, timeoutMs: 100, bitLength: 8, data: b([0x26]));
    expect(c.encode(), [0x81, 0x00, 0x64, 0x00, 0x08, 0x26]);
  });

  test('Mf1CheckKeysOfSectors encodes mask and keys and decodes found keys', () {
    final c = Mf1CheckKeysOfSectors(sectors: {0, 1}, keyTypes: {KeyType.a}, keys: [key]);
    final enc = c.encode();
    expect(enc.length, 10 + 6);
    expect(enc[0], 0xA0); // sector0 A, sector1 A -> bits 7 and 5
    final resp = List<int>.filled(490, 0)..[0] = 0x80;
    for (var i = 0; i < 6; i++) {
      resp[10 + i] = 0xAA;
    }
    final result = c.parseResponse(hfOk(2012, resp));
    expect(result.sectors.length, 40);
    expect(result.sectors[0].keyA, List.filled(6, 0xAA));
    expect(result.sectors[0].keyB, isNull);
    expect(c.timeout, greaterThan(const Duration(seconds: 10)));
  });

  test('RawCommand passes bytes through', () {
    final c = RawCommand(2100, Uint8List(0));
    expect(c.id, 2100);
    expect(c.parseResponse(hfOk(2100, [1, 2])), [1, 2]);
  });
}
```

```dart
// test/commands/lf_reader_test.dart
import 'dart:typed_data';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/commands/lf_reader.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:test/test.dart';

Uint8List b(List<int> l) => Uint8List.fromList(l);
Frame lfOk(int cmd, List<int> data) => Frame(command: cmd, status: 0x40, data: b(data));

void main() {
  test('Em410xScan returns five id bytes', () {
    expect(const Em410xScan().parseResponse(lfOk(3000, [1, 2, 3, 4, 5])), [1, 2, 3, 4, 5]);
  });

  test('Em410xScan maps no-tag status to LfTagNotFound', () {
    expect(() => const Em410xScan().parseResponse(Frame(command: 3000, status: 0x41)),
        throwsA(isA<LfTagNotFound>()));
  });

  test('Em410xWriteToT55xx encodes id, new key and old keys', () {
    final c = Em410xWriteToT55xx(
      cardId: b([1, 2, 3, 4, 5]),
      newKey: b([0x51, 0x24, 0x36, 0x48]),
      oldKeys: [b([0x51, 0x24, 0x36, 0x48]), b([0x19, 0x92, 0x04, 0x27])],
    );
    expect(c.encode().length, 5 + 4 + 8);
  });

  test('fixed-length scans check their lengths', () {
    expect(const HidProxScan().parseResponse(lfOk(3002, List.filled(13, 7))).length, 13);
    expect(const VikingScan().parseResponse(lfOk(3004, [1, 2, 3, 4])).length, 4);
    expect(const PacScan().parseResponse(lfOk(3014, List.filled(8, 1))).length, 8);
    expect(() => const VikingScan().parseResponse(lfOk(3004, [1])),
        throwsA(isA<MalformedResponse>()));
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/commands`
Expected: FAIL on the two new files.

- [ ] **Step 3: Implement**

```dart
// lib/src/commands/raw.dart
import 'dart:typed_data';

import '../protocol/command.dart';

/// Any command by id, with an opaque payload and an opaque response. Used for
/// commands that have no typed wrapper yet and by the expert raw console.
final class RawCommand extends Command<Uint8List> {
  RawCommand(this.id, this.payload, {Duration? timeout})
      : timeout = timeout ?? const Duration(seconds: 3);

  @override
  final int id;
  final Uint8List payload;
  @override
  final Duration timeout;

  @override
  Uint8List encode() => payload;

  @override
  Uint8List decode(Uint8List data) => data;
}
```

```dart
// lib/src/commands/hf_reader.dart
import 'dart:typed_data';

import '../codec/bytes.dart';
import '../model/enums.dart';
import '../model/models.dart';
import '../protocol/command.dart';

const Duration slowReaderTimeout = Duration(seconds: 30);
const Duration keyCheckTimeout = Duration(seconds: 60);

Uint8List _requireLength(Uint8List v, int n, String name) {
  if (v.length != n) {
    throw ArgumentError.value(v.length, name, 'must be $n bytes');
  }
  return v;
}

final class Hf14aScan extends Command<List<Hf14aTag>> {
  const Hf14aScan();
  @override
  int get id => 2000;
  @override
  bool get idempotent => true;
  @override
  List<Hf14aTag> decode(Uint8List data) {
    final r = ByteReader(data);
    final tags = <Hf14aTag>[];
    while (!r.isAtEnd) {
      final uid = r.bytes(r.u8());
      final atqa = r.bytes(2);
      final sak = r.u8();
      final ats = r.bytes(r.u8());
      tags.add(Hf14aTag(uid: uid, atqa: atqa, sak: sak, ats: ats));
    }
    return tags;
  }
}

/// Success status means the tag supports MIFARE Classic authentication.
final class Mf1DetectSupport extends VoidCommand {
  const Mf1DetectSupport();
  @override
  int get id => 2001;
}

final class Mf1DetectPrng extends Command<PrngType> {
  const Mf1DetectPrng();
  @override
  int get id => 2002;
  @override
  PrngType decode(Uint8List data) => PrngType.fromCode(ByteReader(data).u8());
}

final class Mf1AuthOneKeyBlock extends VoidCommand {
  Mf1AuthOneKeyBlock(this.keyType, this.block, Uint8List key)
      : key = _requireLength(key, 6, 'key');
  final KeyType keyType;
  final int block;
  final Uint8List key;
  @override
  int get id => 2007;
  @override
  Uint8List encode() => ByteWriter().u8(keyType.code).u8(block).bytes(key).toBytes();
}

final class Mf1ReadOneBlock extends Command<Uint8List> {
  Mf1ReadOneBlock(this.keyType, this.block, Uint8List key)
      : key = _requireLength(key, 6, 'key');
  final KeyType keyType;
  final int block;
  final Uint8List key;
  @override
  int get id => 2008;
  @override
  bool get idempotent => true;
  @override
  Uint8List encode() => ByteWriter().u8(keyType.code).u8(block).bytes(key).toBytes();
  @override
  Uint8List decode(Uint8List data) => ByteReader(data).bytes(16);
}

final class Mf1WriteOneBlock extends VoidCommand {
  Mf1WriteOneBlock(this.keyType, this.block, Uint8List key, Uint8List data)
      : key = _requireLength(key, 6, 'key'),
        data = _requireLength(data, 16, 'data');
  final KeyType keyType;
  final int block;
  final Uint8List key;
  final Uint8List data;
  @override
  int get id => 2009;
  @override
  Uint8List encode() =>
      ByteWriter().u8(keyType.code).u8(block).bytes(key).bytes(data).toBytes();
}

/// hardware-validate: option bit meanings follow the firmware's hf14a_raw.
final class Hf14aRaw extends Command<Uint8List> {
  const Hf14aRaw({
    required this.options,
    required this.timeoutMs,
    required this.bitLength,
    required this.data,
  });
  final int options;
  final int timeoutMs;
  final int bitLength;
  final Uint8List data;
  @override
  int get id => 2010;
  @override
  Uint8List encode() =>
      ByteWriter().u8(options).u16(timeoutMs).u16(bitLength).bytes(data).toBytes();
  @override
  Uint8List decode(Uint8List data) => data;
}

/// Bit i of the 10-byte mask (MSB first) is sector i ~/ 2, key A when i is
/// even and key B when odd. hardware-validate.
final class Mf1CheckKeysOfSectors extends Command<Mf1KeyCheckResult> {
  Mf1CheckKeysOfSectors({
    required this.sectors,
    required this.keyTypes,
    required List<Uint8List> keys,
  }) : keys = List.unmodifiable(keys) {
    if (keys.length > 83) {
      throw ArgumentError.value(keys.length, 'keys', 'at most 83 keys');
    }
    for (final k in keys) {
      _requireLength(k, 6, 'key');
    }
  }
  final Set<int> sectors;
  final Set<KeyType> keyTypes;
  final List<Uint8List> keys;
  @override
  int get id => 2012;
  @override
  Duration get timeout => keyCheckTimeout;

  static int bitIndex(int sector, KeyType t) => sector * 2 + (t == KeyType.a ? 0 : 1);

  @override
  Uint8List encode() {
    final mask = Uint8List(10);
    for (final s in sectors) {
      for (final t in keyTypes) {
        final i = bitIndex(s, t);
        mask[i ~/ 8] |= 0x80 >> (i % 8);
      }
    }
    final w = ByteWriter().bytes(mask);
    for (final k in keys) {
      w.bytes(k);
    }
    return w.toBytes();
  }

  @override
  Mf1KeyCheckResult decode(Uint8List data) {
    final r = ByteReader(data);
    final found = r.bytes(10);
    bool isSet(int i) => (found[i ~/ 8] & (0x80 >> (i % 8))) != 0;
    final out = <SectorKeys>[];
    for (var s = 0; s < 40; s++) {
      final a = r.bytes(6);
      final b = r.bytes(6);
      out.add(SectorKeys(
        sector: s,
        keyA: isSet(bitIndex(s, KeyType.a)) ? a : null,
        keyB: isSet(bitIndex(s, KeyType.b)) ? b : null,
      ));
    }
    return Mf1KeyCheckResult(out);
  }
}
```

```dart
// lib/src/commands/lf_reader.dart
import 'dart:typed_data';

import '../codec/bytes.dart';
import '../protocol/command.dart';

abstract base class _FixedScan extends Command<Uint8List> {
  const _FixedScan();
  int get length;
  @override
  bool get idempotent => true;
  @override
  Uint8List decode(Uint8List data) => ByteReader(data).bytes(length);
}

final class Em410xScan extends _FixedScan {
  const Em410xScan();
  @override
  int get id => 3000;
  @override
  int get length => 5;
}

final class Em410xWriteToT55xx extends VoidCommand {
  Em410xWriteToT55xx({required this.cardId, required this.newKey, required this.oldKeys}) {
    if (cardId.length != 5) throw ArgumentError.value(cardId.length, 'cardId', 'must be 5 bytes');
    if (newKey.length != 4) throw ArgumentError.value(newKey.length, 'newKey', 'must be 4 bytes');
    for (final k in oldKeys) {
      if (k.length != 4) throw ArgumentError.value(k.length, 'oldKeys', 'each 4 bytes');
    }
  }
  final Uint8List cardId;
  final Uint8List newKey;
  final List<Uint8List> oldKeys;
  @override
  int get id => 3001;
  @override
  Uint8List encode() {
    final w = ByteWriter().bytes(cardId).bytes(newKey);
    for (final k in oldKeys) {
      w.bytes(k);
    }
    return w.toBytes();
  }
}

final class HidProxScan extends _FixedScan {
  const HidProxScan();
  @override
  int get id => 3002;
  @override
  int get length => 13;
}

final class VikingScan extends _FixedScan {
  const VikingScan();
  @override
  int get id => 3004;
  @override
  int get length => 4;
}

final class PacScan extends _FixedScan {
  const PacScan();
  @override
  int get id => 3014;
  @override
  int get length => 8;
}
```

Commands without typed wrappers in v1, reachable through `RawCommand` and listed here so a later task can add wrappers:

| Id | Name | Request | Response | Note |
|---|---|---|---|---|
| 2003 | MF1_STATIC_NESTED_ACQUIRE | see wiki | nonces | hardware-validate, 30 s |
| 2004 | MF1_DARKSIDE_ACQUIRE | see wiki | nonces | hardware-validate, 30 s |
| 2005 | MF1_DETECT_NT_DIST | key type, block, key | dist | hardware-validate |
| 2006 | MF1_NESTED_ACQUIRE | see wiki | nonces | hardware-validate, 30 s |
| 2011 | MF1_MANIPULATE_VALUE_BLOCK | see wiki | none | hardware-validate |
| 2013-2017, 2020 | hardnested, enc nested, check keys on block, scan keep, auth trace, sniff | see wiki | raw | hardware-validate |
| 2100/2101 | FIELD_ON / FIELD_OFF | none | none | |
| 2200/2201 | HF14A_GET/SET_CONFIG | bcc cl2 cl3 rats | same | hardware-validate |
| 3003, 3005, 3006, 3009-3013, 3015-3031 | LF writes, IoProx, ADC, T55xx, EM4x05, sniff | see wiki | raw | hardware-validate |

- [ ] **Step 4: Run to verify pass**

Run: `mise x -- dart test test/commands`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): add reader commands and RawCommand"
```

---

### Task 8: Emulator commands 4xxx, 5xxx and the 6xxx table

**Files:**
- Create: `lib/src/commands/hf_emulator.dart`, `lib/src/commands/lf_emulator.dart`, `lib/src/commands/iso14443_4.dart`, `test/commands/hf_emulator_test.dart`, `test/commands/lf_emulator_test.dart`

**Interfaces:**
- Produces `Mf1WriteEmuBlockData`, `Hf14aSetAntiCollData`, `Mf1SetDetectionEnable`, `Mf1GetDetectionCount`, `Mf1GetDetectionLog`, `Mf1GetDetectionEnable`, `Mf1ReadEmuBlockData`, `Mf1GetEmulatorConfig`, `Mf1GetGen1aMode`, `Mf1SetGen1aMode`, `Mf1GetGen2Mode`, `Mf1SetGen2Mode`, `Mf1GetBlockAntiCollMode`, `Mf1SetBlockAntiCollMode`, `Mf1GetWriteMode`, `Mf1SetWriteMode`, `Hf14aGetAntiCollData`, `Mf0NtagGetUidMagicMode`, `Mf0NtagSetUidMagicMode`, `Mf0NtagReadEmuPageData`, `Mf0NtagWriteEmuPageData`, `Mf0NtagGetPageCount`; LF: `Em410xSetEmuId`, `Em410xGetEmuId`, `HidProxSetEmuId`, `HidProxGetEmuId`, `VikingSetEmuId`, `VikingGetEmuId`, `PacSetEmuId`, `PacGetEmuId`, `JablotronSetEmuId`, `JablotronGetEmuId`, `IdteckSetEmuId`, `IdteckGetEmuId`; constant `emuLfIdLengths`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/commands/hf_emulator_test.dart
import 'dart:typed_data';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/commands/hf_emulator.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:test/test.dart';

Uint8List b(List<int> l) => Uint8List.fromList(l);
Frame ok(int cmd, List<int> data) => Frame(command: cmd, status: 0x68, data: b(data));

void main() {
  test('Mf1WriteEmuBlockData encodes start block then 16-byte blocks', () {
    final c = Mf1WriteEmuBlockData(4, Uint8List(32));
    expect(c.encode().length, 33);
    expect(c.encode()[0], 4);
    expect(() => Mf1WriteEmuBlockData(0, Uint8List(20)).encode(), throwsArgumentError);
  });

  test('Mf1ReadEmuBlockData caps count at 32', () {
    expect(const Mf1ReadEmuBlockData(0, 32).encode(), [0, 32]);
    expect(() => const Mf1ReadEmuBlockData(0, 33).encode(), throwsArgumentError);
    expect(const Mf1ReadEmuBlockData(0, 1).parseResponse(ok(4008, List.filled(16, 9))).length, 16);
  });

  test('Hf14aSetAntiCollData and GetAntiCollData round-trip', () {
    final c = Hf14aSetAntiCollData(
        uid: b([1, 2, 3, 4]), atqa: b([0x00, 0x04]), sak: 0x08, ats: b([]));
    expect(c.encode(), [4, 1, 2, 3, 4, 0x00, 0x04, 0x08, 0]);
    final t = const Hf14aGetAntiCollData().parseResponse(ok(4018, c.encode()));
    expect(t.uidHex, '01020304');
    expect(t.sak, 0x08);
  });

  test('Mf1GetEmulatorConfig decodes five flags', () {
    final cfg = const Mf1GetEmulatorConfig().parseResponse(ok(4009, [1, 0, 1, 0, 3]));
    expect(cfg.detectionEnabled, isTrue);
    expect(cfg.gen1a, isFalse);
    expect(cfg.gen2, isTrue);
    expect(cfg.writeMode, Mf1WriteMode.shadow);
  });

  test('detection count and log', () {
    expect(const Mf1GetDetectionCount().parseResponse(ok(4005, [0, 0, 0, 2])), 2);
    final entry = [
      3, 0x03, // block 3, key B, nested
      1, 2, 3, 4, // uid
      0xAA, 0xBB, 0xCC, 0xDD, // nt
      0x11, 0x22, 0x33, 0x44, // nr
      0x55, 0x66, 0x77, 0x88, // ar
    ];
    final log = const Mf1GetDetectionLog(0).parseResponse(ok(4006, [...entry, ...entry]));
    expect(log.length, 2);
    expect(log[0].block, 3);
    expect(log[0].keyType, KeyType.b);
    expect(log[0].isNested, isTrue);
    expect(log[0].nt, 0xAABBCCDD);
    expect(const Mf1GetDetectionLog(7).encode(), [0, 0, 0, 7]);
  });

  test('boolean getters and setters', () {
    expect(const Mf1GetGen1aMode().parseResponse(ok(4010, [1])), isTrue);
    expect(const Mf1SetGen1aMode(true).encode(), [1]);
    expect(const Mf1SetWriteMode(Mf1WriteMode.deceive).encode(), [2]);
    expect(const Mf1GetWriteMode().parseResponse(ok(4016, [4])), Mf1WriteMode.shadowRequest);
  });

  test('ultralight page commands', () {
    expect(const Mf0NtagReadEmuPageData(4, 2).encode(), [4, 2]);
    expect(Mf0NtagWriteEmuPageData(4, Uint8List(8)).encode().length, 10);
    expect(() => Mf0NtagWriteEmuPageData(4, Uint8List(5)).encode(), throwsArgumentError);
    expect(const Mf0NtagGetPageCount().parseResponse(ok(4030, [135])), 135);
  });
}
```

```dart
// test/commands/lf_emulator_test.dart
import 'dart:typed_data';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/commands/lf_emulator.dart';
import 'package:test/test.dart';

Uint8List b(List<int> l) => Uint8List.fromList(l);
Frame ok(int cmd, List<int> data) => Frame(command: cmd, status: 0x68, data: b(data));

void main() {
  test('set and get ids enforce fixed lengths', () {
    expect(Em410xSetEmuId(b([1, 2, 3, 4, 5])).encode(), [1, 2, 3, 4, 5]);
    expect(() => Em410xSetEmuId(b([1])).encode(), throwsArgumentError);
    expect(const Em410xGetEmuId().parseResponse(ok(5001, [1, 2, 3, 4, 5])), [1, 2, 3, 4, 5]);
    expect(HidProxSetEmuId(Uint8List(13)).id, 5002);
    expect(const VikingGetEmuId().id, 5005);
    expect(PacSetEmuId(Uint8List(8)).id, 5006);
    expect(const JablotronGetEmuId().id, 5011);
    expect(IdteckSetEmuId(Uint8List(8)).id, 5012);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/commands`
Expected: FAIL on the new files.

- [ ] **Step 3: Implement**

```dart
// lib/src/commands/hf_emulator.dart
import 'dart:typed_data';

import '../codec/bytes.dart';
import '../model/enums.dart';
import '../model/models.dart';
import '../protocol/command.dart';

abstract base class _GetBool extends Command<bool> {
  const _GetBool();
  @override
  bool get idempotent => true;
  @override
  bool decode(Uint8List data) => ByteReader(data).u8() != 0;
}

abstract base class _SetBool extends VoidCommand {
  const _SetBool(this.value);
  final bool value;
  @override
  Uint8List encode() => ByteWriter().u8(value ? 1 : 0).toBytes();
}

final class Mf1WriteEmuBlockData extends VoidCommand {
  Mf1WriteEmuBlockData(this.startBlock, this.data) {
    if (data.isEmpty || data.length % 16 != 0) {
      throw ArgumentError.value(data.length, 'data', 'must be a multiple of 16 bytes');
    }
  }
  final int startBlock;
  final Uint8List data;
  @override
  int get id => 4000;
  @override
  Uint8List encode() => ByteWriter().u8(startBlock).bytes(data).toBytes();
}

final class Hf14aSetAntiCollData extends VoidCommand {
  const Hf14aSetAntiCollData({
    required this.uid,
    required this.atqa,
    required this.sak,
    required this.ats,
  });
  final Uint8List uid;
  final Uint8List atqa;
  final int sak;
  final Uint8List ats;
  @override
  int get id => 4001;
  @override
  Uint8List encode() => ByteWriter()
      .u8(uid.length)
      .bytes(uid)
      .bytes(atqa)
      .u8(sak)
      .u8(ats.length)
      .bytes(ats)
      .toBytes();
}

final class Mf1SetDetectionEnable extends _SetBool {
  const Mf1SetDetectionEnable(super.value);
  @override
  int get id => 4004;
}

final class Mf1GetDetectionCount extends Command<int> {
  const Mf1GetDetectionCount();
  @override
  int get id => 4005;
  @override
  bool get idempotent => true;
  @override
  int decode(Uint8List data) => ByteReader(data).u32();
}

/// hardware-validate: 18-byte entries (block, flags, uid, nt, nr, ar).
final class Mf1GetDetectionLog extends Command<List<DetectionLogEntry>> {
  const Mf1GetDetectionLog(this.startIndex);
  final int startIndex;
  @override
  int get id => 4006;
  @override
  bool get idempotent => true;
  @override
  Uint8List encode() => ByteWriter().u32(startIndex).toBytes();
  @override
  List<DetectionLogEntry> decode(Uint8List data) {
    final r = ByteReader(data);
    final out = <DetectionLogEntry>[];
    while (r.remaining >= 18) {
      final block = r.u8();
      final flags = r.u8();
      out.add(DetectionLogEntry(
        block: block,
        keyType: (flags & 0x01) != 0 ? KeyType.b : KeyType.a,
        isNested: (flags & 0x02) != 0,
        uid: r.bytes(4),
        nt: r.u32(),
        nr: r.u32(),
        ar: r.u32(),
      ));
    }
    return out;
  }
}

final class Mf1GetDetectionEnable extends _GetBool {
  const Mf1GetDetectionEnable();
  @override
  int get id => 4007;
}

final class Mf1ReadEmuBlockData extends Command<Uint8List> {
  const Mf1ReadEmuBlockData(this.startBlock, this.count);
  final int startBlock;
  final int count;
  @override
  int get id => 4008;
  @override
  bool get idempotent => true;
  @override
  Uint8List encode() {
    if (count < 1 || count > 32) {
      throw ArgumentError.value(count, 'count', 'must be 1..32');
    }
    return ByteWriter().u8(startBlock).u8(count).toBytes();
  }

  @override
  Uint8List decode(Uint8List data) => ByteReader(data).bytes(count * 16);
}

final class Mf1GetEmulatorConfig extends Command<Mf1EmulatorConfig> {
  const Mf1GetEmulatorConfig();
  @override
  int get id => 4009;
  @override
  bool get idempotent => true;
  @override
  Mf1EmulatorConfig decode(Uint8List data) {
    final r = ByteReader(data);
    return Mf1EmulatorConfig(
      detectionEnabled: r.u8() != 0,
      gen1a: r.u8() != 0,
      gen2: r.u8() != 0,
      blockAntiColl: r.u8() != 0,
      writeMode: Mf1WriteMode.fromCode(r.u8()),
    );
  }
}

final class Mf1GetGen1aMode extends _GetBool {
  const Mf1GetGen1aMode();
  @override
  int get id => 4010;
}

final class Mf1SetGen1aMode extends _SetBool {
  const Mf1SetGen1aMode(super.value);
  @override
  int get id => 4011;
}

final class Mf1GetGen2Mode extends _GetBool {
  const Mf1GetGen2Mode();
  @override
  int get id => 4012;
}

final class Mf1SetGen2Mode extends _SetBool {
  const Mf1SetGen2Mode(super.value);
  @override
  int get id => 4013;
}

final class Mf1GetBlockAntiCollMode extends _GetBool {
  const Mf1GetBlockAntiCollMode();
  @override
  int get id => 4014;
}

final class Mf1SetBlockAntiCollMode extends _SetBool {
  const Mf1SetBlockAntiCollMode(super.value);
  @override
  int get id => 4015;
}

final class Mf1GetWriteMode extends Command<Mf1WriteMode> {
  const Mf1GetWriteMode();
  @override
  int get id => 4016;
  @override
  bool get idempotent => true;
  @override
  Mf1WriteMode decode(Uint8List data) => Mf1WriteMode.fromCode(ByteReader(data).u8());
}

final class Mf1SetWriteMode extends VoidCommand {
  const Mf1SetWriteMode(this.mode);
  final Mf1WriteMode mode;
  @override
  int get id => 4017;
  @override
  Uint8List encode() => ByteWriter().u8(mode.code).toBytes();
}

final class Hf14aGetAntiCollData extends Command<Hf14aTag> {
  const Hf14aGetAntiCollData();
  @override
  int get id => 4018;
  @override
  bool get idempotent => true;
  @override
  Hf14aTag decode(Uint8List data) {
    final r = ByteReader(data);
    final uid = r.bytes(r.u8());
    final atqa = r.bytes(2);
    final sak = r.u8();
    final ats = r.bytes(r.u8());
    return Hf14aTag(uid: uid, atqa: atqa, sak: sak, ats: ats);
  }
}

final class Mf0NtagGetUidMagicMode extends _GetBool {
  const Mf0NtagGetUidMagicMode();
  @override
  int get id => 4019;
}

final class Mf0NtagSetUidMagicMode extends _SetBool {
  const Mf0NtagSetUidMagicMode(super.value);
  @override
  int get id => 4020;
}

final class Mf0NtagReadEmuPageData extends Command<Uint8List> {
  const Mf0NtagReadEmuPageData(this.startPage, this.count);
  final int startPage;
  final int count;
  @override
  int get id => 4021;
  @override
  bool get idempotent => true;
  @override
  Uint8List encode() => ByteWriter().u8(startPage).u8(count).toBytes();
  @override
  Uint8List decode(Uint8List data) => ByteReader(data).bytes(count * 4);
}

final class Mf0NtagWriteEmuPageData extends VoidCommand {
  Mf0NtagWriteEmuPageData(this.startPage, this.data) {
    if (data.isEmpty || data.length % 4 != 0) {
      throw ArgumentError.value(data.length, 'data', 'must be a multiple of 4 bytes');
    }
  }
  final int startPage;
  final Uint8List data;
  @override
  int get id => 4022;
  @override
  Uint8List encode() =>
      ByteWriter().u8(startPage).u8(data.length ~/ 4).bytes(data).toBytes();
}

final class Mf0NtagGetPageCount extends Command<int> {
  const Mf0NtagGetPageCount();
  @override
  int get id => 4030;
  @override
  bool get idempotent => true;
  @override
  int decode(Uint8List data) => ByteReader(data).u8();
}
```

Commands 4023-4029, 4031-4044 (Ultralight version, signature, counters, write mode, detection, MF1 field-off reset, PRNG type, SEOS) stay reachable through `RawCommand` and are hardware-validate; list them in a doc comment at the bottom of the file with their ids and the payloads from `docs/research/chameleon-protocol.md`.

```dart
// lib/src/commands/lf_emulator.dart
import 'dart:typed_data';

import '../codec/bytes.dart';
import '../protocol/command.dart';

/// Wire lengths of each LF emulator id.
const Map<int, int> emuLfIdLengths = {
  5000: 5, 5002: 13, 5004: 4, 5006: 8, 5010: 5, 5012: 8,
};

abstract base class _SetId extends VoidCommand {
  _SetId(this.idBytes) {
    final n = emuLfIdLengths[id]!;
    if (idBytes.length != n) {
      throw ArgumentError.value(idBytes.length, 'id', 'must be $n bytes');
    }
  }
  final Uint8List idBytes;
  @override
  Uint8List encode() => idBytes;
}

abstract base class _GetId extends Command<Uint8List> {
  const _GetId();
  @override
  bool get idempotent => true;
  @override
  Uint8List decode(Uint8List data) => ByteReader(data).bytes(emuLfIdLengths[id - 1]!);
}

final class Em410xSetEmuId extends _SetId {
  Em410xSetEmuId(super.idBytes);
  @override
  int get id => 5000;
}

final class Em410xGetEmuId extends _GetId {
  const Em410xGetEmuId();
  @override
  int get id => 5001;
}

final class HidProxSetEmuId extends _SetId {
  HidProxSetEmuId(super.idBytes);
  @override
  int get id => 5002;
}

final class HidProxGetEmuId extends _GetId {
  const HidProxGetEmuId();
  @override
  int get id => 5003;
}

final class VikingSetEmuId extends _SetId {
  VikingSetEmuId(super.idBytes);
  @override
  int get id => 5004;
}

final class VikingGetEmuId extends _GetId {
  const VikingGetEmuId();
  @override
  int get id => 5005;
}

final class PacSetEmuId extends _SetId {
  PacSetEmuId(super.idBytes);
  @override
  int get id => 5006;
}

final class PacGetEmuId extends _GetId {
  const PacGetEmuId();
  @override
  int get id => 5007;
}

final class JablotronSetEmuId extends _SetId {
  JablotronSetEmuId(super.idBytes);
  @override
  int get id => 5010;
}

final class JablotronGetEmuId extends _GetId {
  const JablotronGetEmuId();
  @override
  int get id => 5011;
}

final class IdteckSetEmuId extends _SetId {
  IdteckSetEmuId(super.idBytes);
  @override
  int get id => 5012;
}

final class IdteckGetEmuId extends _GetId {
  const IdteckGetEmuId();
  @override
  int get id => 5013;
}
```

Note: `_SetId`'s constructor reads `id`, a getter overridden by the subclass; that is legal in Dart because the subclass getter is a plain override with no field initialization order concern. IoProx (5008/5009) has an undocumented length and stays on `RawCommand`.

```dart
// lib/src/commands/iso14443_4.dart
/// ISO14443-4 commands 6000-6005 (Ultra only). All hardware-validate; the
/// wiki does not document payloads. Reach them through RawCommand:
///
/// | 6000 | APDU_RECV | 6001 | APDU_SEND | 6002 | SET_ANTI_COLL |
/// | 6003 | STATIC_RESP | 6004 | READER_APDU | 6005 | EMV_SCAN |
library;

const Set<int> iso14443_4CommandIds = {6000, 6001, 6002, 6003, 6004, 6005};
```

- [ ] **Step 4: Run to verify pass**

Run: `mise x -- dart test test/commands`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): add emulator command catalog"
```

---

### Task 9: Transport, scanner and frame log interfaces

**Files:**
- Create: `lib/src/transport/transport.dart`, `lib/src/transport/scanner.dart`, `lib/src/transport/frame_log.dart`, `test/transport/frame_log_test.dart`

**Interfaces:**
- Produces:

```dart
enum TransportKind { usb, ble, fake }
enum CloseCause { requested, linkLost }
sealed class TransportState; TransportOpening; TransportOpen; TransportClosed(CloseCause cause, {TransportError? error}); TransportPairingRequired
abstract interface class Transport { TransportKind kind; Future<void> open(); Future<void> close(); Stream<Uint8List> incoming; Future<void> write(Uint8List); Stream<TransportState> state; TransportState currentState; }
final class DiscoveredDevice { String name; TransportKind kind; String transportId; bool isBootloader; }
abstract interface class DeviceScanner { TransportKind kind; Stream<List<DiscoveredDevice>> scan(); }
enum FrameDirection { sent, received }
final class FrameLogEntry { DateTime at; FrameDirection direction; Frame frame; }
final class FrameLog { FrameLog({int capacity = 512}); void add(FrameDirection, Frame); List<FrameLogEntry> get entries; String export(); }
```

- [ ] **Step 1: Write the failing test**

```dart
// test/transport/frame_log_test.dart
import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/transport/frame_log.dart';
import 'package:test/test.dart';

void main() {
  test('keeps only the newest entries', () {
    final log = FrameLog(capacity: 2);
    log.add(FrameDirection.sent, Frame(command: 1));
    log.add(FrameDirection.sent, Frame(command: 2));
    log.add(FrameDirection.received, Frame(command: 3));
    expect(log.entries.map((e) => e.frame.command), [2, 3]);
  });

  test('exports one line per frame', () {
    final log = FrameLog();
    log.add(FrameDirection.sent, Frame(command: 1000));
    expect(log.export(), contains('> cmd=1000'));
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/transport`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/src/transport/transport.dart
import 'dart:typed_data';

import '../protocol/errors.dart';

enum TransportKind { usb, ble, fake }

/// Why a transport closed. The session decides whether a link loss was
/// expected (bootloader reboot) or not.
enum CloseCause { requested, linkLost }

sealed class TransportState {
  const TransportState();
}

final class TransportOpening extends TransportState {
  const TransportOpening();
}

final class TransportOpen extends TransportState {
  const TransportOpen();
}

final class TransportClosed extends TransportState {
  const TransportClosed(this.cause, {this.error});
  final CloseCause cause;
  final TransportError? error;
}

final class TransportPairingRequired extends TransportState {
  const TransportPairingRequired();
}

/// Moves bytes. Knows nothing about frames.
abstract interface class Transport {
  TransportKind get kind;
  Future<void> open();
  Future<void> close();
  Stream<Uint8List> get incoming;
  Future<void> write(Uint8List bytes);
  Stream<TransportState> get state;
  TransportState get currentState;
}
```

```dart
// lib/src/transport/scanner.dart
import 'transport.dart';

final class DiscoveredDevice {
  const DiscoveredDevice({
    required this.name,
    required this.kind,
    required this.transportId,
    this.isBootloader = false,
  });

  final String name;
  final TransportKind kind;

  /// Transport-specific identifier: serial port path, BLE address, fake id.
  final String transportId;
  final bool isBootloader;

  @override
  bool operator ==(Object o) =>
      o is DiscoveredDevice && o.kind == kind && o.transportId == transportId;

  @override
  int get hashCode => Object.hash(kind, transportId);

  @override
  String toString() => 'DiscoveredDevice($name, $kind, $transportId, bootloader=$isBootloader)';
}

/// Emits the current list of visible devices whenever it changes.
abstract interface class DeviceScanner {
  TransportKind get kind;
  Stream<List<DiscoveredDevice>> scan();
}
```

```dart
// lib/src/transport/frame_log.dart
import 'dart:collection';

import '../codec/frame.dart';

enum FrameDirection { sent, received }

final class FrameLogEntry {
  FrameLogEntry(this.at, this.direction, this.frame);
  final DateTime at;
  final FrameDirection direction;
  final Frame frame;
}

/// Ring buffer of frames in both directions. Always on; small.
final class FrameLog {
  FrameLog({this.capacity = 512});
  final int capacity;
  final Queue<FrameLogEntry> _entries = Queue();

  void add(FrameDirection direction, Frame frame) {
    _entries.addLast(FrameLogEntry(DateTime.now(), direction, frame));
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
  }

  List<FrameLogEntry> get entries => List.unmodifiable(_entries);

  String export() {
    final b = StringBuffer();
    for (final e in _entries) {
      final arrow = e.direction == FrameDirection.sent ? '>' : '<';
      final hex = e.frame.data.map((x) => x.toRadixString(16).padLeft(2, '0')).join(' ');
      b.writeln('${e.at.toIso8601String()} $arrow cmd=${e.frame.command} '
          'status=0x${e.frame.status.toRadixString(16)} len=${e.frame.data.length} $hex');
    }
    return b.toString();
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `mise x -- dart test test/transport`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): add Transport, DeviceScanner and FrameLog"
```

---

### Task 10: FakeFirmware

**Files:**
- Create: `lib/src/fake/fake_card.dart`, `lib/src/fake/fake_firmware.dart`, `test/fake/fake_firmware_test.dart`

**Interfaces:**
- Produces:

```dart
sealed class FakeCard; FakeMf1Card({uid, atqa, sak, ats, blocks, keys: Map<String, Uint8List> keyed '$sector${A|B}', prng}); FakeUltralightCard({uid, pages}); FakeLfCard(int scanCommandId, Uint8List idBytes)
final class FakeFirmwareConfig { model, version, gitVersion, chipId, address, capabilities (Set<int>?), respondsToCapabilities, settingsVersion; factory .ultra22(), .ultra20(), .lite22(), .preTwoPointZero(), .legacy01() }
final class FakeSlot { hfType, lfType, hfEnabled, lfEnabled, hfNick, lfNick, mf1Blocks (4096 bytes), antiColl, mf1Config, ntagPages (231*4), lfIds Map<int, Uint8List>, detectionLog List<Uint8List> }
final class FakeFirmware { FakeFirmware([FakeFirmwareConfig]); Frame? handle(Frame request); DeviceMode mode; int activeSlot; List<FakeSlot> slots; DeviceSettings settings; DeviceSettings savedSettings; bool slotsSaved; BatteryInfo battery; bool bootloaderRequested; FakeCard? hfCard; FakeCard? lfCard; void present(FakeCard); void removeCards(); }
```

- [ ] **Step 1: Write the failing tests**

```dart
// test/fake/fake_firmware_test.dart
import 'dart:typed_data';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/commands/device.dart';
import 'package:chameleon/src/commands/hf_emulator.dart';
import 'package:chameleon/src/commands/hf_reader.dart';
import 'package:chameleon/src/commands/lf_reader.dart';
import 'package:chameleon/src/fake/fake_card.dart';
import 'package:chameleon/src/fake/fake_firmware.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/protocol/command.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/protocol/status.dart';
import 'package:test/test.dart';

R run<R>(FakeFirmware fw, Command<R> c) => c.parseResponse(fw.handle(c.toFrame())!);

Uint8List b(List<int> l) => Uint8List.fromList(l);

void main() {
  test('answers version, model and capabilities', () {
    final fw = FakeFirmware();
    expect(run(fw, const GetAppVersion()).label, '2.2');
    expect(run(fw, const GetDeviceModel()), DeviceModel.ultra);
    expect(run(fw, const GetDeviceCapabilities()).supports(2000), isTrue);
  });

  test('lite has no reader capabilities and rejects reader mode', () {
    final fw = FakeFirmware(FakeFirmwareConfig.lite22());
    expect(run(fw, const GetDeviceCapabilities()).hasReader, isFalse);
    final f = fw.handle(const ChangeDeviceMode(DeviceMode.reader).toFrame())!;
    expect(f.status, Status.notImplemented);
  });

  test('pre-2.0 answers INVALID_CMD to capabilities', () {
    final fw = FakeFirmware(FakeFirmwareConfig.preTwoPointZero());
    expect(fw.handle(const GetDeviceCapabilities().toFrame())!.status, Status.invalidCmd);
  });

  test('2.0 lacks GET_ALL_SLOT_NICKS and omits sleep timeout byte', () {
    final fw = FakeFirmware(FakeFirmwareConfig.ultra20());
    expect(fw.handle(const GetAllSlotNicks().toFrame())!.status, Status.invalidCmd);
    expect(run(fw, const GetDeviceSettings()).sleepTimeoutSeconds, isNull);
    expect(run(fw, const GetSlotTagNick(0, Sense.hf)), isNotNull);
  });

  test('slot edits persist in memory and mark unsaved until SLOT_DATA_CONFIG_SAVE', () {
    final fw = FakeFirmware();
    run(fw, const SetSlotTagType(3, TagType.ntag215));
    run(fw, const SetSlotEnable(3, Sense.hf, true));
    run(fw, const SetSlotTagNick(3, Sense.hf, 'gym'));
    expect(run(fw, const GetSlotInfo())[3].hf, TagType.ntag215);
    expect(run(fw, const GetEnabledSlots())[3].hf, isTrue);
    expect(run(fw, const GetSlotTagNick(3, Sense.hf)), 'gym');
    expect(fw.slotsSaved, isFalse);
    run(fw, const SlotDataConfigSave());
    expect(fw.slotsSaved, isTrue);
  });

  test('reader commands need reader mode', () {
    final fw = FakeFirmware();
    expect(fw.handle(const Hf14aScan().toFrame())!.status, Status.deviceModeError);
    run(fw, const ChangeDeviceMode(DeviceMode.reader));
    expect(fw.handle(const Hf14aScan().toFrame())!.status, Status.hfTagNo);
  });

  test('presented MF1 card is scanned, authenticated and read', () {
    final fw = FakeFirmware();
    final card = FakeMf1Card.classic1k(uid: b([1, 2, 3, 4]));
    fw.present(card);
    run(fw, const ChangeDeviceMode(DeviceMode.reader));
    final tags = run(fw, const Hf14aScan());
    expect(tags.single.uidHex, '01020304');
    final good = FakeMf1Card.defaultKey;
    expect(() => run(fw, Mf1AuthOneKeyBlock(KeyType.a, 0, good)), returnsNormally);
    expect(fw.handle(Mf1AuthOneKeyBlock(KeyType.a, 0, Uint8List(6)).toFrame())!.status,
        Status.mfErrAuth);
    final block0 = run(fw, Mf1ReadOneBlock(KeyType.a, 0, good));
    expect(block0.sublist(0, 4), [1, 2, 3, 4]);
    run(fw, Mf1WriteOneBlock(KeyType.a, 1, good, Uint8List.fromList(List.filled(16, 0x42))));
    expect(card.blocks.sublist(16, 32), List.filled(16, 0x42));
  });

  test('LF card scan', () {
    final fw = FakeFirmware();
    fw.present(FakeLfCard(3000, b([0xDE, 0xAD, 0xBE, 0xEF, 0x01])));
    run(fw, const ChangeDeviceMode(DeviceMode.reader));
    expect(run(fw, const Em410xScan()), [0xDE, 0xAD, 0xBE, 0xEF, 0x01]);
    expect(fw.handle(const HidProxScan().toFrame())!.status, Status.lfTagNoFound);
  });

  test('emulator block data round-trips on the active slot', () {
    final fw = FakeFirmware();
    final data = Uint8List.fromList(List.generate(32, (i) => i));
    run(fw, Mf1WriteEmuBlockData(2, data));
    expect(run(fw, const Mf1ReadEmuBlockData(2, 2)), data);
    run(fw, const SetActiveSlot(1));
    expect(run(fw, const Mf1ReadEmuBlockData(2, 2)), Uint8List(32));
  });

  test('ENTER_BOOTLOADER has no response and sets the flag', () {
    final fw = FakeFirmware();
    expect(fw.handle(const EnterBootloader().toFrame()), isNull);
    expect(fw.bootloaderRequested, isTrue);
  });

  test('malformed payload answers PAR_ERR', () {
    final fw = FakeFirmware();
    expect(fw.handle(Frame(command: 1003)).status, Status.parErr);
  });

  test('unknown command answers INVALID_CMD', () {
    final fw = FakeFirmware();
    expect(fw.handle(Frame(command: 1999))!.status, Status.invalidCmd);
  });

  test('settings save and reset', () {
    final fw = FakeFirmware();
    run(fw, const SetAnimationMode(AnimationMode.none));
    expect(run(fw, const GetDeviceSettings()).animation, AnimationMode.none);
    expect(fw.savedSettings.animation, AnimationMode.full);
    run(fw, const SaveSettings());
    expect(fw.savedSettings.animation, AnimationMode.none);
    run(fw, const ResetSettings());
    expect(run(fw, const GetDeviceSettings()).animation, AnimationMode.full);
  });

  test('errors surface as typed DeviceError through parseResponse', () {
    final fw = FakeFirmware();
    expect(() => run(fw, const Hf14aScan()), throwsA(isA<DeviceModeError>()));
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/fake`
Expected: FAIL.

- [ ] **Step 3: Implement fake cards**

```dart
// lib/src/fake/fake_card.dart
import 'dart:typed_data';

import '../model/enums.dart';

/// A card the fake reader can "see". Present one with FakeFirmware.present.
sealed class FakeCard {
  const FakeCard();
}

final class FakeMf1Card extends FakeCard {
  FakeMf1Card({
    required this.uid,
    required this.atqa,
    required this.sak,
    required this.ats,
    required this.blocks,
    required this.keys,
    this.prng = PrngType.weak,
  });

  /// A 1K card with FF FF FF FF FF FF on every sector and UID in block 0.
  factory FakeMf1Card.classic1k({required Uint8List uid}) {
    final blocks = Uint8List(64 * 16);
    blocks.setRange(0, uid.length, uid);
    blocks[uid.length] = uid.fold(0, (a, b) => a ^ b); // BCC
    blocks[5] = 0x08;
    blocks[6] = 0x04;
    blocks[7] = 0x00;
    final keys = <String, Uint8List>{};
    for (var s = 0; s < 16; s++) {
      keys[keyId(s, KeyType.a)] = defaultKey;
      keys[keyId(s, KeyType.b)] = defaultKey;
      final trailer = s * 4 + 3;
      blocks.setRange(trailer * 16, trailer * 16 + 6, defaultKey);
      blocks.setRange(trailer * 16 + 6, trailer * 16 + 10, [0xFF, 0x07, 0x80, 0x69]);
      blocks.setRange(trailer * 16 + 10, trailer * 16 + 16, defaultKey);
    }
    return FakeMf1Card(
      uid: uid,
      atqa: Uint8List.fromList([0x00, 0x04]),
      sak: 0x08,
      ats: Uint8List(0),
      blocks: blocks,
      keys: keys,
    );
  }

  static final Uint8List defaultKey = Uint8List.fromList(List.filled(6, 0xFF));

  static String keyId(int sector, KeyType t) => '$sector${t == KeyType.a ? 'A' : 'B'}';

  final Uint8List uid;
  final Uint8List atqa;
  final int sak;
  final Uint8List ats;
  final Uint8List blocks;
  final Map<String, Uint8List> keys;
  final PrngType prng;

  int get blockCount => blocks.length ~/ 16;

  static int sectorOf(int block) => block < 128 ? block ~/ 4 : 32 + (block - 128) ~/ 16;

  bool authenticates(int block, KeyType type, Uint8List key) {
    if (block >= blockCount) return false;
    final expected = keys[keyId(sectorOf(block), type)];
    if (expected == null) return false;
    for (var i = 0; i < 6; i++) {
      if (expected[i] != key[i]) return false;
    }
    return true;
  }
}

final class FakeUltralightCard extends FakeCard {
  FakeUltralightCard({required this.uid, required this.pages});
  final Uint8List uid;
  final Uint8List pages;
}

/// An LF card answering one scan command id (3000 EM410X, 3002 HID Prox,
/// 3004 Viking, 3014 PAC) with fixed id bytes.
final class FakeLfCard extends FakeCard {
  const FakeLfCard(this.scanCommandId, this.idBytes);
  final int scanCommandId;
  final Uint8List idBytes;
}
```

- [ ] **Step 4: Implement the firmware**

```dart
// lib/src/fake/fake_firmware.dart
import 'dart:convert';
import 'dart:typed_data';

import '../codec/bytes.dart';
import '../codec/frame.dart';
import '../commands/lf_emulator.dart' show emuLfIdLengths;
import '../model/enums.dart';
import '../model/models.dart';
import '../protocol/command.dart';
import '../protocol/errors.dart';
import '../protocol/status.dart';
import 'fake_card.dart';

final class FakeFirmwareConfig {
  FakeFirmwareConfig({
    this.model = DeviceModel.ultra,
    this.version = const FirmwareVersion(major: 2, minor: 2),
    this.gitVersion = 'v2.2.0-fake',
    this.chipId = '0102030405060708',
    this.address = '00:11:22:33:44:55',
    this.capabilities,
    this.respondsToCapabilities = true,
    this.settingsVersion = 6,
  });

  factory FakeFirmwareConfig.ultra22() => FakeFirmwareConfig();

  factory FakeFirmwareConfig.ultra20() => FakeFirmwareConfig(
        version: const FirmwareVersion(major: 2, minor: 0),
        gitVersion: 'v2.0.0-fake',
        capabilities: defaultCapabilities(DeviceModel.ultra)
          ..removeAll({1038, 1039, 1040, 4042, 4043, 4044}),
        settingsVersion: 5,
      );

  factory FakeFirmwareConfig.lite22() => FakeFirmwareConfig(model: DeviceModel.lite);

  factory FakeFirmwareConfig.preTwoPointZero() => FakeFirmwareConfig(
        version: const FirmwareVersion(major: 1, minor: 0),
        respondsToCapabilities: false,
      );

  factory FakeFirmwareConfig.legacy01() => FakeFirmwareConfig(
        version: const FirmwareVersion(major: 0, minor: 1),
      );

  final DeviceModel model;
  final FirmwareVersion version;
  final String gitVersion;
  final String chipId;
  final String address;
  final Set<int>? capabilities;
  final bool respondsToCapabilities;
  final int settingsVersion;

  /// Computed once so tests can mutate it to simulate missing commands.
  late final Set<int> effectiveCapabilities = capabilities ?? defaultCapabilities(model);

  static Set<int> defaultCapabilities(DeviceModel model) {
    final ids = <int>{
      for (var i = 1000; i <= 1040; i++) if (i != 1022) i,
      for (var i = 4000; i <= 4044; i++) if (i != 4002 && i != 4003) i,
      for (var i = 5000; i <= 5013; i++) i,
    };
    if (model == DeviceModel.ultra) {
      ids.addAll({
        for (var i = 2000; i <= 2017; i++) i, 2020, 2100, 2101, 2200, 2201,
        for (var i = 3000; i <= 3006; i++) i,
        for (var i = 3009; i <= 3016; i++) i,
        3018, 3019, 3020, 3030, 3031,
        for (var i = 6000; i <= 6005; i++) i,
      });
    }
    return ids;
  }
}

final class FakeSlot {
  TagType hfType = TagType.undefined;
  TagType lfType = TagType.undefined;
  bool hfEnabled = false;
  bool lfEnabled = false;
  String hfNick = '';
  String lfNick = '';
  final Uint8List mf1Blocks = Uint8List(256 * 16);
  Hf14aTag antiColl = Hf14aTag(
    uid: Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
    atqa: Uint8List.fromList([0x00, 0x04]),
    sak: 0x08,
    ats: Uint8List(0),
  );
  Mf1EmulatorConfig mf1Config = const Mf1EmulatorConfig(
    detectionEnabled: false,
    gen1a: false,
    gen2: false,
    blockAntiColl: false,
    writeMode: Mf1WriteMode.normal,
  );
  bool uidMagic = false;
  final Uint8List ntagPages = Uint8List(231 * 4);
  final Map<int, Uint8List> lfIds = {
    for (final e in emuLfIdLengths.entries) e.key: Uint8List(e.value),
  };
  final List<Uint8List> detectionLog = [];

  int get ntagPageCount => switch (hfType) {
        TagType.ntag210 => 20,
        TagType.ntag212 => 41,
        TagType.ntag213 => 45,
        TagType.ntag215 => 135,
        TagType.ntag216 => 231,
        TagType.mf0icu1 => 16,
        TagType.mf0icu2 => 44,
        TagType.mf0ul11 => 20,
        TagType.mf0ul21 => 41,
        _ => 0,
      };
}

DeviceSettings _defaultSettings(int version) => DeviceSettings(
      version: version,
      animation: AnimationMode.full,
      buttonA: ButtonFunction.nextSlot,
      buttonB: ButtonFunction.prevSlot,
      longButtonA: ButtonFunction.cloneUid,
      longButtonB: ButtonFunction.battery,
      blePairingEnabled: false,
      blePairingKey: '123456',
      sleepTimeoutSeconds: version >= 6 ? 8 : null,
    );

/// Answers frames the way the firmware does. Pure: no timers, no streams.
final class FakeFirmware {
  FakeFirmware([FakeFirmwareConfig? config]) : config = config ?? FakeFirmwareConfig() {
    settings = _defaultSettings(this.config.settingsVersion);
    savedSettings = settings;
    slots[0]
      ..hfType = TagType.mifare1k
      ..hfEnabled = true
      ..hfNick = 'Fake 1K'
      ..lfType = TagType.em410x
      ..lfEnabled = true;
  }

  final FakeFirmwareConfig config;
  final List<FakeSlot> slots = List.generate(8, (_) => FakeSlot());
  DeviceMode mode = DeviceMode.emulator;
  int activeSlot = 0;
  late DeviceSettings settings;
  late DeviceSettings savedSettings;
  bool slotsSaved = true;
  BatteryInfo battery = const BatteryInfo(millivolts: 4100, percent: 92);
  bool bootloaderRequested = false;
  FakeCard? hfCard;
  FakeCard? lfCard;

  void present(FakeCard card) {
    if (card is FakeLfCard) {
      lfCard = card;
    } else {
      hfCard = card;
    }
  }

  void removeCards() {
    hfCard = null;
    lfCard = null;
  }

  FakeSlot get _slot => slots[activeSlot];

  Frame? handle(Frame req) {
    final cmd = req.command;
    if (cmd == 1010) {
      bootloaderRequested = true;
      return null;
    }
    if (cmd == 1035 && !config.respondsToCapabilities) {
      return _status(cmd, Status.invalidCmd);
    }
    if (!config.effectiveCapabilities.contains(cmd)) {
      return _status(cmd, Status.invalidCmd);
    }
    final range = CommandRange.forId(cmd);
    final isReader = range == CommandRange.hfReader || range == CommandRange.lfReader;
    if (isReader && mode != DeviceMode.reader) {
      return _status(cmd, Status.deviceModeError);
    }
    try {
      return _dispatch(cmd, ByteReader(req.data));
    } on MalformedResponse {
      return _status(cmd, Status.parErr);
    }
  }

  Frame _status(int cmd, int status, [List<int>? data]) =>
      Frame(command: cmd, status: status, data: data == null ? null : Uint8List.fromList(data));

  Frame _ok(int cmd, [List<int>? data]) => _status(cmd, CommandRange.forId(cmd).successStatus, data);

  Frame _dispatch(int cmd, ByteReader r) {
    switch (cmd) {
      // Device
      case 1000:
        return _ok(cmd, [config.version.major, config.version.minor]);
      case 1001:
        final m = DeviceMode.fromCode(r.u8());
        if (m == DeviceMode.reader && config.model == DeviceModel.lite) {
          return _status(cmd, Status.notImplemented);
        }
        mode = m;
        return _ok(cmd);
      case 1002:
        return _ok(cmd, [mode.code]);
      case 1003:
        activeSlot = _slotIndex(r.u8());
        return _ok(cmd);
      case 1004:
        final s = slots[_slotIndex(r.u8())];
        final t = TagType.fromCode(r.u16());
        if (t.sense == Sense.lf) {
          s.lfType = t;
        } else {
          s.hfType = t;
        }
        slotsSaved = false;
        return _ok(cmd);
      case 1005:
        final s = slots[_slotIndex(r.u8())];
        final t = TagType.fromCode(r.u16());
        if (t.sense == Sense.lf) {
          s.lfType = t;
          s.lfIds.updateAll((k, v) => Uint8List(v.length));
        } else {
          s.hfType = t;
          s.mf1Blocks.fillRange(0, s.mf1Blocks.length, 0);
          s.ntagPages.fillRange(0, s.ntagPages.length, 0);
        }
        slotsSaved = false;
        return _ok(cmd);
      case 1006:
        final s = slots[_slotIndex(r.u8())];
        final sense = Sense.fromCode(r.u8());
        final en = r.u8() != 0;
        if (sense == Sense.lf) {
          s.lfEnabled = en;
        } else {
          s.hfEnabled = en;
        }
        slotsSaved = false;
        return _ok(cmd);
      case 1007:
        final s = slots[_slotIndex(r.u8())];
        final sense = Sense.fromCode(r.u8());
        final nick = utf8.decode(r.rest(), allowMalformed: true);
        if (sense == Sense.lf) {
          s.lfNick = nick;
        } else {
          s.hfNick = nick;
        }
        slotsSaved = false;
        return _ok(cmd);
      case 1008:
        final s = slots[_slotIndex(r.u8())];
        final sense = Sense.fromCode(r.u8());
        return _ok(cmd, utf8.encode(sense == Sense.lf ? s.lfNick : s.hfNick));
      case 1009:
        slotsSaved = true;
        return _ok(cmd);
      case 1011:
        return _ok(cmd, _hexToBytes(config.chipId));
      case 1012:
        return _ok(cmd, _hexToBytes(config.address.replaceAll(':', '')));
      case 1013:
        savedSettings = settings;
        return _ok(cmd);
      case 1014:
        settings = _defaultSettings(config.settingsVersion);
        savedSettings = settings;
        return _ok(cmd);
      case 1015:
        settings = settings.copyWith(animation: AnimationMode.fromCode(r.u8()));
        return _ok(cmd);
      case 1016:
        return _ok(cmd, [settings.animation.code]);
      case 1017:
        return _ok(cmd, utf8.encode(config.gitVersion));
      case 1018:
        return _ok(cmd, [activeSlot]);
      case 1019:
        final w = ByteWriter();
        for (final s in slots) {
          w.u16(s.hfType.code).u16(s.lfType.code);
        }
        return _ok(cmd, w.toBytes());
      case 1020:
        for (final s in slots) {
          s.hfType = TagType.undefined;
          s.lfType = TagType.undefined;
          s.hfEnabled = false;
          s.lfEnabled = false;
          s.hfNick = '';
          s.lfNick = '';
        }
        return _ok(cmd);
      case 1021:
        final s = slots[_slotIndex(r.u8())];
        if (Sense.fromCode(r.u8()) == Sense.lf) {
          s.lfNick = '';
        } else {
          s.hfNick = '';
        }
        slotsSaved = false;
        return _ok(cmd);
      case 1023:
        final w = ByteWriter();
        for (final s in slots) {
          w.u8(s.hfEnabled ? 1 : 0).u8(s.lfEnabled ? 1 : 0);
        }
        return _ok(cmd, w.toBytes());
      case 1024:
        final s = slots[_slotIndex(r.u8())];
        if (Sense.fromCode(r.u8()) == Sense.lf) {
          s.lfType = TagType.undefined;
          s.lfEnabled = false;
        } else {
          s.hfType = TagType.undefined;
          s.hfEnabled = false;
        }
        slotsSaved = false;
        return _ok(cmd);
      case 1025:
        return _ok(cmd, ByteWriter().u16(battery.millivolts).u8(battery.percent).toBytes());
      case 1026:
        return _ok(cmd, [(r.u8() == DeviceButton.a.code ? settings.buttonA : settings.buttonB).code]);
      case 1027:
        final btn = r.u8();
        final fn = ButtonFunction.fromCode(r.u8());
        settings = btn == DeviceButton.a.code
            ? settings.copyWith(buttonA: fn)
            : settings.copyWith(buttonB: fn);
        return _ok(cmd);
      case 1028:
        return _ok(cmd, [
          (r.u8() == DeviceButton.a.code ? settings.longButtonA : settings.longButtonB).code
        ]);
      case 1029:
        final btn = r.u8();
        final fn = ButtonFunction.fromCode(r.u8());
        settings = btn == DeviceButton.a.code
            ? settings.copyWith(longButtonA: fn)
            : settings.copyWith(longButtonB: fn);
        return _ok(cmd);
      case 1030:
        settings = settings.copyWith(blePairingKey: r.utf8String(6));
        return _ok(cmd);
      case 1031:
        return _ok(cmd, utf8.encode(settings.blePairingKey));
      case 1032:
        return _ok(cmd);
      case 1033:
        return _ok(cmd, [config.model.code]);
      case 1034:
        final w = ByteWriter()
            .u8(settings.version)
            .u8(settings.animation.code)
            .u8(settings.buttonA.code)
            .u8(settings.buttonB.code)
            .u8(settings.longButtonA.code)
            .u8(settings.longButtonB.code)
            .u8(settings.blePairingEnabled ? 1 : 0)
            .utf8String(settings.blePairingKey);
        if (config.settingsVersion >= 6) {
          w.u8(settings.sleepTimeoutSeconds ?? 8);
        }
        return _ok(cmd, w.toBytes());
      case 1035:
        final w = ByteWriter();
        for (final id in config.effectiveCapabilities.toList()..sort()) {
          w.u16(id);
        }
        return _ok(cmd, w.toBytes());
      case 1036:
        return _ok(cmd, [settings.blePairingEnabled ? 1 : 0]);
      case 1037:
        settings = settings.copyWith(blePairingEnabled: r.u8() != 0);
        return _ok(cmd);
      case 1038:
        final w = ByteWriter();
        for (final s in slots) {
          final hf = utf8.encode(s.hfNick);
          final lf = utf8.encode(s.lfNick);
          w.u8(hf.length).bytes(hf).u8(lf.length).bytes(lf);
        }
        return _ok(cmd, w.toBytes());
      case 1039:
        return _ok(cmd, [settings.sleepTimeoutSeconds ?? 8]);
      case 1040:
        settings = settings.copyWith(sleepTimeoutSeconds: r.u8());
        return _ok(cmd);

      // HF reader
      case 2000:
        final c = hfCard;
        return switch (c) {
          FakeMf1Card() => _ok(cmd, _antiCollBytes(c.uid, c.atqa, c.sak, c.ats)),
          FakeUltralightCard() => _ok(cmd,
              _antiCollBytes(c.uid, Uint8List.fromList([0x00, 0x44]), 0x00, Uint8List(0))),
          _ => _status(cmd, Status.hfTagNo),
        };
      case 2001:
        return hfCard is FakeMf1Card ? _ok(cmd) : _status(cmd, Status.hfTagNo);
      case 2002:
        final c = hfCard;
        return c is FakeMf1Card ? _ok(cmd, [c.prng.code]) : _status(cmd, Status.hfTagNo);
      case 2007:
        final failure = _mf1Auth(cmd, r);
        return failure ?? _ok(cmd);
      case 2008:
        final c = hfCard;
        final type = KeyType.fromCode(r.u8());
        final block = r.u8();
        final key = r.bytes(6);
        if (c is! FakeMf1Card) return _status(cmd, Status.hfTagNo);
        if (!c.authenticates(block, type, key)) return _status(cmd, Status.mfErrAuth);
        return _ok(cmd, c.blocks.sublist(block * 16, block * 16 + 16));
      case 2009:
        final c = hfCard;
        final type = KeyType.fromCode(r.u8());
        final block = r.u8();
        final key = r.bytes(6);
        final data = r.bytes(16);
        if (c is! FakeMf1Card) return _status(cmd, Status.hfTagNo);
        if (!c.authenticates(block, type, key)) return _status(cmd, Status.mfErrAuth);
        c.blocks.setRange(block * 16, block * 16 + 16, data);
        return _ok(cmd);
      case 2012:
        final c = hfCard;
        if (c is! FakeMf1Card) return _status(cmd, Status.hfTagNo);
        final mask = r.bytes(10);
        final keys = <Uint8List>[];
        while (r.remaining >= 6) {
          keys.add(r.bytes(6));
        }
        final found = Uint8List(10);
        final out = ByteWriter().bytes(found);
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
        return _ok(cmd, ByteWriter().bytes(found).bytes(keyBytes).toBytes());
      case 2100 || 2101:
        return _ok(cmd);

      // LF reader
      case 3000 || 3002 || 3004 || 3014:
        final c = lfCard;
        if (c is FakeLfCard && c.scanCommandId == cmd) return _ok(cmd, c.idBytes);
        return _status(cmd, Status.lfTagNoFound);

      // HF emulator
      case 4000:
        final start = r.u8();
        final data = r.rest();
        _slot.mf1Blocks.setRange(start * 16, start * 16 + data.length, data);
        return _ok(cmd);
      case 4001:
        final uid = r.bytes(r.u8());
        final atqa = r.bytes(2);
        final sak = r.u8();
        final ats = r.bytes(r.u8());
        _slot.antiColl = Hf14aTag(uid: uid, atqa: atqa, sak: sak, ats: ats);
        return _ok(cmd);
      case 4004:
        _slot.mf1Config = _slot.mf1Config.copyWith(detectionEnabled: r.u8() != 0);
        return _ok(cmd);
      case 4005:
        return _ok(cmd, ByteWriter().u32(_slot.detectionLog.length).toBytes());
      case 4006:
        final idx = r.u32();
        final w = ByteWriter();
        for (final e in _slot.detectionLog.skip(idx)) {
          w.bytes(e);
        }
        return _ok(cmd, w.toBytes());
      case 4007:
        return _ok(cmd, [_slot.mf1Config.detectionEnabled ? 1 : 0]);
      case 4008:
        final start = r.u8();
        final count = r.u8();
        return _ok(cmd, _slot.mf1Blocks.sublist(start * 16, (start + count) * 16));
      case 4009:
        final c = _slot.mf1Config;
        return _ok(cmd, [
          c.detectionEnabled ? 1 : 0, c.gen1a ? 1 : 0, c.gen2 ? 1 : 0,
          c.blockAntiColl ? 1 : 0, c.writeMode.code,
        ]);
      case 4010:
        return _ok(cmd, [_slot.mf1Config.gen1a ? 1 : 0]);
      case 4011:
        _slot.mf1Config = _slot.mf1Config.copyWith(gen1a: r.u8() != 0);
        return _ok(cmd);
      case 4012:
        return _ok(cmd, [_slot.mf1Config.gen2 ? 1 : 0]);
      case 4013:
        _slot.mf1Config = _slot.mf1Config.copyWith(gen2: r.u8() != 0);
        return _ok(cmd);
      case 4014:
        return _ok(cmd, [_slot.mf1Config.blockAntiColl ? 1 : 0]);
      case 4015:
        _slot.mf1Config = _slot.mf1Config.copyWith(blockAntiColl: r.u8() != 0);
        return _ok(cmd);
      case 4016:
        return _ok(cmd, [_slot.mf1Config.writeMode.code]);
      case 4017:
        _slot.mf1Config = _slot.mf1Config.copyWith(writeMode: Mf1WriteMode.fromCode(r.u8()));
        return _ok(cmd);
      case 4018:
        final t = _slot.antiColl;
        return _ok(cmd, _antiCollBytes(t.uid, t.atqa, t.sak, t.ats));
      case 4019:
        return _ok(cmd, [_slot.uidMagic ? 1 : 0]);
      case 4020:
        _slot.uidMagic = r.u8() != 0;
        return _ok(cmd);
      case 4021:
        final page = r.u8();
        final count = r.u8();
        return _ok(cmd, _slot.ntagPages.sublist(page * 4, (page + count) * 4));
      case 4022:
        final page = r.u8();
        final count = r.u8();
        final data = r.bytes(count * 4);
        _slot.ntagPages.setRange(page * 4, page * 4 + data.length, data);
        return _ok(cmd);
      case 4030:
        return _ok(cmd, [_slot.ntagPageCount]);

      // LF emulator
      case >= 5000 && <= 5013:
        final setId = cmd.isEven ? cmd : cmd - 1;
        final len = emuLfIdLengths[setId];
        if (len == null) return _status(cmd, Status.notImplemented);
        if (cmd.isEven) {
          _slot.lfIds[setId] = r.bytes(len);
          return _ok(cmd);
        }
        return _ok(cmd, _slot.lfIds[setId]!);

      default:
        return _status(cmd, Status.notImplemented);
    }
  }

  Frame? _mf1Auth(int cmd, ByteReader r) {
    final c = hfCard;
    final type = KeyType.fromCode(r.u8());
    final block = r.u8();
    final key = r.bytes(6);
    if (c is! FakeMf1Card) return _status(cmd, Status.hfTagNo);
    if (!c.authenticates(block, type, key)) return _status(cmd, Status.mfErrAuth);
    return null;
  }

  int _slotIndex(int i) {
    if (i < 0 || i > 7) throw const MalformedResponse('slot out of range');
    return i;
  }

  static Uint8List _antiCollBytes(Uint8List uid, Uint8List atqa, int sak, Uint8List ats) =>
      ByteWriter().u8(uid.length).bytes(uid).bytes(atqa).u8(sak).u8(ats.length).bytes(ats).toBytes();

  static List<int> _hexToBytes(String hex) => [
        for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
      ];
}
```

- [ ] **Step 5: Run to verify pass**

Run: `mise x -- dart test test/fake`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): add FakeFirmware answering device, reader and emulator commands

Configurable as Ultra or Lite and across the firmware version matrix so
handshake skew is tested (spec 4.4)."
```

---

### Task 11: FakeDevice transport and FakeScanner

**Files:**
- Create: `lib/src/fake/fake_device.dart`, `lib/src/fake/fake_scanner.dart`, `test/fake/fake_device_test.dart`

**Interfaces:**
- Produces:

```dart
final class FakeDevice implements Transport {
  FakeDevice({FakeFirmware? firmware, Duration latency = Duration.zero, int chunkSize = 20, TransportError? openError});
  final FakeFirmware firmware; List<Frame> get received;
  void dropNextResponse(); void delayNextResponse(Duration d); void corruptNextResponse(); Future<void> simulateLinkLoss();
}
final class FakeScanner implements DeviceScanner { FakeScanner({List<DiscoveredDevice>? devices}); static const emulatedUltra = DiscoveredDevice(...); }
```

- [ ] **Step 1: Write the failing tests**

```dart
// test/fake/fake_device_test.dart
import 'dart:async';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/codec/frame_decoder.dart';
import 'package:chameleon/src/commands/device.dart';
import 'package:chameleon/src/fake/fake_device.dart';
import 'package:chameleon/src/fake/fake_scanner.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/transport/transport.dart';
import 'package:test/test.dart';

Future<Frame> roundTrip(FakeDevice d, Frame req) async {
  final decoder = FrameDecoder();
  final done = Completer<Frame>();
  final sub = d.incoming.listen((chunk) {
    for (final f in decoder.feed(chunk)) {
      if (!done.isCompleted) done.complete(f);
    }
  });
  await d.write(req.encode());
  final f = await done.future.timeout(const Duration(seconds: 1));
  await sub.cancel();
  return f;
}

void main() {
  test('opens, answers in chunks, closes', () async {
    final d = FakeDevice(chunkSize: 3);
    final chunks = <int>[];
    d.incoming.listen((c) => chunks.add(c.length));
    await d.open();
    expect(d.currentState, isA<TransportOpen>());
    final resp = await roundTrip(d, const GetAppVersion().toFrame());
    expect(resp.command, 1000);
    expect(chunks.every((n) => n <= 3), isTrue);
    await d.close();
    expect(d.currentState, isA<TransportClosed>());
  });

  test('write before open throws Disconnected', () async {
    final d = FakeDevice();
    expect(() => d.write(const GetAppVersion().toFrame().encode()), throwsA(isA<Disconnected>()));
  });

  test('open can fail with a transport error', () async {
    final d = FakeDevice(openError: const PermissionDenied());
    expect(d.open(), throwsA(isA<PermissionDenied>()));
  });

  test('dropNextResponse swallows exactly one response', () async {
    final d = FakeDevice();
    await d.open();
    d.dropNextResponse();
    await d.write(const GetAppVersion().toFrame().encode());
    expect(d.received.length, 1);
    final resp = await roundTrip(d, const GetActiveSlot().toFrame());
    expect(resp.command, 1018);
  });

  test('ENTER_BOOTLOADER causes link loss', () async {
    final d = FakeDevice();
    await d.open();
    final states = <TransportState>[];
    d.state.listen(states.add);
    await d.write(const EnterBootloader().toFrame().encode());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(states.last, isA<TransportClosed>().having((s) => s.cause, 'cause', CloseCause.linkLost));
    expect(d.firmware.bootloaderRequested, isTrue);
  });

  test('simulateLinkLoss closes with linkLost', () async {
    final d = FakeDevice();
    await d.open();
    await d.simulateLinkLoss();
    expect((d.currentState as TransportClosed).cause, CloseCause.linkLost);
  });

  test('FakeScanner lists the emulated Ultra once', () async {
    final lists = await FakeScanner().scan().toList();
    expect(lists.single, [FakeScanner.emulatedUltra]);
    expect(FakeScanner.emulatedUltra.kind, TransportKind.fake);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/fake/fake_device_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/src/fake/fake_device.dart
import 'dart:async';
import 'dart:typed_data';

import '../codec/frame.dart';
import '../codec/frame_decoder.dart';
import '../protocol/errors.dart';
import '../transport/transport.dart';
import 'fake_firmware.dart';

/// A Transport around FakeFirmware that fragments responses, adds latency
/// and can misbehave on demand. The only fake in the SDK.
final class FakeDevice implements Transport {
  FakeDevice({
    FakeFirmware? firmware,
    this.latency = Duration.zero,
    this.chunkSize = 20,
    this.openError,
  }) : firmware = firmware ?? FakeFirmware();

  final FakeFirmware firmware;
  Duration latency;
  int chunkSize;
  TransportError? openError;

  final FrameDecoder _decoder = FrameDecoder();
  final StreamController<Uint8List> _incoming = StreamController.broadcast();
  final StreamController<TransportState> _state = StreamController.broadcast();
  final List<Frame> _received = [];
  TransportState _current = const TransportClosed(CloseCause.requested);
  Future<void> _outbound = Future.value();
  int _dropNext = 0;
  Duration? _delayNext;
  bool _corruptNext = false;

  List<Frame> get received => List.unmodifiable(_received);

  @override
  TransportKind get kind => TransportKind.fake;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Stream<TransportState> get state => _state.stream;

  @override
  TransportState get currentState => _current;

  void dropNextResponse() => _dropNext++;

  void delayNextResponse(Duration d) => _delayNext = d;

  void corruptNextResponse() => _corruptNext = true;

  Future<void> simulateLinkLoss() async => _setState(const TransportClosed(CloseCause.linkLost));

  @override
  Future<void> open() async {
    _setState(const TransportOpening());
    await Future<void>.delayed(latency);
    final err = openError;
    if (err != null) {
      _setState(TransportClosed(CloseCause.linkLost, error: err));
      throw err;
    }
    _setState(const TransportOpen());
  }

  @override
  Future<void> close() async {
    if (_current is TransportOpen) {
      _setState(const TransportClosed(CloseCause.requested));
    }
  }

  @override
  Future<void> write(Uint8List bytes) async {
    if (_current is! TransportOpen) throw const Disconnected('fake device not open');
    for (final frame in _decoder.feed(bytes)) {
      _received.add(frame);
      final response = firmware.handle(frame);
      if (firmware.bootloaderRequested) {
        _outbound = _outbound.then((_) async {
          await Future<void>.delayed(latency);
          _setState(const TransportClosed(CloseCause.linkLost));
        });
        return;
      }
      if (response == null) continue;
      if (_dropNext > 0) {
        _dropNext--;
        continue;
      }
      final delay = _delayNext ?? latency;
      _delayNext = null;
      var encoded = response.encode();
      if (_corruptNext) {
        _corruptNext = false;
        encoded = Uint8List.fromList(encoded)..[encoded.length - 1] ^= 0xFF;
      }
      _outbound = _outbound.then((_) async {
        await Future<void>.delayed(delay);
        if (_current is! TransportOpen) return;
        for (var i = 0; i < encoded.length; i += chunkSize) {
          final end = i + chunkSize > encoded.length ? encoded.length : i + chunkSize;
          _incoming.add(Uint8List.sublistView(encoded, i, end));
        }
      });
    }
  }

  void _setState(TransportState s) {
    _current = s;
    _state.add(s);
  }
}
```

```dart
// lib/src/fake/fake_scanner.dart
import '../transport/scanner.dart';
import '../transport/transport.dart';

final class FakeScanner implements DeviceScanner {
  FakeScanner({List<DiscoveredDevice>? devices}) : devices = devices ?? const [emulatedUltra];

  static const DiscoveredDevice emulatedUltra = DiscoveredDevice(
    name: 'Emulated Chameleon Ultra',
    kind: TransportKind.fake,
    transportId: 'fake-ultra',
  );

  static const DiscoveredDevice emulatedBootloader = DiscoveredDevice(
    name: 'CU',
    kind: TransportKind.fake,
    transportId: 'fake-bootloader',
    isBootloader: true,
  );

  final List<DiscoveredDevice> devices;

  @override
  TransportKind get kind => TransportKind.fake;

  @override
  Stream<List<DiscoveredDevice>> scan() => Stream.value(List.unmodifiable(devices));
}
```

- [ ] **Step 4: Run to verify pass**

Run: `mise x -- dart test test/fake`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): add FakeDevice transport and FakeScanner"
```

---

### Task 12: CancelToken and CommandDispatcher

**Files:**
- Create: `lib/src/session/cancel_token.dart`, `lib/src/session/dispatcher.dart`, `test/session/dispatcher_test.dart`

**Interfaces:**
- Produces:

```dart
final class CancelToken { bool get isCancelled; void cancel(); void onCancel(void Function() f); }
final class CommandDispatcher {
  CommandDispatcher(Transport transport, {FrameLog? log, void Function(DecodeDiagnostic)? onDiagnostic});
  Future<Frame?> send(Frame request, {required Duration timeout, bool expectsResponse = true, CancelToken? cancel});
  bool get isIdle; Stream<Frame> get unexpectedFrames; Future<void> dispose();
}
```

- [ ] **Step 1: Write the failing tests**

```dart
// test/session/dispatcher_test.dart
import 'dart:async';

import 'package:chameleon/src/commands/device.dart';
import 'package:chameleon/src/fake/fake_device.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/session/cancel_token.dart';
import 'package:chameleon/src/session/dispatcher.dart';
import 'package:chameleon/src/transport/frame_log.dart';
import 'package:test/test.dart';

const short = Duration(milliseconds: 40);

void main() {
  late FakeDevice device;
  late CommandDispatcher dispatcher;

  setUp(() async {
    device = FakeDevice();
    await device.open();
    dispatcher = CommandDispatcher(device);
  });

  tearDown(() => dispatcher.dispose());

  test('sends and receives one response', () async {
    final f = await dispatcher.send(const GetAppVersion().toFrame(), timeout: short);
    expect(const GetAppVersion().parseResponse(f!).label, '2.2');
  });

  test('serializes concurrent sends in order', () async {
    final results = await Future.wait([
      dispatcher.send(const GetAppVersion().toFrame(), timeout: short),
      dispatcher.send(const GetActiveSlot().toFrame(), timeout: short),
      dispatcher.send(const GetDeviceModel().toFrame(), timeout: short),
    ]);
    expect(results.map((f) => f!.command), [1000, 1018, 1033]);
    expect(device.received.map((f) => f.command), [1000, 1018, 1033]);
  });

  test('times out when the response is dropped', () async {
    device.dropNextResponse();
    await expectLater(
      dispatcher.send(const GetAppVersion().toFrame(), timeout: short),
      throwsA(isA<CommandTimeout>()),
    );
  });

  test('a late response is drained, not matched to the next command', () async {
    device.delayNextResponse(const Duration(milliseconds: 60));
    await expectLater(
      dispatcher.send(const GetActiveSlot().toFrame(), timeout: short),
      throwsA(isA<CommandTimeout>()),
    );
    device.firmware.activeSlot = 5;
    final f = await dispatcher.send(const GetActiveSlot().toFrame(), timeout: const Duration(seconds: 1));
    expect(const GetActiveSlot().parseResponse(f!), 5);
  });

  test('nothing is dispatched while draining', () async {
    device.dropNextResponse();
    final first = dispatcher.send(const GetAppVersion().toFrame(), timeout: short);
    final second = dispatcher.send(const GetActiveSlot().toFrame(), timeout: const Duration(seconds: 1));
    await expectLater(first, throwsA(isA<CommandTimeout>()));
    expect(device.received.length, 1);
    await second;
    expect(device.received.length, 2);
  });

  test('cancelling a queued command rejects it without sending', () async {
    device.delayNextResponse(const Duration(milliseconds: 30));
    final first = dispatcher.send(const GetAppVersion().toFrame(), timeout: const Duration(seconds: 1));
    final token = CancelToken();
    final second = dispatcher.send(const GetActiveSlot().toFrame(), timeout: short, cancel: token);
    token.cancel();
    await expectLater(second, throwsA(isA<CommandCancelled>()));
    await first;
    expect(device.received.map((f) => f.command), [1000]);
  });

  test('cancelling the in-flight command drains before the next send', () async {
    device.delayNextResponse(const Duration(milliseconds: 60));
    final token = CancelToken();
    final first = dispatcher.send(const GetAppVersion().toFrame(), timeout: const Duration(seconds: 1), cancel: token);
    token.cancel();
    await expectLater(first, throwsA(isA<CommandCancelled>()));
    final f = await dispatcher.send(const GetActiveSlot().toFrame(), timeout: const Duration(seconds: 1));
    expect(f!.command, 1018);
  });

  test('no-response commands complete with null immediately', () async {
    final f = await dispatcher.send(const EnterBootloader().toFrame(), timeout: short, expectsResponse: false);
    expect(f, isNull);
  });

  test('link loss fails pending commands and later sends', () async {
    device.dropNextResponse();
    final pending = dispatcher.send(const GetAppVersion().toFrame(), timeout: const Duration(seconds: 5));
    await device.simulateLinkLoss();
    await expectLater(pending, throwsA(isA<Disconnected>()));
    await expectLater(
      dispatcher.send(const GetActiveSlot().toFrame(), timeout: short),
      throwsA(isA<Disconnected>()),
    );
  });

  test('records both directions in the frame log', () async {
    final log = FrameLog();
    final d = CommandDispatcher(device, log: log);
    await d.send(const GetAppVersion().toFrame(), timeout: short);
    expect(log.entries.map((e) => e.direction), [FrameDirection.sent, FrameDirection.received]);
    await d.dispose();
  });

  test('frames for no pending command go to unexpectedFrames', () async {
    final seen = <int>[];
    dispatcher.unexpectedFrames.listen((f) => seen.add(f.command));
    await device.write(const GetActiveSlot().toFrame().encode());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(seen, [1018]);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/session/dispatcher_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/src/session/cancel_token.dart
final class CancelToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final l in List.of(_listeners)) {
      l();
    }
    _listeners.clear();
  }

  void onCancel(void Function() f) {
    if (_cancelled) {
      f();
    } else {
      _listeners.add(f);
    }
  }
}
```

```dart
// lib/src/session/dispatcher.dart
import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../codec/frame.dart';
import '../codec/frame_decoder.dart';
import '../protocol/errors.dart';
import '../transport/frame_log.dart';
import '../transport/transport.dart';
import 'cancel_token.dart';

final class _Pending {
  _Pending(this.request, this.timeout, this.expectsResponse, this.cancel, this.generation);
  final Frame request;
  final Duration timeout;
  final bool expectsResponse;
  final CancelToken? cancel;
  final int generation;
  final Completer<Frame?> completer = Completer();
  Timer? timer;

  void fail(Object error) {
    timer?.cancel();
    if (!completer.isCompleted) completer.completeError(error);
  }

  void succeed(Frame? f) {
    timer?.cancel();
    if (!completer.isCompleted) completer.complete(f);
  }
}

/// One command in flight, responses matched by command id, timeouts,
/// cancellation and draining (spec 4.3).
final class CommandDispatcher {
  CommandDispatcher(
    this._transport, {
    FrameLog? log,
    void Function(DecodeDiagnostic)? onDiagnostic,
  })  : _log = log,
        _decoder = FrameDecoder(onDiagnostic: onDiagnostic) {
    _incomingSub = _transport.incoming.listen(_onBytes);
    _stateSub = _transport.state.listen(_onState);
  }

  final Transport _transport;
  final FrameLog? _log;
  final FrameDecoder _decoder;
  late final StreamSubscription<Uint8List> _incomingSub;
  late final StreamSubscription<TransportState> _stateSub;
  final Queue<_Pending> _queue = Queue();
  final StreamController<Frame> _unexpected = StreamController.broadcast();
  _Pending? _inFlight;
  _Pending? _draining;
  Timer? _drainTimer;
  int _generation = 0;
  bool _closed = false;

  bool get isIdle => _inFlight == null && _draining == null && _queue.isEmpty;

  Stream<Frame> get unexpectedFrames => _unexpected.stream;

  Future<Frame?> send(
    Frame request, {
    required Duration timeout,
    bool expectsResponse = true,
    CancelToken? cancel,
  }) {
    if (_closed) return Future.error(const Disconnected());
    final p = _Pending(request, timeout, expectsResponse, cancel, ++_generation);
    _queue.addLast(p);
    cancel?.onCancel(() => _cancel(p));
    _pump();
    return p.completer.future;
  }

  Future<void> dispose() async {
    _closed = true;
    _failAll(const Disconnected('dispatcher disposed'));
    await _incomingSub.cancel();
    await _stateSub.cancel();
    await _unexpected.close();
  }

  void _pump() {
    if (_inFlight != null || _draining != null) return;
    while (_queue.isNotEmpty) {
      final p = _queue.removeFirst();
      if (p.cancel?.isCancelled ?? false) {
        p.fail(const CommandCancelled());
        continue;
      }
      _inFlight = p;
      _log?.add(FrameDirection.sent, p.request);
      unawaited(_transport.write(p.request.encode()).then((_) {
        if (_inFlight != p) return;
        if (!p.expectsResponse) {
          _inFlight = null;
          p.succeed(null);
          _pump();
          return;
        }
        p.timer = Timer(p.timeout, () => _timeout(p));
      }, onError: (Object e) {
        if (_inFlight == p) _inFlight = null;
        p.fail(e is ChameleonException ? e : Disconnected(e.toString()));
        _pump();
      }));
      return;
    }
  }

  void _timeout(_Pending p) {
    if (_inFlight != p) return;
    _inFlight = null;
    _startDrain(p);
    p.fail(CommandTimeout(p.request.command, p.timeout));
  }

  void _cancel(_Pending p) {
    if (_inFlight == p) {
      _inFlight = null;
      _startDrain(p);
      p.fail(const CommandCancelled());
      return;
    }
    if (_queue.remove(p)) {
      p.fail(const CommandCancelled());
    }
  }

  void _startDrain(_Pending p) {
    _draining = p;
    _drainTimer = Timer(p.timeout, _endDrain);
  }

  void _endDrain() {
    _drainTimer?.cancel();
    _drainTimer = null;
    _draining = null;
    _pump();
  }

  void _onBytes(Uint8List chunk) {
    for (final frame in _decoder.feed(chunk)) {
      _log?.add(FrameDirection.received, frame);
      final p = _inFlight;
      if (p != null && frame.command == p.request.command) {
        _inFlight = null;
        p.succeed(frame);
        _pump();
        continue;
      }
      final d = _draining;
      if (d != null && frame.command == d.request.command) {
        _endDrain();
        continue;
      }
      _unexpected.add(frame);
    }
  }

  void _onState(TransportState s) {
    if (s is TransportClosed) {
      _closed = true;
      _failAll(Disconnected(s.error?.message ?? 'transport closed (${s.cause.name})'));
    }
  }

  void _failAll(ChameleonException error) {
    _drainTimer?.cancel();
    _draining = null;
    final inFlight = _inFlight;
    _inFlight = null;
    inFlight?.fail(error);
    while (_queue.isNotEmpty) {
      _queue.removeFirst().fail(error);
    }
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `mise x -- dart test test/session/dispatcher_test.dart`
Expected: all pass. The late-response test relies on the drain window (timeout plus timeout, 80 ms) outlasting the delayed response (60 ms); keep that relationship if you tune the numbers.

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): add CommandDispatcher with timeouts, cancellation and draining

Late responses to abandoned commands are consumed by the drain, never
matched to a fresh command with the same id (spec 4.3)."
```

---

### Task 13: Session state machine and handshake

**Files:**
- Create: `lib/src/session/state_stream.dart`, `lib/src/session/connection_state.dart`, `lib/src/session/device_session.dart`, `test/session/state_stream_test.dart`, `test/session/device_session_test.dart`
- Modify: `lib/src/protocol/errors.dart` (add `ReaderUnavailable`)

**Interfaces:**
- Produces:

```dart
final class StateStream<T> { StateStream(T initial); T get value; Stream<T> get changes; Stream<T> get values /* current then changes */; void set(T); Future<void> close(); }
enum DisconnectCause { requested, expected, unexpected }
sealed class ConnectionState; SessionConnecting; SessionReady(DeviceInfo info); SessionLimited(UnsupportedReason reason, {FirmwareVersion? version}); SessionUpdating; SessionDisconnected(DisconnectCause cause, {ChameleonException? error})
final class DeviceSession {
  DeviceSession(Transport transport, {Duration idlePollInterval = 3s, Duration batteryDelay = 5s, FrameLog? frameLog});
  static const int supportedMajor = 2;
  Transport get transport; FrameLog get frameLog;
  StateStream<ConnectionState> get connectionState;
  StateStream<DeviceInfo?> get deviceInfo; StateStream<List<Slot>> get slotsState; StateStream<int?> get activeSlot;
  StateStream<DeviceSettings?> get settingsState; StateStream<BatteryInfo?> get battery; StateStream<DeviceMode?> get mode;
  Stream<ChameleonException> get backgroundErrors;
  Future<void> open(); Future<void> close();
  @internal Future<R> send<R>(Command<R> c, {CancelToken? cancel, bool allowLimited = false});
}
```

(Facades, lease and polling are added in the next tasks; this task lands the skeleton with the handshake and state transitions.)

- [ ] **Step 1: Write the failing tests**

```dart
// test/session/state_stream_test.dart
import 'package:chameleon/src/session/state_stream.dart';
import 'package:test/test.dart';

void main() {
  test('values emits current then changes', () async {
    final s = StateStream<int>(1);
    final got = <int>[];
    final sub = s.values.listen(got.add);
    await Future<void>.delayed(Duration.zero);
    s.set(2);
    s.set(3);
    await Future<void>.delayed(Duration.zero);
    expect(got, [1, 2, 3]);
    expect(s.value, 3);
    await sub.cancel();
    await s.close();
  });
}
```

```dart
// test/session/device_session_test.dart
import 'package:chameleon/src/commands/device.dart';
import 'package:chameleon/src/fake/fake_device.dart';
import 'package:chameleon/src/fake/fake_firmware.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/model/models.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/session/connection_state.dart';
import 'package:chameleon/src/session/device_session.dart';
import 'package:test/test.dart';

DeviceSession sessionFor(FakeFirmwareConfig config, {FakeDevice? device}) => DeviceSession(
      device ?? FakeDevice(firmware: FakeFirmware(config)),
      idlePollInterval: const Duration(days: 1),
      batteryDelay: Duration.zero,
    );

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test('reaches ready on a 2.2 Ultra with only three handshake commands', () async {
    final device = FakeDevice();
    final s = sessionFor(FakeFirmwareConfig.ultra22(), device: device);
    final states = <ConnectionState>[];
    s.connectionState.changes.listen(states.add);
    await s.open();
    expect(s.connectionState.value, isA<SessionReady>());
    expect(device.received.take(3).map((f) => f.command), [1035, 1000, 1033]);
    expect(states.first, isA<SessionConnecting>());
    expect(s.deviceInfo.value!.model, DeviceModel.ultra);
    await s.close();
    expect(s.connectionState.value,
        isA<SessionDisconnected>().having((d) => d.cause, 'cause', DisconnectCause.requested));
  });

  test('loads identity, mode, slots, settings and battery in the background', () async {
    final s = sessionFor(FakeFirmwareConfig.ultra22());
    await s.open();
    await settle();
    expect(s.deviceInfo.value!.identity!.chipId, '0102030405060708');
    expect(s.deviceInfo.value!.gitVersion, 'v2.2.0-fake');
    expect(s.mode.value, DeviceMode.emulator);
    expect(s.slotsState.value.length, 8);
    expect(s.slotsState.value[0].hfNick, 'Fake 1K');
    expect(s.settingsState.value!.blePairingKey, '123456');
    expect(s.battery.value!.percent, 92);
    await s.close();
  });

  test('2.0 firmware without GET_ALL_SLOT_NICKS still loads nicknames', () async {
    final s = sessionFor(FakeFirmwareConfig.ultra20());
    await s.open();
    await settle();
    expect(s.connectionState.value, isA<SessionReady>());
    expect(s.slotsState.value[0].hfNick, 'Fake 1K');
    expect(s.settingsState.value!.sleepTimeoutSeconds, isNull);
    await s.close();
  });

  test('pre-2.0 firmware lands in limited(preTwoPointZero)', () async {
    final s = sessionFor(FakeFirmwareConfig.preTwoPointZero());
    await s.open();
    expect(s.connectionState.value,
        isA<SessionLimited>().having((l) => l.reason, 'reason', UnsupportedReason.preTwoPointZero));
    await s.close();
  });

  test('legacy 0.1 lands in limited(legacyMustUpdate)', () async {
    final s = sessionFor(FakeFirmwareConfig.legacy01());
    await s.open();
    expect((s.connectionState.value as SessionLimited).reason, UnsupportedReason.legacyMustUpdate);
    await s.close();
  });

  test('a newer major lands in limited(newerMajor)', () async {
    final s = sessionFor(FakeFirmwareConfig(version: const FirmwareVersion(major: 3, minor: 0)));
    await s.open();
    expect((s.connectionState.value as SessionLimited).reason, UnsupportedReason.newerMajor);
    await s.close();
  });

  test('limited sessions refuse ordinary commands but allow ENTER_BOOTLOADER', () async {
    final device = FakeDevice(firmware: FakeFirmware(FakeFirmwareConfig.preTwoPointZero()));
    final s = sessionFor(FakeFirmwareConfig.preTwoPointZero(), device: device);
    await s.open();
    expect(() => s.send(const GetActiveSlot()), throwsA(isA<SessionNotReady>()));
    await s.send(const EnterBootloader(), allowLimited: true);
    expect(device.firmware.bootloaderRequested, isTrue);
  });

  test('background failures surface as errors, not refusals', () async {
    final device = FakeDevice();
    final s = sessionFor(FakeFirmwareConfig.ultra22(), device: device);
    device.firmware.config.effectiveCapabilities.remove(1034);
    final errors = <ChameleonException>[];
    s.backgroundErrors.listen(errors.add);
    await s.open();
    await settle();
    expect(s.connectionState.value, isA<SessionReady>());
    expect(s.settingsState.value, isNull);
    expect(errors.whereType<InvalidCommand>(), isNotEmpty);
    await s.close();
  });

  test('link loss while ready is an unexpected disconnect', () async {
    final device = FakeDevice();
    final s = sessionFor(FakeFirmwareConfig.ultra22(), device: device);
    await s.open();
    await device.simulateLinkLoss();
    await settle();
    expect((s.connectionState.value as SessionDisconnected).cause, DisconnectCause.unexpected);
  });

  test('transport open failure is reported and rethrown', () async {
    final device = FakeDevice(openError: const PermissionDenied());
    final s = sessionFor(FakeFirmwareConfig.ultra22(), device: device);
    await expectLater(s.open(), throwsA(isA<PermissionDenied>()));
    expect((s.connectionState.value as SessionDisconnected).error, isA<PermissionDenied>());
  });

  test('idempotent commands retry once on timeout', () async {
    final device = FakeDevice();
    final s = sessionFor(FakeFirmwareConfig.ultra22(), device: device);
    await s.open();
    await settle();
    device.dropNextResponse();
    final v = await s.send(const GetAppVersion());
    expect(v.label, '2.2');
    await s.close();
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/session`
Expected: FAIL on the new files.

- [ ] **Step 3: Implement**

Add to `lib/src/protocol/errors.dart`:

```dart
final class ReaderUnavailable extends ChameleonException {
  const ReaderUnavailable() : super('this device has no reader');
}
```

```dart
// lib/src/session/state_stream.dart
import 'dart:async';

/// A current value plus a broadcast stream of changes.
final class StateStream<T> {
  StateStream(this._value);

  T _value;
  final StreamController<T> _changes = StreamController.broadcast();

  T get value => _value;

  Stream<T> get changes => _changes.stream;

  /// The current value first, then every change.
  Stream<T> get values {
    late StreamController<T> out;
    StreamSubscription<T>? sub;
    out = StreamController<T>(
      onListen: () {
        out.add(_value);
        sub = _changes.stream.listen(out.add, onDone: out.close);
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  void set(T v) {
    _value = v;
    if (!_changes.isClosed) _changes.add(v);
  }

  Future<void> close() => _changes.close();
}
```

```dart
// lib/src/session/connection_state.dart
import '../model/models.dart';
import '../protocol/errors.dart';

enum DisconnectCause { requested, expected, unexpected }

sealed class ConnectionState {
  const ConnectionState();
}

final class SessionConnecting extends ConnectionState {
  const SessionConnecting();
}

final class SessionReady extends ConnectionState {
  const SessionReady(this.info);
  final DeviceInfo info;
}

/// Transport open, firmware unsupported. Only ENTER_BOOTLOADER is allowed.
final class SessionLimited extends ConnectionState {
  const SessionLimited(this.reason, {this.version});
  final UnsupportedReason reason;
  final FirmwareVersion? version;
}

/// ENTER_BOOTLOADER was sent on purpose; the coming close is expected.
final class SessionUpdating extends ConnectionState {
  const SessionUpdating();
}

final class SessionDisconnected extends ConnectionState {
  const SessionDisconnected(this.cause, {this.error});
  final DisconnectCause cause;
  final ChameleonException? error;
}
```

```dart
// lib/src/session/device_session.dart
import 'dart:async';

import 'package:meta/meta.dart';

import '../commands/device.dart';
import '../model/enums.dart';
import '../model/models.dart';
import '../protocol/command.dart';
import '../protocol/errors.dart';
import '../transport/frame_log.dart';
import '../transport/transport.dart';
import 'cancel_token.dart';
import 'connection_state.dart';
import 'dispatcher.dart';
import 'state_stream.dart';

/// Owns one connection: handshake, state machine, cached device state.
final class DeviceSession {
  DeviceSession(
    this.transport, {
    this.idlePollInterval = const Duration(seconds: 3),
    this.batteryDelay = const Duration(seconds: 5),
    FrameLog? frameLog,
  }) : frameLog = frameLog ?? FrameLog();

  static const int supportedMajor = 2;

  final Transport transport;
  final FrameLog frameLog;
  final Duration idlePollInterval;
  final Duration batteryDelay;

  final StateStream<ConnectionState> connectionState =
      StateStream(const SessionDisconnected(DisconnectCause.requested));
  final StateStream<DeviceInfo?> deviceInfo = StateStream(null);
  final StateStream<List<Slot>> slotsState = StateStream(const []);
  final StateStream<int?> activeSlot = StateStream(null);
  final StateStream<DeviceSettings?> settingsState = StateStream(null);
  final StateStream<BatteryInfo?> battery = StateStream(null);
  final StateStream<DeviceMode?> mode = StateStream(null);

  final StreamController<ChameleonException> _backgroundErrors = StreamController.broadcast();
  Stream<ChameleonException> get backgroundErrors => _backgroundErrors.stream;

  CommandDispatcher? _dispatcher;
  StreamSubscription<TransportState>? _transportSub;
  DateTime? _readyAt;

  // Hooks filled in by later tasks (lease, polling, facades).
  int _busy = 0;
  Timer? _pollTimer;

  bool get isReady => connectionState.value is SessionReady;

  DeviceInfo get _requireInfo {
    final i = deviceInfo.value;
    if (i == null) throw const SessionNotReady('no device info');
    return i;
  }

  Future<void> open() async {
    connectionState.set(const SessionConnecting());
    _transportSub = transport.state.listen(_onTransportState);
    _dispatcher = CommandDispatcher(transport, log: frameLog);
    try {
      await transport.open();
    } on ChameleonException catch (e) {
      connectionState.set(SessionDisconnected(DisconnectCause.unexpected, error: e));
      rethrow;
    }
    try {
      await _handshake();
    } on ChameleonException catch (e) {
      connectionState.set(SessionDisconnected(DisconnectCause.unexpected, error: e));
      await transport.close();
      rethrow;
    }
  }

  Future<void> _handshake() async {
    final Capabilities caps;
    try {
      caps = await _dispatch(const GetDeviceCapabilities());
    } on DeviceError {
      connectionState.set(const SessionLimited(UnsupportedReason.preTwoPointZero));
      return;
    } on CommandTimeout {
      connectionState.set(const SessionLimited(UnsupportedReason.preTwoPointZero));
      return;
    }
    final version = await _dispatch(const GetAppVersion());
    if (version.isLegacy) {
      connectionState.set(SessionLimited(UnsupportedReason.legacyMustUpdate, version: version));
      return;
    }
    if (version.major > supportedMajor) {
      connectionState.set(SessionLimited(UnsupportedReason.newerMajor, version: version));
      return;
    }
    final model = await _dispatch(const GetDeviceModel());
    final info = DeviceInfo(model: model, version: version, capabilities: caps);
    deviceInfo.set(info);
    _readyAt = DateTime.now();
    connectionState.set(SessionReady(info));
    unawaited(_loadBackground());
    _startPolling();
  }

  Future<void> _loadBackground() async {
    await _background(() async {
      final git = await send(const GetGitVersion());
      final chip = await send(const GetDeviceChipId());
      final addr = await send(const GetDeviceAddress());
      deviceInfo.set(_requireInfo.copyWith(
        gitVersion: git,
        identity: DeviceIdentity(chip),
        bleAddress: addr,
      ));
    });
    await _background(() async => mode.set(await send(const GetDeviceMode())));
    await _background(refreshSlots);
    await _background(() async => settingsState.set(await send(const GetDeviceSettings())));
    await _background(() async {
      final wait = batteryDelay - DateTime.now().difference(_readyAt!);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      if (!isReady) return;
      battery.set(await send(const GetBatteryInfo()));
    });
  }

  Future<void> _background(Future<void> Function() body) async {
    if (!isReady) return;
    try {
      await body();
    } on ChameleonException catch (e) {
      _backgroundErrors.add(e);
    }
  }

  /// Reloads the slot cache from the device (1018, 1019, 1023, nicknames).
  Future<List<Slot>> refreshSlots() async {
    final caps = _requireInfo.capabilities;
    final active = await send(const GetActiveSlot());
    final types = await send(const GetSlotInfo());
    final enabled = await send(const GetEnabledSlots());
    final List<SlotNicks> nicks;
    if (caps.supports(1038)) {
      nicks = await send(const GetAllSlotNicks());
    } else {
      nicks = [];
      for (var i = 0; i < 8; i++) {
        final hf = await _nickOrEmpty(i, Sense.hf);
        final lf = await _nickOrEmpty(i, Sense.lf);
        nicks.add(SlotNicks(hf, lf));
      }
    }
    final list = List.generate(
      8,
      (i) => Slot(
        index: i,
        hfType: types[i].hf,
        lfType: types[i].lf,
        hfEnabled: enabled[i].hf,
        lfEnabled: enabled[i].lf,
        hfNick: nicks[i].hf,
        lfNick: nicks[i].lf,
      ),
    );
    activeSlot.set(active);
    slotsState.set(list);
    return list;
  }

  Future<String> _nickOrEmpty(int slot, Sense sense) async {
    try {
      return await send(GetSlotTagNick(slot, sense));
    } on DeviceError {
      return '';
    }
  }

  /// Sends a command. Internal to the SDK; app code uses facades.
  @internal
  Future<R> send<R>(Command<R> command, {CancelToken? cancel, bool allowLimited = false}) async {
    final state = connectionState.value;
    final ok = state is SessionReady ||
        state is SessionUpdating ||
        (allowLimited && state is SessionLimited);
    if (!ok) throw SessionNotReady('session is ${state.runtimeType}');
    try {
      return await _dispatch(command, cancel: cancel);
    } on CommandTimeout {
      if (!command.idempotent) rethrow;
      return _dispatch(command, cancel: cancel);
    }
  }

  Future<R> _dispatch<R>(Command<R> command, {CancelToken? cancel}) async {
    final d = _dispatcher;
    if (d == null) throw const Disconnected();
    final frame = await d.send(
      command.toFrame(),
      timeout: command.timeout,
      expectsResponse: command.expectsResponse,
      cancel: cancel,
    );
    if (frame == null) return null as R;
    return command.parseResponse(frame);
  }

  Future<void> close() async {
    _stopPolling();
    await transport.close();
    if (connectionState.value is! SessionDisconnected) {
      connectionState.set(const SessionDisconnected(DisconnectCause.requested));
    }
    await _teardown();
  }

  void _onTransportState(TransportState s) {
    if (s is! TransportClosed) return;
    final current = connectionState.value;
    final cause = switch (s.cause) {
      CloseCause.requested => DisconnectCause.requested,
      CloseCause.linkLost =>
        current is SessionUpdating ? DisconnectCause.expected : DisconnectCause.unexpected,
    };
    if (current is! SessionDisconnected) {
      connectionState.set(SessionDisconnected(cause, error: s.error));
    }
    _stopPolling();
    unawaited(_teardown());
  }

  Future<void> _teardown() async {
    await _transportSub?.cancel();
    _transportSub = null;
    final d = _dispatcher;
    _dispatcher = null;
    await d?.dispose();
  }

  void _startPolling() {}
  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}
```

`_busy` and `_startPolling` are placeholders that Task 14 fills; leaving them empty here keeps this task's tests focused on the handshake. `null as R` for no-response commands is safe because every such command is a `VoidCommand`.

- [ ] **Step 4: Run to verify pass**

Run: `mise x -- dart test test/session`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): add DeviceSession with minimal handshake and state machine

Only capabilities, version and model gate readiness; everything else
loads in the background and fails soft (spec 4.3)."
```

---

### Task 14: Reader lease, idle poll and busy tracking

**Files:**
- Create: `lib/src/session/reader_lease.dart`, `test/session/lease_and_poll_test.dart`
- Modify: `lib/src/session/device_session.dart`

**Interfaces:**
- Produces on `DeviceSession`: `Future<ReaderLease> acquireReaderMode()`, `Future<T> withReaderMode<T>(Future<T> Function() body)`, `Future<T> busy<T>(Future<T> Function() body)`, `int get readerLeaseCount`, `bool get isBusy`; `final class ReaderLease { Future<void> release(); bool get isReleased; }`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/session/lease_and_poll_test.dart
import 'package:chameleon/src/commands/device.dart';
import 'package:chameleon/src/fake/fake_device.dart';
import 'package:chameleon/src/fake/fake_firmware.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/model/models.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/session/device_session.dart';
import 'package:test/test.dart';

Future<void> settle([int ms = 20]) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  test('nested leases switch mode once and restore once', () async {
    final device = FakeDevice();
    final s = DeviceSession(device, idlePollInterval: const Duration(days: 1), batteryDelay: Duration.zero);
    await s.open();
    await settle();
    final before = device.received.length;
    final outer = await s.acquireReaderMode();
    final inner = await s.acquireReaderMode();
    expect(device.firmware.mode, DeviceMode.reader);
    expect(s.readerLeaseCount, 2);
    await inner.release();
    expect(device.firmware.mode, DeviceMode.reader);
    await outer.release();
    expect(device.firmware.mode, DeviceMode.emulator);
    expect(s.mode.value, DeviceMode.emulator);
    final modeChanges = device.received.skip(before).where((f) => f.command == 1001).length;
    expect(modeChanges, 2);
    await s.close();
  });

  test('withReaderMode restores mode when the body throws', () async {
    final device = FakeDevice();
    final s = DeviceSession(device, idlePollInterval: const Duration(days: 1), batteryDelay: Duration.zero);
    await s.open();
    await settle();
    await expectLater(
      s.withReaderMode(() async => throw StateError('boom')),
      throwsStateError,
    );
    expect(device.firmware.mode, DeviceMode.emulator);
    await s.close();
  });

  test('a Lite cannot acquire a reader lease', () async {
    final s = DeviceSession(FakeDevice(firmware: FakeFirmware(FakeFirmwareConfig.lite22())),
        idlePollInterval: const Duration(days: 1), batteryDelay: Duration.zero);
    await s.open();
    await expectLater(s.acquireReaderMode(), throwsA(isA<ReaderUnavailable>()));
    await s.close();
  });

  test('idle poll picks up an active slot changed on the device', () async {
    final device = FakeDevice();
    final s = DeviceSession(device, idlePollInterval: const Duration(milliseconds: 30), batteryDelay: Duration.zero);
    await s.open();
    await settle();
    expect(s.activeSlot.value, 0);
    device.firmware.activeSlot = 4; // as if button A was pressed
    device.firmware.battery = const BatteryInfo(millivolts: 3700, percent: 40);
    await settle(80);
    expect(s.activeSlot.value, 4);
    expect(s.battery.value!.percent, 40);
    await s.close();
  });

  test('idle poll pauses while a lease or busy block is active', () async {
    final device = FakeDevice();
    final s = DeviceSession(device, idlePollInterval: const Duration(milliseconds: 20), batteryDelay: Duration.zero);
    await s.open();
    await settle();
    final lease = await s.acquireReaderMode();
    final n = device.received.length;
    await settle(70);
    expect(device.received.length, n);
    await lease.release();
    await s.busy(() async {
      final m = device.received.length;
      await settle(70);
      expect(device.received.length, m);
    });
    await settle(50);
    expect(device.received.length, greaterThan(n));
    await s.close();
  });

  test('polling stops after close', () async {
    final device = FakeDevice();
    final s = DeviceSession(device, idlePollInterval: const Duration(milliseconds: 20), batteryDelay: Duration.zero);
    await s.open();
    await s.close();
    final n = device.received.length;
    await settle(60);
    expect(device.received.length, n);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/session/lease_and_poll_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/src/session/reader_lease.dart
/// Handle returned by DeviceSession.acquireReaderMode. Release it when the
/// reader operation is done; the last release restores emulator mode.
final class ReaderLease {
  ReaderLease(this._onRelease);
  final Future<void> Function() _onRelease;
  bool _released = false;

  bool get isReleased => _released;

  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _onRelease();
  }
}
```

Add to `DeviceSession` (replace the placeholder members `_busy`, `_pollTimer`, `_startPolling`, `_stopPolling`):

```dart
  int _leases = 0;
  int _busy = 0;
  Timer? _pollTimer;
  bool _polling = false;

  int get readerLeaseCount => _leases;
  bool get isBusy => _busy > 0 || _leases > 0;

  Future<ReaderLease> acquireReaderMode() async {
    if (!_requireInfo.capabilities.hasReader) throw const ReaderUnavailable();
    if (_leases == 0) {
      await send(const ChangeDeviceMode(DeviceMode.reader));
      mode.set(DeviceMode.reader);
    }
    _leases++;
    return ReaderLease(_releaseReader);
  }

  Future<void> _releaseReader() async {
    _leases--;
    if (_leases > 0 || !isReady) return;
    try {
      await send(const ChangeDeviceMode(DeviceMode.emulator));
      mode.set(DeviceMode.emulator);
    } on ChameleonException catch (e) {
      _backgroundErrors.add(e);
    }
  }

  Future<T> withReaderMode<T>(Future<T> Function() body) async {
    final lease = await acquireReaderMode();
    try {
      return await body();
    } finally {
      await lease.release();
    }
  }

  /// Pauses idle polling for the duration of a long operation.
  Future<T> busy<T>(Future<T> Function() body) async {
    _busy++;
    try {
      return await body();
    } finally {
      _busy--;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(idlePollInterval, (_) => unawaited(_pollOnce()));
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollOnce() async {
    if (_polling || !isReady || isBusy || !(_dispatcher?.isIdle ?? false)) return;
    _polling = true;
    try {
      await _background(() async {
        activeSlot.set(await send(const GetActiveSlot()));
        mode.set(await send(const GetDeviceMode()));
        if (DateTime.now().difference(_readyAt!) >= batteryDelay) {
          battery.set(await send(const GetBatteryInfo()));
        }
      });
    } finally {
      _polling = false;
    }
  }
```

Add `import 'reader_lease.dart';` to the session file.

- [ ] **Step 4: Run to verify pass**

Run: `mise x -- dart test test/session`
Expected: all pass. Timing-based tests use generous margins; if one is flaky on CI, double its settle durations rather than weakening the assertion.

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): add reader lease, busy tracking and idle poll

Reader mode is ref-counted so nested operations restore emulator mode
exactly once; the poll keeps active slot, mode and battery fresh."
```

---

### Task 15: Device, slots, settings, emulator and firmware facades

**Files:**
- Create: `lib/src/session/facades/device.dart`, `lib/src/session/facades/slots.dart`, `lib/src/session/facades/settings.dart`, `lib/src/session/facades/emulator.dart`, `lib/src/session/facades/firmware.dart`, `test/session/facades_test.dart`
- Modify: `lib/src/session/device_session.dart` (expose `device`, `slots`, `settings`, `emulator`, `firmware` facade fields)

**Interfaces:**
- Produces:

```dart
final class DeviceFacade { DeviceInfo? get info; Future<BatteryInfo> readBattery(); Future<DeviceMode> readMode(); Future<void> setMode(DeviceMode); Future<DeviceIdentity> readIdentity(); }
final class SlotsFacade { List<Slot> get current; int? get active; Future<List<Slot>> refresh(); Future<void> setActive(int); Future<void> setEnabled(int, Sense, bool); Future<void> rename(int, Sense, String); Future<void> setTagType(int, TagType); Future<void> resetToDefault(int, TagType); Future<void> deleteSense(int, Sense); Future<void> save(); }
final class SettingsFacade { DeviceSettings? get current; Future<DeviceSettings> refresh(); Future<void> setAnimation(AnimationMode); Future<void> setButton(DeviceButton, ButtonFunction, {bool long = false}); Future<void> setBlePairingKey(String); Future<void> setBlePairingEnabled(bool); Future<void> setSleepTimeout(int); Future<void> save(); Future<void> reset(); Future<void> deleteAllBleBonds(); }
final class EmulatorFacade { Future<Uint8List> readMf1Blocks(int start, int count); Future<void> writeMf1Blocks(int start, Uint8List data); Future<Hf14aTag> getAntiColl(); Future<void> setAntiColl(Hf14aTag); Future<Mf1EmulatorConfig> getMf1Config(); Future<void> setMf1WriteMode(Mf1WriteMode); Future<void> setGen1a(bool); Future<void> setGen2(bool); Future<void> setBlockAntiColl(bool); Future<void> setDetectionEnabled(bool); Future<List<DetectionLogEntry>> readDetectionLog(); Future<Uint8List> readNtagPages(int start, int count); Future<void> writeNtagPages(int start, Uint8List data); Future<int> getNtagPageCount(); Future<void> setLfId(TagType, Uint8List); Future<Uint8List> getLfId(TagType); static int? lfSetCommandId(TagType); }
final class FirmwareFacade { Future<void> enterBootloader(); }
```

Every slot mutation ends with `SlotDataConfigSave` so the device never holds unsaved slot state; `save()` exists for callers that batch raw edits. Settings mutations do not auto-save because BLE pairing changes need an explicit save and reboot.

- [ ] **Step 1: Write the failing tests**

```dart
// test/session/facades_test.dart
import 'dart:typed_data';

import 'package:chameleon/src/fake/fake_device.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/model/models.dart';
import 'package:chameleon/src/session/connection_state.dart';
import 'package:chameleon/src/session/device_session.dart';
import 'package:test/test.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakeDevice device;
  late DeviceSession s;

  setUp(() async {
    device = FakeDevice();
    s = DeviceSession(device, idlePollInterval: const Duration(days: 1), batteryDelay: Duration.zero);
    await s.open();
    await settle();
  });

  tearDown(() => s.close());

  test('device facade reads battery and switches mode with write-through', () async {
    expect((await s.device.readBattery()).percent, 92);
    await s.device.setMode(DeviceMode.reader);
    expect(s.mode.value, DeviceMode.reader);
    expect((await s.device.readIdentity()).chipId, '0102030405060708');
  });

  test('slot edits are written through, persisted and reflected in the cache', () async {
    await s.slots.setTagType(2, TagType.ntag216);
    await s.slots.setEnabled(2, Sense.hf, true);
    await s.slots.rename(2, Sense.hf, 'badge');
    await s.slots.setActive(2);
    expect(s.slots.current[2].hfType, TagType.ntag216);
    expect(s.slots.current[2].hfEnabled, isTrue);
    expect(s.slots.current[2].hfNick, 'badge');
    expect(s.slots.active, 2);
    expect(device.firmware.slotsSaved, isTrue);
    expect(device.firmware.slots[2].hfNick, 'badge');
    await s.slots.deleteSense(2, Sense.hf);
    expect(s.slots.current[2].hfType, TagType.undefined);
    final fresh = await s.slots.refresh();
    expect(fresh[2].hfEnabled, isFalse);
  });

  test('resetToDefault clears emulator data for that sense', () async {
    await s.emulator.writeMf1Blocks(1, Uint8List.fromList(List.filled(16, 7)));
    await s.slots.resetToDefault(0, TagType.mifare1k);
    expect(await s.emulator.readMf1Blocks(1, 1), Uint8List(16));
  });

  test('settings edits update the cache and save explicitly', () async {
    await s.settings.setAnimation(AnimationMode.minimal);
    await s.settings.setButton(DeviceButton.b, ButtonFunction.battery, long: true);
    await s.settings.setSleepTimeout(20);
    expect(s.settings.current!.animation, AnimationMode.minimal);
    expect(s.settings.current!.longButtonB, ButtonFunction.battery);
    expect(s.settings.current!.sleepTimeoutSeconds, 20);
    expect(device.firmware.savedSettings.animation, AnimationMode.full);
    await s.settings.save();
    expect(device.firmware.savedSettings.animation, AnimationMode.minimal);
    await s.settings.reset();
    expect(s.settings.current!.animation, AnimationMode.full);
  });

  test('emulator facade chunks large block writes and reads', () async {
    final data = Uint8List.fromList(List.generate(64 * 16, (i) => i & 0xFF));
    await s.emulator.writeMf1Blocks(0, data);
    expect(await s.emulator.readMf1Blocks(0, 64), data);
    expect(device.received.where((f) => f.command == 4000).length, 2);
  });

  test('emulator facade anti-collision, config and LF ids', () async {
    final tag = Hf14aTag(uid: Uint8List.fromList([9, 8, 7, 6]), atqa: Uint8List.fromList([0, 4]), sak: 8, ats: Uint8List(0));
    await s.emulator.setAntiColl(tag);
    expect((await s.emulator.getAntiColl()).uidHex, '09080706');
    await s.emulator.setMf1WriteMode(Mf1WriteMode.shadow);
    expect((await s.emulator.getMf1Config()).writeMode, Mf1WriteMode.shadow);
    final id = Uint8List.fromList([1, 2, 3, 4, 5]);
    await s.emulator.setLfId(TagType.em410x, id);
    expect(await s.emulator.getLfId(TagType.em410x), id);
    expect(() => s.emulator.setLfId(TagType.mifare1k, id), throwsArgumentError);
  });

  test('firmware facade enters bootloader and the close is expected', () async {
    await s.firmware.enterBootloader();
    await settle();
    expect(device.firmware.bootloaderRequested, isTrue);
    expect((s.connectionState.value as SessionDisconnected).cause, DisconnectCause.expected);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/session/facades_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

In `device_session.dart` add:

```dart
  late final DeviceFacade device = DeviceFacade(this);
  late final SlotsFacade slots = SlotsFacade(this);
  late final SettingsFacade settings = SettingsFacade(this);
  late final EmulatorFacade emulator = EmulatorFacade(this);
  late final FirmwareFacade firmware = FirmwareFacade(this);
```

with imports of the five facade files.

```dart
// lib/src/session/facades/device.dart
import '../../commands/device.dart';
import '../../model/enums.dart';
import '../../model/models.dart';
import '../device_session.dart';

final class DeviceFacade {
  DeviceFacade(this._s);
  final DeviceSession _s;

  DeviceInfo? get info => _s.deviceInfo.value;

  Future<BatteryInfo> readBattery() async {
    final b = await _s.send(const GetBatteryInfo());
    _s.battery.set(b);
    return b;
  }

  Future<DeviceMode> readMode() async {
    final m = await _s.send(const GetDeviceMode());
    _s.mode.set(m);
    return m;
  }

  Future<void> setMode(DeviceMode m) async {
    await _s.send(ChangeDeviceMode(m));
    _s.mode.set(m);
  }

  Future<DeviceIdentity> readIdentity() async {
    final chip = await _s.send(const GetDeviceChipId());
    final id = DeviceIdentity(chip);
    final current = info;
    if (current != null) _s.deviceInfo.set(current.copyWith(identity: id));
    return id;
  }
}
```

```dart
// lib/src/session/facades/slots.dart
import '../../commands/device.dart';
import '../../model/enums.dart';
import '../../model/models.dart';
import '../device_session.dart';

final class SlotsFacade {
  SlotsFacade(this._s);
  final DeviceSession _s;

  List<Slot> get current => _s.slotsState.value;
  int? get active => _s.activeSlot.value;

  Future<List<Slot>> refresh() => _s.refreshSlots();

  Future<void> setActive(int index) async {
    await _s.send(SetActiveSlot(index));
    _s.activeSlot.set(index);
  }

  Future<void> setEnabled(int index, Sense sense, bool enabled) async {
    await _s.send(SetSlotEnable(index, sense, enabled));
    _update(index, (s) => sense == Sense.lf ? s.copyWith(lfEnabled: enabled) : s.copyWith(hfEnabled: enabled));
    await save();
  }

  Future<void> rename(int index, Sense sense, String nick) async {
    await _s.send(SetSlotTagNick(index, sense, nick));
    _update(index, (s) => sense == Sense.lf ? s.copyWith(lfNick: nick) : s.copyWith(hfNick: nick));
    await save();
  }

  Future<void> setTagType(int index, TagType type) async {
    await _s.send(SetSlotTagType(index, type));
    _update(index, (s) => type.sense == Sense.lf ? s.copyWith(lfType: type) : s.copyWith(hfType: type));
    await save();
  }

  /// Sets the type and resets that sense's emulator data to defaults.
  Future<void> resetToDefault(int index, TagType type) async {
    await _s.send(SetSlotDataDefault(index, type));
    _update(index, (s) => type.sense == Sense.lf ? s.copyWith(lfType: type) : s.copyWith(hfType: type));
    await save();
  }

  Future<void> deleteSense(int index, Sense sense) async {
    await _s.send(DeleteSlotSenseType(index, sense));
    _update(index, (s) => sense == Sense.lf
        ? s.copyWith(lfType: TagType.undefined, lfEnabled: false)
        : s.copyWith(hfType: TagType.undefined, hfEnabled: false));
    await save();
  }

  Future<void> save() => _s.send(const SlotDataConfigSave());

  void _update(int index, Slot Function(Slot) f) {
    final list = List<Slot>.of(current);
    if (index >= list.length) return;
    list[index] = f(list[index]);
    _s.slotsState.set(list);
  }
}
```

```dart
// lib/src/session/facades/settings.dart
import '../../commands/device.dart';
import '../../model/enums.dart';
import '../../model/models.dart';
import '../device_session.dart';

final class SettingsFacade {
  SettingsFacade(this._s);
  final DeviceSession _s;

  DeviceSettings? get current => _s.settingsState.value;

  Future<DeviceSettings> refresh() async {
    final v = await _s.send(const GetDeviceSettings());
    _s.settingsState.set(v);
    return v;
  }

  Future<void> setAnimation(AnimationMode mode) async {
    await _s.send(SetAnimationMode(mode));
    _update((s) => s.copyWith(animation: mode));
  }

  Future<void> setButton(DeviceButton button, ButtonFunction fn, {bool long = false}) async {
    await _s.send(long ? SetLongButtonPressConfig(button, fn) : SetButtonPressConfig(button, fn));
    _update((s) => switch ((button, long)) {
          (DeviceButton.a, false) => s.copyWith(buttonA: fn),
          (DeviceButton.b, false) => s.copyWith(buttonB: fn),
          (DeviceButton.a, true) => s.copyWith(longButtonA: fn),
          (DeviceButton.b, true) => s.copyWith(longButtonB: fn),
        });
  }

  Future<void> setBlePairingKey(String key) async {
    await _s.send(SetBlePairingKey(key));
    _update((s) => s.copyWith(blePairingKey: key));
  }

  Future<void> setBlePairingEnabled(bool enabled) async {
    await _s.send(SetBlePairingEnable(enabled));
    _update((s) => s.copyWith(blePairingEnabled: enabled));
  }

  Future<void> setSleepTimeout(int seconds) async {
    await _s.send(SetSleepTimeout(seconds));
    _update((s) => s.copyWith(sleepTimeoutSeconds: seconds));
  }

  Future<void> save() => _s.send(const SaveSettings());

  Future<void> reset() async {
    await _s.send(const ResetSettings());
    await refresh();
  }

  Future<void> deleteAllBleBonds() => _s.send(const DeleteAllBleBonds());

  void _update(DeviceSettings Function(DeviceSettings) f) {
    final c = current;
    if (c != null) _s.settingsState.set(f(c));
  }
}
```

```dart
// lib/src/session/facades/emulator.dart
import 'dart:typed_data';

import '../../commands/hf_emulator.dart';
import '../../commands/lf_emulator.dart';
import '../../commands/raw.dart';
import '../../model/enums.dart';
import '../../model/models.dart';
import '../device_session.dart';

/// Operates on the active slot's emulator data.
final class EmulatorFacade {
  EmulatorFacade(this._s);
  final DeviceSession _s;

  static const int _blocksPerChunk = 32;

  Future<Uint8List> readMf1Blocks(int start, int count) async {
    final out = BytesBuilder(copy: false);
    var offset = 0;
    while (offset < count) {
      final n = (count - offset).clamp(1, _blocksPerChunk);
      out.add(await _s.send(Mf1ReadEmuBlockData(start + offset, n)));
      offset += n;
    }
    return out.toBytes();
  }

  Future<void> writeMf1Blocks(int start, Uint8List data) async {
    if (data.length % 16 != 0) {
      throw ArgumentError.value(data.length, 'data', 'must be a multiple of 16');
    }
    final total = data.length ~/ 16;
    var offset = 0;
    while (offset < total) {
      final n = (total - offset).clamp(1, _blocksPerChunk);
      await _s.send(Mf1WriteEmuBlockData(
          start + offset, Uint8List.sublistView(data, offset * 16, (offset + n) * 16)));
      offset += n;
    }
  }

  Future<Hf14aTag> getAntiColl() => _s.send(const Hf14aGetAntiCollData());

  Future<void> setAntiColl(Hf14aTag t) =>
      _s.send(Hf14aSetAntiCollData(uid: t.uid, atqa: t.atqa, sak: t.sak, ats: t.ats));

  Future<Mf1EmulatorConfig> getMf1Config() => _s.send(const Mf1GetEmulatorConfig());
  Future<void> setMf1WriteMode(Mf1WriteMode m) => _s.send(Mf1SetWriteMode(m));
  Future<void> setGen1a(bool v) => _s.send(Mf1SetGen1aMode(v));
  Future<void> setGen2(bool v) => _s.send(Mf1SetGen2Mode(v));
  Future<void> setBlockAntiColl(bool v) => _s.send(Mf1SetBlockAntiCollMode(v));
  Future<void> setDetectionEnabled(bool v) => _s.send(Mf1SetDetectionEnable(v));

  Future<List<DetectionLogEntry>> readDetectionLog() async {
    final count = await _s.send(const Mf1GetDetectionCount());
    if (count == 0) return const [];
    return _s.send(const Mf1GetDetectionLog(0));
  }

  Future<Uint8List> readNtagPages(int start, int count) => _s.send(Mf0NtagReadEmuPageData(start, count));
  Future<void> writeNtagPages(int start, Uint8List data) => _s.send(Mf0NtagWriteEmuPageData(start, data));
  Future<int> getNtagPageCount() => _s.send(const Mf0NtagGetPageCount());

  static int? lfSetCommandId(TagType t) => switch (t) {
        TagType.em410x => 5000,
        TagType.hidProx => 5002,
        TagType.viking => 5004,
        TagType.pac => 5006,
        TagType.jablotron => 5010,
        TagType.idteck => 5012,
        _ => null,
      };

  Future<void> setLfId(TagType type, Uint8List id) async {
    final cmd = lfSetCommandId(type);
    if (cmd == null) throw ArgumentError.value(type, 'type', 'not an LF emulator type');
    final expected = emuLfIdLengths[cmd]!;
    if (id.length != expected) throw ArgumentError.value(id.length, 'id', 'must be $expected bytes');
    await _s.send(RawCommand(cmd, id));
  }

  Future<Uint8List> getLfId(TagType type) async {
    final cmd = lfSetCommandId(type);
    if (cmd == null) throw ArgumentError.value(type, 'type', 'not an LF emulator type');
    return _s.send(RawCommand(cmd + 1, Uint8List(0)));
  }
}
```

```dart
// lib/src/session/facades/firmware.dart
import 'dart:async';

import '../../commands/device.dart';
import '../connection_state.dart';
import '../device_session.dart';

final class FirmwareFacade {
  FirmwareFacade(this._s);
  final DeviceSession _s;

  /// Moves the session to updating and reboots the device into the
  /// bootloader. Allowed from ready and limited. Resolves when the transport
  /// reports closed, or after [grace] if the link stays up.
  Future<void> enterBootloader({Duration grace = const Duration(seconds: 5)}) async {
    final state = _s.connectionState.value;
    if (state is! SessionReady && state is! SessionLimited) {
      throw StateError('cannot enter bootloader from ${state.runtimeType}');
    }
    _s.connectionState.set(const SessionUpdating());
    final closed = _s.connectionState.changes
        .firstWhere((c) => c is SessionDisconnected)
        .timeout(grace, onTimeout: () => const SessionDisconnected(DisconnectCause.expected));
    await _s.send(const EnterBootloader());
    await closed;
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `mise x -- dart test test/session`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): add device, slots, settings, emulator and firmware facades

Slot mutations persist immediately; settings save explicitly because
pairing changes need a save and reboot (spec 8.1)."
```

---

### Task 16: Reader facade

**Files:**
- Create: `lib/src/session/facades/reader.dart`, `test/session/reader_facade_test.dart`
- Modify: `lib/src/session/device_session.dart` (add `late final ReaderFacade reader = ReaderFacade(this);`)

**Interfaces:**
- Produces:

```dart
final class Mf1DumpReadResult { Uint8List blocks; List<bool> readMask; List<SectorKeys> keys; int get blockCount; bool get isComplete; }
final class ReaderFacade {
  Future<List<Hf14aTag>> scan14a();            // [] when no tag
  Future<bool> detectMf1Support();
  Future<PrngType?> detectPrng();              // null when no tag
  Future<bool> mf1Auth(int block, KeyType type, Uint8List key);
  Future<Uint8List> mf1ReadBlock(int block, KeyType type, Uint8List key);
  Future<void> mf1WriteBlock(int block, KeyType type, Uint8List key, Uint8List data);
  Future<Mf1KeyCheckResult> mf1CheckKeys({required Set<int> sectors, Set<KeyType> keyTypes = const {KeyType.a, KeyType.b}, required List<Uint8List> keys});
  Future<Mf1DumpReadResult> mf1ReadDump({required TagType type, required List<Uint8List> candidateKeys, void Function(int done, int total)? onProgress, CancelToken? cancel});
  Future<Uint8List?> scanEm410x(); Future<Uint8List?> scanHidProx(); Future<Uint8List?> scanViking(); Future<Uint8List?> scanPac();
  static int sectorCount(TagType t); static int blockCount(TagType t); static int firstBlockOf(int sector); static int blocksInSector(int sector);
}
```

- [ ] **Step 1: Write the failing tests**

```dart
// test/session/reader_facade_test.dart
import 'dart:typed_data';

import 'package:chameleon/src/fake/fake_card.dart';
import 'package:chameleon/src/fake/fake_device.dart';
import 'package:chameleon/src/fake/fake_firmware.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/session/device_session.dart';
import 'package:chameleon/src/session/facades/reader.dart';
import 'package:test/test.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));
Uint8List b(List<int> l) => Uint8List.fromList(l);

void main() {
  late FakeDevice device;
  late DeviceSession s;

  setUp(() async {
    device = FakeDevice();
    s = DeviceSession(device, idlePollInterval: const Duration(days: 1), batteryDelay: Duration.zero);
    await s.open();
    await settle();
  });

  tearDown(() => s.close());

  test('scan14a returns empty when no card and restores emulator mode', () async {
    expect(await s.reader.scan14a(), isEmpty);
    expect(device.firmware.mode, DeviceMode.emulator);
  });

  test('scan14a returns the presented card', () async {
    device.firmware.present(FakeMf1Card.classic1k(uid: b([1, 2, 3, 4])));
    final tags = await s.reader.scan14a();
    expect(tags.single.uidHex, '01020304');
    expect(await s.reader.detectMf1Support(), isTrue);
    expect(await s.reader.detectPrng(), PrngType.weak);
  });

  test('mf1Auth is false on a wrong key, read and write work with the right key', () async {
    final card = FakeMf1Card.classic1k(uid: b([1, 2, 3, 4]));
    device.firmware.present(card);
    expect(await s.reader.mf1Auth(0, KeyType.a, Uint8List(6)), isFalse);
    expect(await s.reader.mf1Auth(0, KeyType.a, FakeMf1Card.defaultKey), isTrue);
    final block = await s.reader.mf1ReadBlock(0, KeyType.a, FakeMf1Card.defaultKey);
    expect(block.sublist(0, 4), [1, 2, 3, 4]);
    await s.reader.mf1WriteBlock(4, KeyType.a, FakeMf1Card.defaultKey, b(List.filled(16, 1)));
    expect(card.blocks.sublist(64, 80), List.filled(16, 1));
  });

  test('mf1CheckKeys finds keys per sector', () async {
    device.firmware.present(FakeMf1Card.classic1k(uid: b([1, 2, 3, 4])));
    final r = await s.reader.mf1CheckKeys(sectors: {0, 1}, keys: [Uint8List(6), FakeMf1Card.defaultKey]);
    expect(r.sectors[0].keyA, FakeMf1Card.defaultKey);
    expect(r.sectors[1].keyB, FakeMf1Card.defaultKey);
    expect(r.sectors[2].keyA, isNull);
  });

  test('mf1ReadDump reads every block of a 1K with the right keys and reports progress', () async {
    final card = FakeMf1Card.classic1k(uid: b([1, 2, 3, 4]));
    device.firmware.present(card);
    final progress = <int>[];
    final dump = await s.reader.mf1ReadDump(
      type: TagType.mifare1k,
      candidateKeys: [FakeMf1Card.defaultKey],
      onProgress: (done, total) => progress.add(done),
    );
    expect(dump.blockCount, 64);
    expect(dump.isComplete, isTrue);
    expect(dump.blocks, card.blocks);
    expect(dump.keys[3].keyA, FakeMf1Card.defaultKey);
    expect(progress.last, 16);
    expect(device.firmware.mode, DeviceMode.emulator);
  });

  test('mf1ReadDump marks unreadable sectors and stays partial', () async {
    final card = FakeMf1Card.classic1k(uid: b([1, 2, 3, 4]));
    card.keys.remove(FakeMf1Card.keyId(5, KeyType.a));
    card.keys.remove(FakeMf1Card.keyId(5, KeyType.b));
    device.firmware.present(card);
    final dump = await s.reader.mf1ReadDump(type: TagType.mifare1k, candidateKeys: [FakeMf1Card.defaultKey]);
    expect(dump.isComplete, isFalse);
    expect(dump.readMask.sublist(20, 24), everyElement(isFalse));
    expect(dump.readMask.sublist(0, 20), everyElement(isTrue));
  });

  test('LF scans return null when absent and bytes when present', () async {
    expect(await s.reader.scanEm410x(), isNull);
    device.firmware.present(FakeLfCard(3000, b([1, 2, 3, 4, 5])));
    expect(await s.reader.scanEm410x(), [1, 2, 3, 4, 5]);
    expect(await s.reader.scanHidProx(), isNull);
  });

  test('geometry helpers', () {
    expect(ReaderFacade.sectorCount(TagType.mifare1k), 16);
    expect(ReaderFacade.sectorCount(TagType.mifare4k), 40);
    expect(ReaderFacade.blockCount(TagType.mifareMini), 20);
    expect(ReaderFacade.firstBlockOf(32), 128);
    expect(ReaderFacade.blocksInSector(39), 16);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/session/reader_facade_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/src/session/facades/reader.dart
import 'dart:typed_data';

import '../../commands/hf_reader.dart';
import '../../commands/lf_reader.dart';
import '../../model/enums.dart';
import '../../model/models.dart';
import '../../protocol/command.dart';
import '../../protocol/errors.dart';
import '../cancel_token.dart';
import '../device_session.dart';

final class Mf1DumpReadResult {
  Mf1DumpReadResult({required this.blocks, required this.readMask, required this.keys});
  final Uint8List blocks;
  final List<bool> readMask;
  final List<SectorKeys> keys;

  int get blockCount => readMask.length;
  bool get isComplete => readMask.every((b) => b);
}

/// Reader operations. Every method takes its own reader lease, so callers
/// never manage device mode.
final class ReaderFacade {
  ReaderFacade(this._s);
  final DeviceSession _s;

  static int sectorCount(TagType t) => switch (t) {
        TagType.mifareMini => 5,
        TagType.mifare1k => 16,
        TagType.mifare2k => 32,
        TagType.mifare4k => 40,
        _ => throw ArgumentError.value(t, 'type', 'not MIFARE Classic'),
      };

  static int blocksInSector(int sector) => sector < 32 ? 4 : 16;

  static int firstBlockOf(int sector) => sector < 32 ? sector * 4 : 128 + (sector - 32) * 16;

  static int blockCount(TagType t) {
    final n = sectorCount(t);
    return firstBlockOf(n - 1) + blocksInSector(n - 1);
  }

  Future<T?> _orNull<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on HfTagNotFound {
      return null;
    } on LfTagNotFound {
      return null;
    }
  }

  Future<List<Hf14aTag>> scan14a() => _s.withReaderMode(() async =>
      await _orNull(() => _s.send(const Hf14aScan())) ?? const []);

  Future<bool> detectMf1Support() => _s.withReaderMode(() async {
        try {
          await _s.send(const Mf1DetectSupport());
          return true;
        } on DeviceError {
          return false;
        }
      });

  Future<PrngType?> detectPrng() => _s.withReaderMode(() => _orNull(() => _s.send(const Mf1DetectPrng())));

  Future<bool> mf1Auth(int block, KeyType type, Uint8List key) => _s.withReaderMode(() async {
        try {
          await _s.send(Mf1AuthOneKeyBlock(type, block, key));
          return true;
        } on AuthenticationFailed {
          return false;
        }
      });

  Future<Uint8List> mf1ReadBlock(int block, KeyType type, Uint8List key) =>
      _s.withReaderMode(() => _s.send(Mf1ReadOneBlock(type, block, key)));

  Future<void> mf1WriteBlock(int block, KeyType type, Uint8List key, Uint8List data) =>
      _s.withReaderMode(() => _s.send(Mf1WriteOneBlock(type, block, key, data)));

  Future<Mf1KeyCheckResult> mf1CheckKeys({
    required Set<int> sectors,
    Set<KeyType> keyTypes = const {KeyType.a, KeyType.b},
    required List<Uint8List> keys,
  }) =>
      _s.withReaderMode(() => _s.send(Mf1CheckKeysOfSectors(sectors: sectors, keyTypes: keyTypes, keys: keys)));

  /// Reads a full MIFARE Classic dump: finds a working key per sector from
  /// [candidateKeys], then reads each block. Sectors with no working key stay
  /// zero with readMask false.
  Future<Mf1DumpReadResult> mf1ReadDump({
    required TagType type,
    required List<Uint8List> candidateKeys,
    void Function(int done, int total)? onProgress,
    CancelToken? cancel,
  }) {
    final sectors = sectorCount(type);
    final totalBlocks = blockCount(type);
    return _s.withReaderMode(() => _s.busy(() async {
          final blocks = Uint8List(totalBlocks * 16);
          final mask = List<bool>.filled(totalBlocks, false);
          final found = await _s.send(
            Mf1CheckKeysOfSectors(
              sectors: {for (var i = 0; i < sectors; i++) i},
              keyTypes: const {KeyType.a, KeyType.b},
              keys: candidateKeys.take(83).toList(),
            ),
            cancel: cancel,
          );
          final keys = found.sectors.take(sectors).toList();
          for (var s = 0; s < sectors; s++) {
            if (cancel?.isCancelled ?? false) throw const CommandCancelled();
            final sk = keys[s];
            final (KeyType, Uint8List)? pick = sk.keyA != null
                ? (KeyType.a, sk.keyA!)
                : sk.keyB != null
                    ? (KeyType.b, sk.keyB!)
                    : null;
            if (pick != null) {
              final first = firstBlockOf(s);
              for (var b = first; b < first + blocksInSector(s); b++) {
                try {
                  final data = await _s.send(Mf1ReadOneBlock(pick.$1, b, pick.$2), cancel: cancel);
                  blocks.setRange(b * 16, b * 16 + 16, data);
                  mask[b] = true;
                } on DeviceError {
                  // leave block unread
                }
              }
            }
            onProgress?.call(s + 1, sectors);
          }
          return Mf1DumpReadResult(blocks: blocks, readMask: mask, keys: keys);
        }));
  }

  Future<Uint8List?> _lfScan(Command<Uint8List> c) => _s.withReaderMode(() => _orNull(() => _s.send(c)));

  Future<Uint8List?> scanEm410x() => _lfScan(const Em410xScan());
  Future<Uint8List?> scanHidProx() => _lfScan(const HidProxScan());
  Future<Uint8List?> scanViking() => _lfScan(const VikingScan());
  Future<Uint8List?> scanPac() => _lfScan(const PacScan());
}
```

Note: `Mf1DumpReadResult.keys[3].keyA` in the test reads the trailer keys as found by the check; sector 3's key A is the default key, so this asserts the check result flowed through.

- [ ] **Step 4: Run to verify pass**

Run: `mise x -- dart test test/session`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): add reader facade with full-dump read"
```

---

### Task 17: Dump formats

**Files:**
- Create: `lib/src/dump/dump_format.dart`, `lib/src/dump/mifare_classic.dart`, `lib/src/dump/ultralight.dart`, `lib/src/dump/em410x.dart`, `test/dump/dump_formats_test.dart`

**Interfaces:**
- Produces:

```dart
abstract interface class CardDump { TagType get type; Uint8List toBytes(); }
final class DumpField { const DumpField(String label, String value); }
abstract interface class DumpFormat<T extends CardDump> { TagFamily get family; T parse(Uint8List bytes, TagType type); List<DumpField> describe(T dump); List<String> validate(T dump); }
abstract final class DumpFormats { static DumpFormat<CardDump>? forType(TagType t); static CardDump parse(Uint8List bytes, TagType t); static int ultralightPageCount(TagType t); }
final class MifareClassicDump implements CardDump { MifareClassicDump(TagType type, Uint8List blocks); int get blockCount; int get sectorCount; Uint8List get uid; Uint8List keyA(int sector); Uint8List keyB(int sector); Uint8List accessBits(int sector); Uint8List block(int i); }
final class UltralightDump implements CardDump { UltralightDump(TagType type, Uint8List pages); int get pageCount; Uint8List get uid; Uint8List page(int i); }
final class Em410xDump implements CardDump { Em410xDump(Uint8List id); }
```

- [ ] **Step 1: Write the failing tests**

```dart
// test/dump/dump_formats_test.dart
import 'dart:typed_data';

import 'package:chameleon/src/dump/dump_format.dart';
import 'package:chameleon/src/dump/em410x.dart';
import 'package:chameleon/src/dump/mifare_classic.dart';
import 'package:chameleon/src/dump/ultralight.dart';
import 'package:chameleon/src/fake/fake_card.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:test/test.dart';

Uint8List b(List<int> l) => Uint8List.fromList(l);

void main() {
  test('registry finds a format per family', () {
    expect(DumpFormats.forType(TagType.mifare1k), isA<MifareClassicFormat>());
    expect(DumpFormats.forType(TagType.ntag215), isA<UltralightFormat>());
    expect(DumpFormats.forType(TagType.em410x), isA<Em410xFormat>());
    expect(DumpFormats.forType(TagType.seos), isNull);
  });

  test('MIFARE Classic dump exposes geometry and keys', () {
    final card = FakeMf1Card.classic1k(uid: b([1, 2, 3, 4]));
    final dump = DumpFormats.parse(card.blocks, TagType.mifare1k) as MifareClassicDump;
    expect(dump.blockCount, 64);
    expect(dump.sectorCount, 16);
    expect(dump.uid, [1, 2, 3, 4]);
    expect(dump.keyA(0), FakeMf1Card.defaultKey);
    expect(dump.keyB(15), FakeMf1Card.defaultKey);
    expect(dump.accessBits(0), [0xFF, 0x07, 0x80, 0x69]);
    expect(dump.toBytes(), card.blocks);
    expect(const MifareClassicFormat().validate(dump), isEmpty);
    final fields = const MifareClassicFormat().describe(dump);
    expect(fields.any((f) => f.label == 'UID' && f.value == '01020304'), isTrue);
  });

  test('MIFARE Classic validation flags wrong length and bad BCC', () {
    final bad = MifareClassicDump(TagType.mifare1k, Uint8List(63 * 16));
    expect(const MifareClassicFormat().validate(bad), contains(contains('length')));
    final card = FakeMf1Card.classic1k(uid: b([1, 2, 3, 4]));
    card.blocks[4] ^= 0xFF;
    final dump = MifareClassicDump(TagType.mifare1k, card.blocks);
    expect(const MifareClassicFormat().validate(dump), contains(contains('BCC')));
  });

  test('Ultralight dump reads the 7-byte UID from pages 0 and 1', () {
    final pages = Uint8List(135 * 4);
    pages.setRange(0, 3, [0x04, 0xAA, 0xBB]);
    pages.setRange(4, 8, [0xCC, 0xDD, 0xEE, 0xFF]);
    final dump = DumpFormats.parse(pages, TagType.ntag215) as UltralightDump;
    expect(dump.pageCount, 135);
    expect(dump.uid, [0x04, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]);
    expect(const UltralightFormat().validate(dump), isEmpty);
    expect(const UltralightFormat().validate(UltralightDump(TagType.ntag213, Uint8List(8))),
        contains(contains('pages')));
    expect(DumpFormats.ultralightPageCount(TagType.ntag216), 231);
  });

  test('EM410X dump is five bytes', () {
    final dump = DumpFormats.parse(b([0xDE, 0xAD, 0xBE, 0xEF, 0x01]), TagType.em410x) as Em410xDump;
    expect(dump.toBytes(), [0xDE, 0xAD, 0xBE, 0xEF, 0x01]);
    expect(const Em410xFormat().describe(dump).first.value, 'DEADBEEF01');
    expect(const Em410xFormat().validate(Em410xDump(b([1]))), isNotEmpty);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/dump`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/src/dump/dump_format.dart
import 'dart:typed_data';

import '../model/enums.dart';
import 'em410x.dart';
import 'mifare_classic.dart';
import 'ultralight.dart';

abstract interface class CardDump {
  TagType get type;
  Uint8List toBytes();
}

final class DumpField {
  const DumpField(this.label, this.value);
  final String label;
  final String value;
}

/// Pure knowledge of one tag family's dump layout (spec 3.5).
abstract interface class DumpFormat<T extends CardDump> {
  TagFamily get family;
  T parse(Uint8List bytes, TagType type);
  List<DumpField> describe(T dump);

  /// Empty when valid; otherwise human-readable problems.
  List<String> validate(T dump);
}

abstract final class DumpFormats {
  static final Map<TagFamily, DumpFormat<CardDump>> _byFamily = {
    TagFamily.mifareClassic: const MifareClassicFormat(),
    TagFamily.ultralight: const UltralightFormat(),
    TagFamily.lf: const Em410xFormat(),
  };

  static DumpFormat<CardDump>? forType(TagType t) {
    if (t.family == TagFamily.lf && t != TagType.em410x) return null;
    return _byFamily[t.family];
  }

  static CardDump parse(Uint8List bytes, TagType t) {
    final f = forType(t);
    if (f == null) throw ArgumentError.value(t, 'type', 'no dump format');
    return f.parse(bytes, t);
  }

  static int ultralightPageCount(TagType t) => switch (t) {
        TagType.ntag210 => 20,
        TagType.ntag212 => 41,
        TagType.ntag213 => 45,
        TagType.ntag215 => 135,
        TagType.ntag216 => 231,
        TagType.mf0icu1 => 16,
        TagType.mf0icu2 => 44,
        TagType.mf0ul11 => 20,
        TagType.mf0ul21 => 41,
        _ => throw ArgumentError.value(t, 'type', 'not Ultralight'),
      };
}
```

```dart
// lib/src/dump/mifare_classic.dart
import 'dart:typed_data';

import '../model/enums.dart';
import '../model/models.dart';
import 'dump_format.dart';

final class MifareClassicDump implements CardDump {
  MifareClassicDump(this.type, this.blocks);

  @override
  final TagType type;
  final Uint8List blocks;

  static int sectorCountFor(TagType t) => switch (t) {
        TagType.mifareMini => 5,
        TagType.mifare1k => 16,
        TagType.mifare2k => 32,
        TagType.mifare4k => 40,
        _ => throw ArgumentError.value(t, 'type', 'not MIFARE Classic'),
      };

  static int firstBlockOf(int sector) => sector < 32 ? sector * 4 : 128 + (sector - 32) * 16;
  static int blocksInSector(int sector) => sector < 32 ? 4 : 16;
  static int trailerOf(int sector) => firstBlockOf(sector) + blocksInSector(sector) - 1;

  int get sectorCount => sectorCountFor(type);
  int get expectedBlockCount => firstBlockOf(sectorCount - 1) + blocksInSector(sectorCount - 1);
  int get blockCount => blocks.length ~/ 16;

  Uint8List block(int i) => Uint8List.sublistView(blocks, i * 16, i * 16 + 16);
  Uint8List get uid => Uint8List.sublistView(blocks, 0, 4);
  Uint8List keyA(int sector) => Uint8List.sublistView(block(trailerOf(sector)), 0, 6);
  Uint8List accessBits(int sector) => Uint8List.sublistView(block(trailerOf(sector)), 6, 10);
  Uint8List keyB(int sector) => Uint8List.sublistView(block(trailerOf(sector)), 10, 16);

  @override
  Uint8List toBytes() => blocks;
}

final class MifareClassicFormat implements DumpFormat<MifareClassicDump> {
  const MifareClassicFormat();

  @override
  TagFamily get family => TagFamily.mifareClassic;

  @override
  MifareClassicDump parse(Uint8List bytes, TagType type) => MifareClassicDump(type, bytes);

  @override
  List<DumpField> describe(MifareClassicDump d) => [
        DumpField('UID', hexOf(d.uid)),
        DumpField('Type', d.type.name),
        DumpField('Sectors', '${d.sectorCount}'),
        DumpField('Blocks', '${d.blockCount}'),
        DumpField('SAK', d.blocks.length > 5 ? hexOf([d.blocks[5]]) : ''),
        DumpField('ATQA', d.blocks.length > 7 ? hexOf([d.blocks[7], d.blocks[6]]) : ''),
      ];

  @override
  List<String> validate(MifareClassicDump d) {
    final problems = <String>[];
    if (d.blocks.length != d.expectedBlockCount * 16) {
      problems.add('length ${d.blocks.length} is not ${d.expectedBlockCount * 16} bytes');
      return problems;
    }
    final bcc = d.uid.fold<int>(0, (a, x) => a ^ x);
    if (d.blocks[4] != bcc) problems.add('BCC ${hexOf([d.blocks[4]])} does not match UID');
    return problems;
  }
}
```

```dart
// lib/src/dump/ultralight.dart
import 'dart:typed_data';

import '../model/enums.dart';
import '../model/models.dart';
import 'dump_format.dart';

final class UltralightDump implements CardDump {
  UltralightDump(this.type, this.pages);

  @override
  final TagType type;
  final Uint8List pages;

  int get pageCount => pages.length ~/ 4;
  Uint8List page(int i) => Uint8List.sublistView(pages, i * 4, i * 4 + 4);

  /// 7-byte UID: page 0 bytes 0..2 then page 1 bytes 0..3.
  Uint8List get uid => Uint8List.fromList([...pages.sublist(0, 3), ...pages.sublist(4, 8)]);

  @override
  Uint8List toBytes() => pages;
}

final class UltralightFormat implements DumpFormat<UltralightDump> {
  const UltralightFormat();

  @override
  TagFamily get family => TagFamily.ultralight;

  @override
  UltralightDump parse(Uint8List bytes, TagType type) => UltralightDump(type, bytes);

  @override
  List<DumpField> describe(UltralightDump d) => [
        DumpField('UID', d.pages.length >= 8 ? hexOf(d.uid) : ''),
        DumpField('Type', d.type.name),
        DumpField('Pages', '${d.pageCount}'),
      ];

  @override
  List<String> validate(UltralightDump d) {
    final expected = DumpFormats.ultralightPageCount(d.type);
    if (d.pages.length % 4 != 0) return ['length is not a multiple of 4'];
    if (d.pageCount != expected) return ['has ${d.pageCount} pages, expected $expected'];
    return const [];
  }
}
```

```dart
// lib/src/dump/em410x.dart
import 'dart:typed_data';

import '../model/enums.dart';
import '../model/models.dart';
import 'dump_format.dart';

final class Em410xDump implements CardDump {
  Em410xDump(this.id);
  final Uint8List id;

  @override
  TagType get type => TagType.em410x;

  @override
  Uint8List toBytes() => id;
}

final class Em410xFormat implements DumpFormat<Em410xDump> {
  const Em410xFormat();

  @override
  TagFamily get family => TagFamily.lf;

  @override
  Em410xDump parse(Uint8List bytes, TagType type) => Em410xDump(bytes);

  @override
  List<DumpField> describe(Em410xDump d) => [DumpField('ID', hexOf(d.id))];

  @override
  List<String> validate(Em410xDump d) => d.id.length == 5 ? const [] : ['id must be 5 bytes'];
}
```

- [ ] **Step 4: Run to verify pass**

Run: `mise x -- dart test test/dump`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): add dump formats for MIFARE Classic, Ultralight and EM410X"
```

---

### Task 18: DFU package and init packet parsing

**Files:**
- Create: `lib/src/dfu/protobuf_reader.dart`, `lib/src/dfu/dfu_package.dart`, `test/dfu/dfu_package_test.dart`, `test/dfu/proto_builder.dart` (test helper)
- Modify: `lib/src/protocol/errors.dart` (add `DfuError`)

**Interfaces:**
- Produces:

```dart
final class DfuError extends ChameleonException { DfuError(String message, {int? opcode, int? result}); }
final class ProtoReader { ProtoReader(Uint8List); bool get isAtEnd; (int field, int wire) readTag(); int readVarint(); Uint8List readBytes(); void skip(int wire); }
final class InitPacket { int fwVersion; int hwVersion; List<int> sdReq; int type; int sdSize; int blSize; int appSize; int hashType; Uint8List hash; bool isDebug; static InitPacket parse(Uint8List dat); }
enum DfuImageKind { softdeviceBootloader, softdevice, bootloader, application }
final class DfuImage { DfuImageKind kind; Uint8List bin; Uint8List dat; InitPacket init; bool get hashMatches; }
final class DfuPackage { List<DfuImage> images; int get hardwareVersion; DeviceModel? get targetModel; static DfuPackage fromZip(Uint8List zip); }
```

Test helper `test/dfu/proto_builder.dart` builds init packets and zips so every DFU test can make its own package:

```dart
// test/dfu/proto_builder.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

Uint8List varint(int v) {
  final out = <int>[];
  while (v >= 0x80) {
    out.add((v & 0x7F) | 0x80);
    v >>= 7;
  }
  out.add(v);
  return Uint8List.fromList(out);
}

Uint8List field(int number, int wire, List<int> payload) =>
    Uint8List.fromList([...varint((number << 3) | wire), ...payload]);

Uint8List varintField(int number, int v) => field(number, 0, varint(v));
Uint8List bytesField(int number, List<int> b) => field(number, 2, [...varint(b.length), ...b]);

/// Builds a .dat init packet the way nrfutil does (hash stored reversed).
Uint8List buildInitPacket({required Uint8List bin, int hwVersion = 0, int fwVersion = 1, int type = 4}) {
  final hash = sha256.convert(bin).bytes.reversed.toList();
  final hashMsg = [...varintField(1, 3), ...bytesField(2, hash)];
  final init = [
    ...varintField(1, fwVersion),
    ...varintField(2, hwVersion),
    ...bytesField(3, varint(0x0100)), // sd_req packed
    ...varintField(4, type),
    ...varintField(7, bin.length),
    ...bytesField(8, hashMsg),
  ];
  final command = [...varintField(1, 1), ...bytesField(2, init)];
  final signed = [...bytesField(1, command), ...varintField(2, 0), ...bytesField(3, List.filled(64, 0))];
  return bytesField(2, signed);
}

Uint8List buildZip({required Uint8List bin, required Uint8List dat, String binName = 'app.bin', String datName = 'app.dat', String key = 'application'}) {
  final manifest = jsonEncode({
    'manifest': {
      key: {'bin_file': binName, 'dat_file': datName},
    },
  });
  final archive = Archive()
    ..add(ArchiveFile.bytes('manifest.json', Uint8List.fromList(utf8.encode(manifest))))
    ..add(ArchiveFile.bytes(binName, bin))
    ..add(ArchiveFile.bytes(datName, dat));
  return ZipEncoder().encodeBytes(archive);
}
```

If the resolved `archive` major differs from 4, use its equivalents: `ArchiveFile(name, size, bytes)`, `Archive.addFile`, and `Uint8List.fromList(ZipEncoder().encode(archive)!)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/dfu/dfu_package_test.dart
import 'dart:typed_data';

import 'package:chameleon/src/dfu/dfu_package.dart';
import 'package:chameleon/src/dfu/protobuf_reader.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:test/test.dart';

import 'proto_builder.dart';

void main() {
  final bin = Uint8List.fromList(List.generate(1000, (i) => i & 0xFF));

  test('ProtoReader decodes varints, tags and bytes', () {
    final r = ProtoReader(Uint8List.fromList([...varintField(2, 300), ...bytesField(8, [1, 2])]));
    expect(r.readTag(), (2, 0));
    expect(r.readVarint(), 300);
    expect(r.readTag(), (8, 2));
    expect(r.readBytes(), [1, 2]);
    expect(r.isAtEnd, isTrue);
  });

  test('InitPacket parses hw version, app size and hash', () {
    final p = InitPacket.parse(buildInitPacket(bin: bin, hwVersion: 1, fwVersion: 7));
    expect(p.hwVersion, 1);
    expect(p.fwVersion, 7);
    expect(p.appSize, 1000);
    expect(p.hashType, 3);
    expect(p.hash.length, 32);
    expect(p.sdReq, [0x0100]);
    expect(p.type, 4);
  });

  test('DfuPackage reads a zip, verifies the hash and names the model', () {
    final pkg = DfuPackage.fromZip(buildZip(bin: bin, dat: buildInitPacket(bin: bin)));
    expect(pkg.images.single.kind, DfuImageKind.application);
    expect(pkg.images.single.bin, bin);
    expect(pkg.images.single.hashMatches, isTrue);
    expect(pkg.hardwareVersion, 0);
    expect(pkg.targetModel, DeviceModel.ultra);
  });

  test('a Lite package targets the Lite', () {
    final pkg = DfuPackage.fromZip(buildZip(bin: bin, dat: buildInitPacket(bin: bin, hwVersion: 1)));
    expect(pkg.targetModel, DeviceModel.lite);
  });

  test('tampered firmware fails the hash check', () {
    final tampered = Uint8List.fromList(bin)..[10] ^= 1;
    final pkg = DfuPackage.fromZip(buildZip(bin: tampered, dat: buildInitPacket(bin: bin)));
    expect(pkg.images.single.hashMatches, isFalse);
  });

  test('missing manifest is a DfuError', () {
    expect(() => DfuPackage.fromZip(Uint8List(0)), throwsA(isA<DfuError>()));
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/dfu`
Expected: FAIL.

- [ ] **Step 3: Implement**

Add to `lib/src/protocol/errors.dart`:

```dart
final class DfuError extends ChameleonException {
  DfuError(super.message, {this.opcode, this.result});
  final int? opcode;
  final int? result;
}
```

```dart
// lib/src/dfu/protobuf_reader.dart
import 'dart:typed_data';

import '../protocol/errors.dart';

/// Minimal protobuf wire-format reader: enough for Nordic's dfu-cc.proto.
final class ProtoReader {
  ProtoReader(this._d);
  final Uint8List _d;
  int _o = 0;

  bool get isAtEnd => _o >= _d.length;

  int readVarint() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (_o >= _d.length) throw DfuError('truncated varint in init packet');
      final b = _d[_o++];
      result |= (b & 0x7F) << shift;
      if (b & 0x80 == 0) return result;
      shift += 7;
    }
  }

  (int, int) readTag() {
    final t = readVarint();
    return (t >> 3, t & 0x07);
  }

  Uint8List readBytes() {
    final n = readVarint();
    if (_o + n > _d.length) throw DfuError('truncated bytes in init packet');
    final out = Uint8List.fromList(_d.sublist(_o, _o + n));
    _o += n;
    return out;
  }

  void skip(int wire) {
    switch (wire) {
      case 0:
        readVarint();
      case 1:
        _o += 8;
      case 2:
        readBytes();
      case 5:
        _o += 4;
      default:
        throw DfuError('unsupported wire type $wire');
    }
  }
}
```

```dart
// lib/src/dfu/dfu_package.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';

import '../model/enums.dart';
import '../protocol/errors.dart';
import 'protobuf_reader.dart';

/// Decoded dfu-cc.proto InitCommand.
final class InitPacket {
  const InitPacket({
    required this.fwVersion,
    required this.hwVersion,
    required this.sdReq,
    required this.type,
    required this.sdSize,
    required this.blSize,
    required this.appSize,
    required this.hashType,
    required this.hash,
    required this.isDebug,
  });

  final int fwVersion;
  final int hwVersion;
  final List<int> sdReq;
  final int type;
  final int sdSize;
  final int blSize;
  final int appSize;
  final int hashType;
  final Uint8List hash;
  final bool isDebug;

  static const int hashTypeSha256 = 3;

  static InitPacket parse(Uint8List dat) {
    // Packet { command = 1; signed_command = 2 }
    Uint8List? command;
    final packet = ProtoReader(dat);
    while (!packet.isAtEnd) {
      final (f, w) = packet.readTag();
      if (f == 1 && w == 2) {
        command = packet.readBytes();
      } else if (f == 2 && w == 2) {
        // SignedCommand { command = 1; signature_type = 2; signature = 3 }
        final signed = ProtoReader(packet.readBytes());
        while (!signed.isAtEnd) {
          final (sf, sw) = signed.readTag();
          if (sf == 1 && sw == 2) {
            command = signed.readBytes();
          } else {
            signed.skip(sw);
          }
        }
      } else {
        packet.skip(w);
      }
    }
    if (command == null) throw DfuError('init packet has no command');
    // Command { op_code = 1; init = 2 }
    Uint8List? init;
    final cmd = ProtoReader(command);
    while (!cmd.isAtEnd) {
      final (f, w) = cmd.readTag();
      if (f == 2 && w == 2) {
        init = cmd.readBytes();
      } else {
        cmd.skip(w);
      }
    }
    if (init == null) throw DfuError('init packet has no InitCommand');
    var fw = 0, hw = 0, type = 0, sdSize = 0, blSize = 0, appSize = 0, hashType = 0;
    var isDebug = false;
    final sdReq = <int>[];
    Uint8List hash = Uint8List(0);
    final r = ProtoReader(init);
    while (!r.isAtEnd) {
      final (f, w) = r.readTag();
      switch (f) {
        case 1:
          fw = r.readVarint();
        case 2:
          hw = r.readVarint();
        case 3:
          if (w == 2) {
            final packed = ProtoReader(r.readBytes());
            while (!packed.isAtEnd) {
              sdReq.add(packed.readVarint());
            }
          } else {
            sdReq.add(r.readVarint());
          }
        case 4:
          type = r.readVarint();
        case 5:
          sdSize = r.readVarint();
        case 6:
          blSize = r.readVarint();
        case 7:
          appSize = r.readVarint();
        case 8:
          final h = ProtoReader(r.readBytes());
          while (!h.isAtEnd) {
            final (hf, hw2) = h.readTag();
            if (hf == 1) {
              hashType = h.readVarint();
            } else if (hf == 2) {
              hash = h.readBytes();
            } else {
              h.skip(hw2);
            }
          }
        case 9:
          isDebug = r.readVarint() != 0;
        default:
          r.skip(w);
      }
    }
    return InitPacket(
      fwVersion: fw,
      hwVersion: hw,
      sdReq: sdReq,
      type: type,
      sdSize: sdSize,
      blSize: blSize,
      appSize: appSize,
      hashType: hashType,
      hash: hash,
      isDebug: isDebug,
    );
  }
}

enum DfuImageKind { softdeviceBootloader, softdevice, bootloader, application }

final class DfuImage {
  DfuImage({required this.kind, required this.bin, required this.dat}) : init = InitPacket.parse(dat);

  final DfuImageKind kind;
  final Uint8List bin;
  final Uint8List dat;
  final InitPacket init;

  /// nrfutil stores the SHA-256 of the image byte-reversed. hardware-validate
  /// against a real release package.
  bool get hashMatches {
    if (init.hashType != InitPacket.hashTypeSha256) return false;
    final digest = sha256.convert(bin).bytes;
    const eq = ListEquality<int>();
    return eq.equals(digest.reversed.toList(), init.hash) || eq.equals(digest, init.hash);
  }
}

/// An nrfutil zip: manifest.json plus .bin and .dat per image.
final class DfuPackage {
  DfuPackage(this.images);

  final List<DfuImage> images;

  int get hardwareVersion => images.first.init.hwVersion;

  DeviceModel? get targetModel => switch (hardwareVersion) {
        0 => DeviceModel.ultra,
        1 => DeviceModel.lite,
        _ => null,
      };

  static const _manifestOrder = [
    ('softdevice_bootloader', DfuImageKind.softdeviceBootloader),
    ('softdevice', DfuImageKind.softdevice),
    ('bootloader', DfuImageKind.bootloader),
    ('application', DfuImageKind.application),
  ];

  static DfuPackage fromZip(Uint8List zip) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zip);
    } catch (e) {
      throw DfuError('not a zip file: $e');
    }
    Uint8List? file(String name) {
      final f = archive.files.firstWhereOrNull((f) => f.name == name);
      return f == null ? null : Uint8List.fromList(f.readBytes()!);
    }

    final manifestBytes = file('manifest.json');
    if (manifestBytes == null) throw DfuError('manifest.json missing');
    final manifest = (jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>)['manifest'];
    if (manifest is! Map<String, dynamic>) throw DfuError('manifest has no "manifest" object');
    final images = <DfuImage>[];
    for (final (key, kind) in _manifestOrder) {
      final entry = manifest[key];
      if (entry is! Map<String, dynamic>) continue;
      final bin = file(entry['bin_file'] as String);
      final dat = file(entry['dat_file'] as String);
      if (bin == null || dat == null) throw DfuError('$key files missing from zip');
      images.add(DfuImage(kind: kind, bin: bin, dat: dat));
    }
    if (images.isEmpty) throw DfuError('manifest lists no images');
    return DfuPackage(images);
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `mise x -- dart test test/dfu`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): parse nrfutil DFU packages and init packets"
```

---

### Task 19: Secure DFU state machine, channel and fake bootloader

**Files:**
- Create: `lib/src/dfu/crc32.dart`, `lib/src/dfu/dfu_channel.dart`, `lib/src/dfu/secure_dfu.dart`, `lib/src/dfu/fake_bootloader.dart`, `test/dfu/crc32_test.dart`, `test/dfu/secure_dfu_test.dart`

**Interfaces:**
- Produces:

```dart
int crc32(List<int> bytes, [int seed = 0]);
abstract interface class DfuChannel { int get maxDataWrite; Future<void> writeControl(Uint8List); Future<void> writeData(Uint8List); Stream<Uint8List> get responses; Future<void> close(); }
enum DfuStage { init, firmware, done }
final class DfuProgress { DfuStage stage; int bytesSent; int bytesTotal; double get fraction; }
final class SecureDfu { SecureDfu(DfuChannel channel, {Duration responseTimeout = 30s}); Future<void> run(DfuImage image, {void Function(DfuProgress)? onProgress, CancelToken? cancel}); }
final class FakeBootloader { FakeBootloader({int maxObjectSize = 4096, int expectedHwVersion = 0}); Uint8List handleControl(Uint8List req); void handleData(Uint8List bytes); Uint8List get flashed; InitPacket? get init; bool get completed; void failNextCreate(); void corruptNextCrc(); }
final class FakeDfuChannel implements DfuChannel { FakeDfuChannel(FakeBootloader, {int maxDataWrite = 20, Duration latency = Duration.zero}); bool get isClosed; void dropNextResponse(); }
```

Secure DFU opcodes: create 0x01, set PRN 0x02, calculate CRC 0x03, execute 0x04, select 0x06, response 0x60. Result codes: 0x01 success, 0x02 opcode not supported, 0x03 invalid parameter, 0x04 insufficient resources, 0x05 invalid object, 0x07 unsupported type, 0x08 operation not permitted, 0x0A operation failed. Object types: 1 command (init packet), 2 data (firmware). Multi-byte fields in DFU control payloads are little-endian.

- [ ] **Step 1: Write the failing tests**

```dart
// test/dfu/crc32_test.dart
import 'dart:convert';

import 'package:chameleon/src/dfu/crc32.dart';
import 'package:test/test.dart';

void main() {
  test('crc32 of "123456789" is 0xCBF43926', () {
    expect(crc32(utf8.encode('123456789')), 0xCBF43926);
  });

  test('crc32 is resumable with a seed', () {
    final a = utf8.encode('12345');
    final b = utf8.encode('6789');
    expect(crc32(b, crc32(a)), 0xCBF43926);
  });
}
```

```dart
// test/dfu/secure_dfu_test.dart
import 'dart:typed_data';

import 'package:chameleon/src/dfu/dfu_package.dart';
import 'package:chameleon/src/dfu/fake_bootloader.dart';
import 'package:chameleon/src/dfu/secure_dfu.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/session/cancel_token.dart';
import 'package:test/test.dart';

import 'proto_builder.dart';

DfuImage image(Uint8List bin, {int hw = 0}) =>
    DfuImage(kind: DfuImageKind.application, bin: bin, dat: buildInitPacket(bin: bin, hwVersion: hw));

void main() {
  final bin = Uint8List.fromList(List.generate(10 * 1024 + 37, (i) => (i * 7) & 0xFF));

  test('flashes a firmware image in objects and 20-byte packets', () async {
    final bl = FakeBootloader(maxObjectSize: 4096);
    final ch = FakeDfuChannel(bl, maxDataWrite: 20);
    final progress = <DfuProgress>[];
    await SecureDfu(ch).run(image(bin), onProgress: progress.add);
    expect(bl.flashed, bin);
    expect(bl.init!.appSize, bin.length);
    expect(bl.completed, isTrue);
    expect(progress.last.stage, DfuStage.done);
    expect(progress.last.fraction, 1.0);
    final sent = progress.map((p) => p.bytesSent).toList();
    for (var i = 1; i < sent.length; i++) {
      expect(sent[i], greaterThanOrEqualTo(sent[i - 1]));
    }
    expect(bl.executedDataObjects, 3);
  });

  test('bootloader rejecting the hardware version is a DfuError', () async {
    final bl = FakeBootloader(expectedHwVersion: 1);
    final ch = FakeDfuChannel(bl);
    await expectLater(
      SecureDfu(ch).run(image(bin, hw: 0)),
      throwsA(isA<DfuError>().having((e) => e.result, 'result', 0x0A)),
    );
  });

  test('a CRC mismatch is a DfuError', () async {
    final bl = FakeBootloader()..corruptNextCrc();
    await expectLater(SecureDfu(FakeDfuChannel(bl)).run(image(bin)),
        throwsA(isA<DfuError>().having((e) => e.message, 'message', contains('CRC'))));
  });

  test('a failed create is reported with opcode and result', () async {
    final bl = FakeBootloader()..failNextCreate();
    await expectLater(SecureDfu(FakeDfuChannel(bl)).run(image(bin)),
        throwsA(isA<DfuError>().having((e) => e.opcode, 'opcode', 0x01)));
  });

  test('missing response times out as a DfuError', () async {
    final ch = FakeDfuChannel(FakeBootloader())..dropNextResponse();
    await expectLater(
      SecureDfu(ch, responseTimeout: const Duration(milliseconds: 50)).run(image(bin)),
      throwsA(isA<DfuError>().having((e) => e.message, 'message', contains('timed out'))),
    );
  });

  test('cancellation stops the transfer', () async {
    final bl = FakeBootloader();
    final ch = FakeDfuChannel(bl, latency: const Duration(milliseconds: 1));
    final token = CancelToken();
    final run = SecureDfu(ch).run(image(bin), cancel: token, onProgress: (p) {
      if (p.stage == DfuStage.firmware && p.bytesSent > 100) token.cancel();
    });
    await expectLater(run, throwsA(isA<CommandCancelled>()));
    expect(bl.completed, isFalse);
  });

  test('a mismatched image hash is refused before any transfer', () async {
    final tampered = Uint8List.fromList(bin)..[0] ^= 1;
    final img = DfuImage(kind: DfuImageKind.application, bin: tampered, dat: buildInitPacket(bin: bin));
    final bl = FakeBootloader();
    await expectLater(SecureDfu(FakeDfuChannel(bl)).run(img), throwsA(isA<DfuError>()));
    expect(bl.init, isNull);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/dfu`
Expected: FAIL on the new files.

- [ ] **Step 3: Implement**

```dart
// lib/src/dfu/crc32.dart
final List<int> _table = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

/// IEEE CRC-32 as used by Nordic Secure DFU. Pass the previous value as
/// [seed] to continue over more data.
int crc32(List<int> bytes, [int seed = 0]) {
  var c = seed ^ 0xFFFFFFFF;
  for (final b in bytes) {
    c = _table[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
```

```dart
// lib/src/dfu/dfu_channel.dart
import 'dart:typed_data';

/// The two DFU endpoints: control point (with responses) and data packets.
abstract interface class DfuChannel {
  int get maxDataWrite;
  Future<void> writeControl(Uint8List bytes);
  Future<void> writeData(Uint8List bytes);
  Stream<Uint8List> get responses;
  Future<void> close();
}
```

```dart
// lib/src/dfu/secure_dfu.dart
import 'dart:async';
import 'dart:typed_data';

import '../protocol/errors.dart';
import '../session/cancel_token.dart';
import 'crc32.dart';
import 'dfu_channel.dart';
import 'dfu_package.dart';

abstract final class DfuOp {
  static const int create = 0x01;
  static const int setPrn = 0x02;
  static const int calcCrc = 0x03;
  static const int execute = 0x04;
  static const int select = 0x06;
  static const int response = 0x60;
  static const int resultSuccess = 0x01;
  static const int typeCommand = 1;
  static const int typeData = 2;
}

enum DfuStage { init, firmware, done }

final class DfuProgress {
  const DfuProgress(this.stage, this.bytesSent, this.bytesTotal);
  final DfuStage stage;
  final int bytesSent;
  final int bytesTotal;
  double get fraction => bytesTotal == 0 ? 1.0 : bytesSent / bytesTotal;
}

/// Nordic Secure DFU protocol v1 over an abstract channel (spec 4.5).
final class SecureDfu {
  SecureDfu(this._channel, {this.responseTimeout = const Duration(seconds: 30)});

  final DfuChannel _channel;
  final Duration responseTimeout;

  Future<void> run(
    DfuImage image, {
    void Function(DfuProgress)? onProgress,
    CancelToken? cancel,
  }) async {
    if (!image.hashMatches) throw DfuError('image hash does not match init packet');
    final responses = StreamQueue(_channel.responses);
    try {
      await _sendObject(
        responses,
        type: DfuOp.typeCommand,
        data: image.dat,
        stage: DfuStage.init,
        onProgress: onProgress,
        cancel: cancel,
      );
      await _sendObject(
        responses,
        type: DfuOp.typeData,
        data: image.bin,
        stage: DfuStage.firmware,
        onProgress: onProgress,
        cancel: cancel,
      );
      onProgress?.call(DfuProgress(DfuStage.done, image.bin.length, image.bin.length));
    } finally {
      await responses.cancel();
    }
  }

  Future<void> _sendObject(
    StreamQueue<Uint8List> responses, {
    required int type,
    required Uint8List data,
    required DfuStage stage,
    void Function(DfuProgress)? onProgress,
    CancelToken? cancel,
  }) async {
    final select = await _request(responses, DfuOp.select, [type]);
    final maxSize = _u32le(select, 0);
    await _request(responses, DfuOp.setPrn, [0, 0]);
    var offset = 0;
    var crc = 0;
    onProgress?.call(DfuProgress(stage, 0, data.length));
    while (offset < data.length) {
      _checkCancel(cancel);
      final objLen = (data.length - offset).clamp(0, maxSize);
      await _request(responses, DfuOp.create, [type, ..._le32(objLen)]);
      final objEnd = offset + objLen;
      var pos = offset;
      while (pos < objEnd) {
        _checkCancel(cancel);
        final end = (pos + _channel.maxDataWrite).clamp(0, objEnd);
        await _channel.writeData(Uint8List.sublistView(data, pos, end));
        pos = end;
      }
      crc = crc32(Uint8List.sublistView(data, offset, objEnd), crc);
      final crcResp = await _request(responses, DfuOp.calcCrc, const []);
      final devOffset = _u32le(crcResp, 0);
      final devCrc = _u32le(crcResp, 4);
      if (devOffset != objEnd || devCrc != crc) {
        throw DfuError('CRC mismatch at $objEnd: device offset $devOffset crc '
            '0x${devCrc.toRadixString(16)} expected 0x${crc.toRadixString(16)}');
      }
      await _request(responses, DfuOp.execute, const []);
      offset = objEnd;
      onProgress?.call(DfuProgress(stage, offset, data.length));
    }
  }

  Future<Uint8List> _request(StreamQueue<Uint8List> responses, int opcode, List<int> payload) async {
    await _channel.writeControl(Uint8List.fromList([opcode, ...payload]));
    final Uint8List r;
    try {
      r = await responses.next.timeout(responseTimeout);
    } on TimeoutException {
      throw DfuError('opcode 0x${opcode.toRadixString(16)} timed out', opcode: opcode);
    }
    if (r.length < 3 || r[0] != DfuOp.response || r[1] != opcode) {
      throw DfuError('unexpected DFU response ${r.toList()}', opcode: opcode);
    }
    if (r[2] != DfuOp.resultSuccess) {
      throw DfuError('opcode 0x${opcode.toRadixString(16)} failed with result 0x${r[2].toRadixString(16)}',
          opcode: opcode, result: r[2]);
    }
    return Uint8List.sublistView(r, 3);
  }

  void _checkCancel(CancelToken? c) {
    if (c?.isCancelled ?? false) throw const CommandCancelled();
  }

  static int _u32le(Uint8List b, int o) =>
      b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

  static List<int> _le32(int v) => [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];
}

/// Small pull-based queue over a stream (avoids a dependency on
/// package:async's StreamQueue).
final class StreamQueue<T> {
  StreamQueue(Stream<T> stream) {
    _sub = stream.listen(
      (e) {
        final w = _waiters.isEmpty ? null : _waiters.removeAt(0);
        if (w != null) {
          w.complete(e);
        } else {
          _buffer.add(e);
        }
      },
      onError: (Object e) {
        final w = _waiters.isEmpty ? null : _waiters.removeAt(0);
        w?.completeError(e);
      },
    );
  }

  late final StreamSubscription<T> _sub;
  final List<T> _buffer = [];
  final List<Completer<T>> _waiters = [];

  Future<T> get next {
    if (_buffer.isNotEmpty) return Future.value(_buffer.removeAt(0));
    final c = Completer<T>();
    _waiters.add(c);
    return c.future;
  }

  Future<void> cancel() => _sub.cancel();
}
```

```dart
// lib/src/dfu/fake_bootloader.dart
import 'dart:async';
import 'dart:typed_data';

import 'crc32.dart';
import 'dfu_channel.dart';
import 'dfu_package.dart';
import 'secure_dfu.dart';

/// The bootloader side of Secure DFU, enough to prove SecureDfu and to back
/// FakeDevice's bootloader mode.
final class FakeBootloader {
  FakeBootloader({this.maxObjectSize = 4096, this.expectedHwVersion = 0});

  final int maxObjectSize;
  final int expectedHwVersion;

  final BytesBuilder _command = BytesBuilder();
  final BytesBuilder _data = BytesBuilder();
  int _selected = 0;
  int _pendingSize = 0;
  int _pendingReceived = 0;
  bool _failNextCreate = false;
  bool _corruptNextCrc = false;
  InitPacket? _init;
  int executedDataObjects = 0;
  bool completed = false;

  InitPacket? get init => _init;
  Uint8List get flashed => _data.toBytes();

  void failNextCreate() => _failNextCreate = true;
  void corruptNextCrc() => _corruptNextCrc = true;

  BytesBuilder get _buf => _selected == DfuOp.typeCommand ? _command : _data;

  Uint8List handleControl(Uint8List req) {
    final op = req[0];
    List<int> ok([List<int> payload = const []]) => [DfuOp.response, op, DfuOp.resultSuccess, ...payload];
    List<int> fail(int result) => [DfuOp.response, op, result];
    switch (op) {
      case DfuOp.select:
        _selected = req[1];
        final bytes = _buf.toBytes();
        final max = _selected == DfuOp.typeCommand ? 512 : maxObjectSize;
        return Uint8List.fromList(ok([..._le(max), ..._le(bytes.length), ..._le(crc32(bytes))]));
      case DfuOp.setPrn:
        return Uint8List.fromList(ok());
      case DfuOp.create:
        if (_failNextCreate) {
          _failNextCreate = false;
          return Uint8List.fromList(fail(0x04));
        }
        _selected = req[1];
        _pendingSize = req[2] | (req[3] << 8) | (req[4] << 16) | (req[5] << 24);
        _pendingReceived = 0;
        if (_selected == DfuOp.typeCommand) _command.clear();
        return Uint8List.fromList(ok());
      case DfuOp.calcCrc:
        final bytes = _buf.toBytes();
        var crc = crc32(bytes);
        if (_corruptNextCrc) {
          _corruptNextCrc = false;
          crc ^= 0xFFFF;
        }
        return Uint8List.fromList(ok([..._le(bytes.length), ..._le(crc)]));
      case DfuOp.execute:
        if (_pendingReceived != _pendingSize) return Uint8List.fromList(fail(0x05));
        if (_selected == DfuOp.typeCommand) {
          final parsed = InitPacket.parse(_command.toBytes());
          if (parsed.hwVersion != expectedHwVersion) return Uint8List.fromList(fail(0x0A));
          _init = parsed;
          _data.clear();
        } else {
          executedDataObjects++;
          if (_init != null && _data.length == _init!.appSize) completed = true;
        }
        return Uint8List.fromList(ok());
      default:
        return Uint8List.fromList(fail(0x02));
    }
  }

  void handleData(Uint8List bytes) {
    _buf.add(bytes);
    _pendingReceived += bytes.length;
  }

  static List<int> _le(int v) => [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];
}

/// Not final: FakeDevice extends it to reboot on close.
class FakeDfuChannel implements DfuChannel {
  FakeDfuChannel(this.bootloader, {this.maxDataWrite = 20, this.latency = Duration.zero});

  final FakeBootloader bootloader;
  @override
  final int maxDataWrite;
  final Duration latency;
  final StreamController<Uint8List> _responses = StreamController.broadcast();
  bool _closed = false;
  int _drop = 0;

  bool get isClosed => _closed;

  void dropNextResponse() => _drop++;

  @override
  Stream<Uint8List> get responses => _responses.stream;

  @override
  Future<void> writeControl(Uint8List bytes) async {
    await Future<void>.delayed(latency);
    final r = bootloader.handleControl(bytes);
    if (_drop > 0) {
      _drop--;
      return;
    }
    _responses.add(r);
  }

  @override
  Future<void> writeData(Uint8List bytes) async {
    if (bytes.length > maxDataWrite) throw StateError('write larger than maxDataWrite');
    await Future<void>.delayed(latency);
    bootloader.handleData(bytes);
  }

  @override
  Future<void> close() async {
    _closed = true;
    await _responses.close();
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `mise x -- dart test test/dfu`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): add pure-Dart Secure DFU with a fake bootloader

One implementation for every platform; channels differ (spec 4.5)."
```

---

### Task 20: DFU orchestrator and FakeDevice bootloader mode

**Files:**
- Create: `lib/src/dfu/dfu_orchestrator.dart`, `test/dfu/dfu_orchestrator_test.dart`
- Modify: `lib/src/fake/fake_device.dart`, `lib/src/fake/fake_scanner.dart`

**Interfaces:**
- Produces:

```dart
enum DfuPhase { checking, enteringBootloader, findingBootloader, transferring, findingDevice, done }
sealed class DfuEvent; DfuPhaseChanged(DfuPhase phase); DfuProgressed(DfuProgress progress); DfuCompleted(DiscoveredDevice? device); DfuFailed(ChameleonException error)
typedef DfuChannelOpener = Future<DfuChannel> Function(DiscoveredDevice bootloader);
final class DfuOrchestrator {
  DfuOrchestrator({required List<DeviceScanner> scanners, required DfuChannelOpener openChannel, Duration scanTimeout = 30s});
  Stream<DfuEvent> run({DeviceSession? session, required DfuPackage package, DiscoveredDevice? bootloader, CancelToken? cancel});
}
// FakeDevice additions
FakeBootloader get bootloader; bool get inBootloader; FakeDfuChannel openDfuChannel({int maxDataWrite = 20}); void leaveBootloader();
// FakeScanner addition
factory FakeScanner.forDevice(FakeDevice device)  // lists the bootloader entry while inBootloader, else emulatedUltra
```

- [ ] **Step 1: Write the failing tests**

```dart
// test/dfu/dfu_orchestrator_test.dart
import 'dart:typed_data';

import 'package:chameleon/src/dfu/dfu_orchestrator.dart';
import 'package:chameleon/src/dfu/dfu_package.dart';
import 'package:chameleon/src/fake/fake_device.dart';
import 'package:chameleon/src/fake/fake_firmware.dart';
import 'package:chameleon/src/fake/fake_scanner.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/session/connection_state.dart';
import 'package:chameleon/src/session/device_session.dart';
import 'package:test/test.dart';

import 'proto_builder.dart';

DfuPackage package(Uint8List bin, {int hw = 0}) =>
    DfuPackage.fromZip(buildZip(bin: bin, dat: buildInitPacket(bin: bin, hwVersion: hw)));

void main() {
  final bin = Uint8List.fromList(List.generate(6000, (i) => i & 0xFF));

  DfuOrchestrator orchestratorFor(FakeDevice device) => DfuOrchestrator(
        scanners: [FakeScanner.forDevice(device)],
        openChannel: (_) async => device.openDfuChannel(),
        scanTimeout: const Duration(seconds: 1),
      );

  test('updates a connected device end to end and finds it again', () async {
    final device = FakeDevice();
    final s = DeviceSession(device, idlePollInterval: const Duration(days: 1), batteryDelay: Duration.zero);
    await s.open();
    final events = await orchestratorFor(device).run(session: s, package: package(bin)).toList();
    expect(events.whereType<DfuPhaseChanged>().map((e) => e.phase), [
      DfuPhase.checking,
      DfuPhase.enteringBootloader,
      DfuPhase.findingBootloader,
      DfuPhase.transferring,
      DfuPhase.findingDevice,
      DfuPhase.done,
    ]);
    expect(events.last, isA<DfuCompleted>().having((e) => e.device, 'device', FakeScanner.emulatedUltra));
    expect(device.bootloader.flashed, bin);
    expect(device.inBootloader, isFalse);
    expect((s.connectionState.value as SessionDisconnected).cause, DisconnectCause.expected);
  });

  test('refuses a package for the other model before touching the device', () async {
    final device = FakeDevice();
    final s = DeviceSession(device, idlePollInterval: const Duration(days: 1), batteryDelay: Duration.zero);
    await s.open();
    final events = await orchestratorFor(device).run(session: s, package: package(bin, hw: 1)).toList();
    expect(events.last, isA<DfuFailed>().having((e) => e.error, 'error', isA<DfuError>()));
    expect(device.firmware.bootloaderRequested, isFalse);
    await s.close();
  });

  test('recovers a device already in the bootloader without a session', () async {
    final device = FakeDevice();
    await device.open();
    await device.write(Uint8List.fromList([0x11, 0xEF, 0x03, 0xF2, 0, 0, 0, 0, 0x0B, 0x00]));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(device.inBootloader, isTrue);
    final events = await orchestratorFor(device)
        .run(package: package(bin), bootloader: FakeScanner.emulatedBootloader)
        .toList();
    expect(events.whereType<DfuPhaseChanged>().first.phase, DfuPhase.transferring);
    expect(events.last, isA<DfuCompleted>());
    expect(device.bootloader.flashed, bin);
  });

  test('works on a limited session (outdated firmware)', () async {
    final device = FakeDevice(firmware: FakeFirmware(FakeFirmwareConfig.preTwoPointZero()));
    final s = DeviceSession(device, idlePollInterval: const Duration(days: 1), batteryDelay: Duration.zero);
    await s.open();
    expect(s.connectionState.value, isA<SessionLimited>());
    final events = await orchestratorFor(device).run(session: s, package: package(bin)).toList();
    expect(events.last, isA<DfuCompleted>());
  });

  test('bootloader not found is a DfuFailed', () async {
    final device = FakeDevice();
    final s = DeviceSession(device, idlePollInterval: const Duration(days: 1), batteryDelay: Duration.zero);
    await s.open();
    final orchestrator = DfuOrchestrator(
      scanners: [FakeScanner(devices: const [])],
      openChannel: (_) async => device.openDfuChannel(),
      scanTimeout: const Duration(milliseconds: 50),
    );
    final events = await orchestrator.run(session: s, package: package(bin)).toList();
    expect(events.last, isA<DfuFailed>().having((e) => e.error.message, 'message', contains('bootloader')));
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/dfu/dfu_orchestrator_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Add to `FakeDevice`:

```dart
  final FakeBootloader bootloader = FakeBootloader();

  bool get inBootloader => firmware.bootloaderRequested;

  /// A DFU channel to this device's bootloader. Closing it reboots the
  /// device back into the application.
  FakeDfuChannel openDfuChannel({int maxDataWrite = 20}) {
    if (!inBootloader) throw const DeviceNotFound('device is not in bootloader');
    return _RebootingChannel(this, maxDataWrite);
  }

  void leaveBootloader() => firmware.bootloaderRequested = false;
```

and, in the same file:

```dart
final class _RebootingChannel extends FakeDfuChannel {
  _RebootingChannel(this._device, int maxDataWrite)
      : super(_device.bootloader, maxDataWrite: maxDataWrite);
  final FakeDevice _device;

  @override
  Future<void> close() async {
    await super.close();
    _device.leaveBootloader();
  }
}
```

Import `../dfu/fake_bootloader.dart` in `fake_device.dart`; `bootloaderRequested` on `FakeFirmware` is already a plain settable field.

Add to `FakeScanner`:

```dart
  FakeScanner.forDevice(FakeDevice device)
      : devices = const [],
        _provider = (() => [device.inBootloader ? emulatedBootloader : emulatedUltra]);

  final List<DiscoveredDevice> Function()? _provider;

  @override
  Stream<List<DiscoveredDevice>> scan() =>
      Stream.value(List.unmodifiable(_provider?.call() ?? devices));
```

(Give the default constructor `_provider = null`.)

```dart
// lib/src/dfu/dfu_orchestrator.dart
import 'dart:async';

import '../model/enums.dart';
import '../protocol/errors.dart';
import '../session/cancel_token.dart';
import '../session/device_session.dart';
import '../transport/scanner.dart';
import 'dfu_channel.dart';
import 'dfu_package.dart';
import 'secure_dfu.dart';

enum DfuPhase { checking, enteringBootloader, findingBootloader, transferring, findingDevice, done }

sealed class DfuEvent {
  const DfuEvent();
}

final class DfuPhaseChanged extends DfuEvent {
  const DfuPhaseChanged(this.phase);
  final DfuPhase phase;
}

final class DfuProgressed extends DfuEvent {
  const DfuProgressed(this.progress);
  final DfuProgress progress;
}

final class DfuCompleted extends DfuEvent {
  const DfuCompleted(this.device);
  final DiscoveredDevice? device;
}

final class DfuFailed extends DfuEvent {
  const DfuFailed(this.error);
  final ChameleonException error;
}

typedef DfuChannelOpener = Future<DfuChannel> Function(DiscoveredDevice bootloader);

/// Runs a whole update: model check, reboot, find bootloader, transfer,
/// find the device again (spec 4.5). Starts from a session or from a device
/// already advertising as a bootloader.
final class DfuOrchestrator {
  DfuOrchestrator({
    required this.scanners,
    required this.openChannel,
    this.scanTimeout = const Duration(seconds: 30),
  });

  final List<DeviceScanner> scanners;
  final DfuChannelOpener openChannel;
  final Duration scanTimeout;

  Stream<DfuEvent> run({
    DeviceSession? session,
    required DfuPackage package,
    DiscoveredDevice? bootloader,
    CancelToken? cancel,
  }) async* {
    try {
      var target = bootloader;
      if (target == null) {
        if (session == null) throw DfuError('need a session or a bootloader device');
        yield const DfuPhaseChanged(DfuPhase.checking);
        final model = session.deviceInfo.value?.model;
        final wanted = package.targetModel;
        if (model != null && wanted != null && model != wanted) {
          throw DfuError('package is for the ${wanted.name}, device is a ${model.name}');
        }
        for (final img in package.images) {
          if (!img.hashMatches) throw DfuError('${img.kind.name} image hash mismatch');
        }
        yield const DfuPhaseChanged(DfuPhase.enteringBootloader);
        await session.firmware.enterBootloader();
        yield const DfuPhaseChanged(DfuPhase.findingBootloader);
        target = await _find((d) => d.isBootloader, cancel);
        if (target == null) throw DfuError('bootloader not found within $scanTimeout');
      }
      yield const DfuPhaseChanged(DfuPhase.transferring);
      final channel = await openChannel(target);
      try {
        final dfu = SecureDfu(channel);
        final controller = StreamController<DfuEvent>();
        final done = Future(() async {
          for (final img in package.images) {
            await dfu.run(img, cancel: cancel, onProgress: (p) => controller.add(DfuProgressed(p)));
          }
        }).whenComplete(controller.close);
        yield* controller.stream;
        await done;
      } finally {
        await channel.close();
      }
      yield const DfuPhaseChanged(DfuPhase.findingDevice);
      final device = await _find((d) => !d.isBootloader, cancel);
      yield const DfuPhaseChanged(DfuPhase.done);
      yield DfuCompleted(device);
    } on ChameleonException catch (e) {
      yield DfuFailed(e);
    }
  }

  Future<DiscoveredDevice?> _find(bool Function(DiscoveredDevice) test, CancelToken? cancel) async {
    final deadline = DateTime.now().add(scanTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (cancel?.isCancelled ?? false) throw const CommandCancelled();
      for (final scanner in scanners) {
        final lists = await scanner.scan().timeout(scanTimeout, onTimeout: (sink) => sink.close()).toList();
        for (final list in lists) {
          for (final d in list) {
            if (test(d)) return d;
          }
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return null;
  }
}
```

Note: `DeviceModel` is imported for `.name`; keep the import even if the analyzer marks it unused after edits, or reference it explicitly.

- [ ] **Step 4: Run to verify pass**

Run: `mise x -- dart test`
Expected: the whole package passes.

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): add DfuOrchestrator and FakeDevice bootloader mode

Starts from a session or from a device already in the bootloader, so a
failed update is always recoverable (spec 5.6)."
```

---

### Task 21: Public barrel, firmware matrix sweep, coverage and close

**Files:**
- Modify: `lib/chameleon.dart`
- Create: `test/public_api_test.dart`, `test/firmware_matrix_test.dart`, `packages/chameleon/README.md`
- Modify: `AGENTS.md`, `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, `tasks/lessons.md`

- [ ] **Step 1: Write the failing tests**

```dart
// test/public_api_test.dart
// Uses only the public barrel. Fails to compile if an export is missing.
import 'package:chameleon/chameleon.dart';
import 'package:test/test.dart';

void main() {
  test('an app can connect, read slots and scan using only public API', () async {
    final device = FakeDevice();
    final session = DeviceSession(device, idlePollInterval: const Duration(days: 1), batteryDelay: Duration.zero);
    await session.open();
    expect(session.connectionState.value, isA<SessionReady>());
    final slots = await session.slots.refresh();
    expect(slots[0].hfType, TagType.mifare1k);
    expect(await session.reader.scan14a(), isEmpty);
    final dump = DumpFormats.parse(await session.emulator.readMf1Blocks(0, 64), TagType.mifare1k);
    expect(dump, isA<MifareClassicDump>());
    final scanners = <DeviceScanner>[FakeScanner()];
    expect((await scanners.first.scan().first).single, FakeScanner.emulatedUltra);
    expect(const HfTagNotFound(), isA<DeviceError>());
    expect(FrameLog, isNotNull);
    expect(DfuOrchestrator, isNotNull);
    expect(CancelToken(), isNotNull);
    await session.close();
  });
}
```

```dart
// test/firmware_matrix_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:test/test.dart';

void main() {
  final matrix = <String, FakeFirmwareConfig>{
    'ultra 2.2': FakeFirmwareConfig.ultra22(),
    'ultra 2.0': FakeFirmwareConfig.ultra20(),
    'lite 2.2': FakeFirmwareConfig.lite22(),
  };

  for (final entry in matrix.entries) {
    test('${entry.key}: ready, slots loaded, settings loaded', () async {
      final device = FakeDevice(firmware: FakeFirmware(entry.value), chunkSize: 7, latency: const Duration(milliseconds: 1));
      final s = DeviceSession(device, idlePollInterval: const Duration(days: 1), batteryDelay: Duration.zero);
      final errors = <ChameleonException>[];
      s.backgroundErrors.listen(errors.add);
      await s.open();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(s.connectionState.value, isA<SessionReady>());
      expect(s.slots.current.length, 8);
      expect(s.settings.current, isNotNull);
      expect(errors, isEmpty);
      expect(s.deviceInfo.value!.capabilities.hasReader, entry.value.model == DeviceModel.ultra);
      await s.close();
    });
  }

  test('lite never exposes reader operations', () async {
    final s = DeviceSession(FakeDevice(firmware: FakeFirmware(FakeFirmwareConfig.lite22())),
        idlePollInterval: const Duration(days: 1), batteryDelay: Duration.zero);
    await s.open();
    await expectLater(s.reader.scan14a(), throwsA(isA<ReaderUnavailable>()));
    await s.close();
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/public_api_test.dart test/firmware_matrix_test.dart`
Expected: FAIL to compile (barrel exports nothing yet).

- [ ] **Step 3: Write the barrel**

```dart
// lib/chameleon.dart
/// Clean-room Dart SDK for the Chameleon Ultra and Chameleon Lite.
///
/// Pure Dart: this library never imports Flutter. Commands are internal;
/// use the facades on [DeviceSession].
library;

export 'src/codec/frame.dart' show Frame;
export 'src/codec/frame_decoder.dart' show DecodeDiagnostic, ResyncDiagnostic, BadLrcDiagnostic, OversizedFrameDiagnostic;
export 'src/dfu/dfu_channel.dart';
export 'src/dfu/dfu_orchestrator.dart';
export 'src/dfu/dfu_package.dart';
export 'src/dfu/fake_bootloader.dart';
export 'src/dfu/secure_dfu.dart' show DfuStage, DfuProgress, SecureDfu;
export 'src/dump/dump_format.dart';
export 'src/dump/em410x.dart';
export 'src/dump/mifare_classic.dart';
export 'src/dump/ultralight.dart';
export 'src/fake/fake_card.dart';
export 'src/fake/fake_device.dart';
export 'src/fake/fake_firmware.dart' show FakeFirmware, FakeFirmwareConfig, FakeSlot;
export 'src/fake/fake_scanner.dart';
export 'src/model/enums.dart';
export 'src/model/models.dart';
export 'src/protocol/errors.dart';
export 'src/protocol/status.dart';
export 'src/session/cancel_token.dart';
export 'src/session/connection_state.dart';
export 'src/session/device_session.dart';
export 'src/session/facades/device.dart';
export 'src/session/facades/emulator.dart';
export 'src/session/facades/firmware.dart';
export 'src/session/facades/reader.dart';
export 'src/session/facades/settings.dart';
export 'src/session/facades/slots.dart';
export 'src/session/reader_lease.dart';
export 'src/session/state_stream.dart';
export 'src/transport/frame_log.dart';
export 'src/transport/scanner.dart';
export 'src/transport/transport.dart';

const String chameleonSdkVersion = '0.1.0';
```

Delete the placeholder `test/smoke_test.dart` from Phase 0 if it duplicates the version check, or keep it; both are fine.

- [ ] **Step 4: Run everything with coverage**

```bash
cd packages/chameleon
mise x -- dart test --coverage=coverage
mise x -- dart pub global activate coverage
mise x -- dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --packages=.dart_tool/package_config.json --report-on=lib
```

Then summarise line coverage per file (for example with `lcov --summary coverage/lcov.info` if installed, or a short Dart script over lcov.info). Expected: every file under `lib/src` above 85 percent except the command catalog files, whose raw-only entries are not exercised; list any file below that in the closing commit message.

- [ ] **Step 5: Boundary and format checks**

Run from the worktree root: `mise x -- dart run tool/dep_lint.dart && mise x -- dart format --set-exit-if-changed packages/chameleon && mise x -- dart analyze --fatal-infos packages/chameleon && bash tool/check_codegen.sh`
Expected: all green.

- [ ] **Step 6: README and status**

Write `packages/chameleon/README.md`: what the package is (clean-room, pure Dart), the layer diagram from this plan's file structure, a ten-line usage example (open a session on `FakeDevice`, read slots, scan), the list of `hardware-validate` items, and the statement that commands are internal.

Update `AGENTS.md` "Current status" to say Phase 1 is complete and the next steps are Phase 2 (design system) and Phase 3 (transports). Tick Phase 1 in the roadmap. Add lessons to `tasks/lessons.md`.

- [ ] **Step 7: Commit**

```bash
git add packages/chameleon AGENTS.md docs tasks
git commit -m "feat(chameleon): publish the SDK barrel, firmware matrix tests and README

Closes Phase 1. Every spec 4.3 behavior has a named test; commands stay
internal to the package."
```

---

## Self-review notes

- Spec coverage: 3.1 (Tasks 1-2), 3.2 (4, 6-8), 3.3 (3), 3.4 (5), 3.5 (17), 3.6 (1-2, 6-8), 4.1 (9), 4.2 (9, 11), 4.3 (12-16), 4.4 (10-11, 20), 4.5 (18-20), 8.1 (15-16), 8.2 dump formats (17), 9 error types (3, 18), 10 SDK tests and matrix (21). Device identity persistence and merge (4.2) is app-side and lands in Phase 4; the SDK supplies `DeviceIdentity` and `DiscoveredDevice`.
- Known simplifications to revisit on hardware: 2012 bit ordering, 4006 record layout, 1034 length, 6xxx success status, init packet hash byte order, serial control lines.
- Type names used across tasks: `Frame`, `Command<R>`, `VoidCommand`, `RawCommand`, `DeviceError`, `TransportError`, `CommandTimeout`, `CommandCancelled`, `SessionNotReady`, `ReaderUnavailable`, `DfuError`, `Transport`, `TransportState`, `CloseCause`, `DeviceScanner`, `DiscoveredDevice`, `FrameLog`, `FakeFirmware`, `FakeFirmwareConfig`, `FakeDevice`, `FakeScanner`, `FakeCard`, `FakeMf1Card`, `FakeLfCard`, `CancelToken`, `CommandDispatcher`, `StateStream`, `ConnectionState` and its five subclasses, `DisconnectCause`, `DeviceSession`, `ReaderLease`, the six facades, `Mf1DumpReadResult`, `DumpFormat`, `DumpFormats`, `CardDump`, `MifareClassicDump`, `UltralightDump`, `Em410xDump`, `InitPacket`, `DfuImage`, `DfuPackage`, `DfuChannel`, `SecureDfu`, `DfuProgress`, `DfuStage`, `FakeBootloader`, `FakeDfuChannel`, `DfuOrchestrator`, `DfuEvent` and subclasses, `DfuPhase`.

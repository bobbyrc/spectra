# chameleon

Clean-room Dart SDK for the Chameleon Ultra and Chameleon Lite: framing,
commands, models, a device session and Nordic Secure DFU. Pure Dart — this
package never imports Flutter, so all of it is unit-testable without a device
and without a Flutter test binding.

Clean room: every byte of wire format here comes from the official firmware
documentation, condensed in `docs/research/chameleon-protocol.md`. The GPL-3.0
reference app was used to cross-check behaviour, never as a source of code.

## Layers

```
chameleon.dart                the public barrel; nothing else is public API
  src/session/                DeviceSession, the state machine, the six facades
  src/dump/                   dump formats (MIFARE Classic, Ultralight, EM410x)
  src/dfu/                    DFU package parsing, Secure DFU, the orchestrator
  src/commands/               the command catalog (internal)
  src/model/                  freezed models and enums
  src/protocol/               Command<R>, status codes, the error hierarchy
  src/codec/                  Frame, FrameDecoder, LRC, byte readers
  src/transport/              Transport, DeviceScanner, FrameLog (seams)
  src/fake/                   FakeDevice/FakeFirmware: the whole device, faked
```

An app talks to `DeviceSession` and its facades (`device`, `slots`,
`settings`, `emulator`, `reader`, `firmware`). **Commands are internal**
(spec 3.2): `session.send(Command)` exists for the SDK's own use and no
command class is exported, so a new device operation is a facade method here,
never a command built in app code. The firmware's raw status codes are
internal for the same reason (spec 3.3): a caller catches a typed
`DeviceError`, never compares an int.

A `DeviceSession` is single-use. Once its transport has gone — a link loss,
or `close()` — the session is spent and `open()` throws; reconnecting means
a new session over a new transport.

Transports are seams: `Transport` and `DeviceScanner` are implemented per
platform in `chameleon_flutter` (Phase 3). This package ships `FakeDevice`,
`FakeScanner` and `FakeBootloader`, which speak the real protocol, so every
feature can be built and tested with no hardware present.

## Usage

```dart
import 'package:chameleon/chameleon.dart';

Future<void> main() async {
  final session = DeviceSession(FakeDevice()); // a real Transport on device
  await session.open();
  if (session.connectionState.value is! SessionReady) return;

  final slots = await session.slots.refresh();
  print('slot 0 holds ${slots[0].hfType.name} "${slots[0].hfNick}"');

  for (final tag in await session.reader.scan14a()) {
    print('found ${tag.uidHex}');
  }
  await session.close();
}
```

`session.connectionState`, `deviceInfo`, `slotsState`, `activeSlot`,
`settingsState`, `battery` and `mode` are `StateStream`s: current value plus
changes. `close()` is mandatory — it is the only thing that closes them.

## Tests and coverage

`dart test` runs 320 tests with no hardware. Coverage of the hand-written
sources (2026-09-03, generated `models.freezed.dart` excluded) is 91.5 % of
lines: session 96.2 %, facades 97.3 %, codec 95.2 %, dfu 91.4 %, protocol
91.0 %, commands 89.5 %, fake 88.4 %, transport 84.4 %, dump 82.5 %. The
uncovered remainder is mostly catalog entries and `toString`s; the gate is a
green suite with a coverage report, not a percentage.

```bash
dart test --coverage=coverage
dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info \
  --packages=../../.dart_tool/package_config.json --report-on=lib
```

## Unverified on hardware

Anything derived from the reference app rather than the firmware docs is
tagged `hardware-validate` in a doc comment, and the tests that pin it carry
the `hardware-validate` tag (`dart test -t hardware-validate`). Open items,
tracked in `docs/hardware-checklist.md`:

- MF1 detection log (4006) record layout, 18 bytes per entry.
- `MifareClassicDump.uid`: block 0 is assumed to hold a 4-byte UID.
- The settings payload length (1034); decoded by its leading version byte.
- `hf14a_raw` (2010) option bit meanings.
- Check-keys-of-sectors (2012) sector and key A/B mask bit ordering.
- LF emulator id lengths for HID Prox, Viking, PAC, Jablotron and Idteck.
- ISO14443-4 commands (6000-6005) in full, including their success status.
- The DFU init packet's SHA-256 byte order (nrfutil writes it reversed).
- Whether executing an already-executed DFU object is a no-op on resume.

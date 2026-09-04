import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';

/// The cards the emulated Chameleon's reader "sees" (spec 7.5: every feature
/// has to work in emulator mode, and a read with nothing in the field is not
/// a working Read screen).
///
/// `FakeFirmware.present` is exactly the scripting hook spec 4.4 describes
/// (`packages/chameleon/lib/src/fake/fake_firmware.dart`); there is still
/// only one fake, at the transport level, and the real `DeviceSession` runs
/// above it.

/// The UID the demo MIFARE Classic answers with. Also what the screenshots
/// and the Phase 6 gate test look for.
final Uint8List demoMifareUid = Uint8List.fromList(<int>[
  0xDE,
  0xAD,
  0xBE,
  0xEF,
]);

/// EM410X_SCAN. The fake answers 3000, 3002, 3004 and 3014 from whichever
/// `FakeLfCard` is present (`fake_reader_handlers.dart`).
const int _em410xScanCommand = 3000;

final Uint8List demoEm410xId = Uint8List.fromList(<int>[
  0x12,
  0x34,
  0x56,
  0x78,
  0x9A,
]);

/// A fake with one card in each field.
FakeDevice buildEmulatedDevice() {
  final FakeFirmware firmware = FakeFirmware()
    ..present(FakeMf1Card.classic1k(uid: Uint8List.fromList(demoMifareUid)))
    ..present(FakeLfCard(_em410xScanCommand, Uint8List.fromList(demoEm410xId)));
  return FakeDevice(firmware: firmware);
}

/// The app's transport factory: the emulated device gets scripted cards,
/// every real device goes through `chameleon_flutter` untouched.
Transport emulatorAwareTransport(DiscoveredDevice device) =>
    device.kind == TransportKind.fake
    ? buildEmulatedDevice()
    : ChameleonTransports.transportFor(device);

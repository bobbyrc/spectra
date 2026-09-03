import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/emulator/demo_cards.dart';

void main() {
  test('the emulated device has a card in each field', () {
    final FakeDevice device = buildEmulatedDevice();
    expect(device.firmware.hfCard, isA<FakeMf1Card>());
    expect(device.firmware.lfCard, isA<FakeLfCard>());
  });

  test('the demo MIFARE Classic answers with the documented UID', () {
    final FakeDevice device = buildEmulatedDevice();
    final FakeMf1Card hf = device.firmware.hfCard! as FakeMf1Card;
    expect(hf.uid, demoMifareUid);
  });

  test('the demo EM410x answers with the documented id', () {
    final FakeDevice device = buildEmulatedDevice();
    final FakeLfCard lf = device.firmware.lfCard! as FakeLfCard;
    expect(lf.idBytes, demoEm410xId);
  });

  test('a plain FakeDevice (what an unpatched factory would return) has no '
      'cards in its field', () {
    // Ruling 4: proves the assertion above actually distinguishes
    // emulatorAwareTransport's behaviour from the bare `transportFor`
    // fake branch, which just returns `FakeDevice()`.
    final FakeFirmware bare = FakeFirmware();
    expect(bare.hfCard, isNull);
    expect(bare.lfCard, isNull);
  });

  test('a fake-kind device gets the scripted demo cards', () {
    final Transport transport = emulatorAwareTransport(
      FakeScanner.emulatedUltra,
    );
    expect(transport, isA<FakeDevice>());
    final FakeDevice device = transport as FakeDevice;
    expect(device.firmware.hfCard, isA<FakeMf1Card>());
    expect(device.firmware.lfCard, isA<FakeLfCard>());
  });

  test('a non-fake device kind still delegates to ChameleonTransports', () {
    // BleTransport's constructor only assigns fields — no plugin channel
    // call happens until a method is invoked on it — so constructing one
    // through the real factory here has no side effects.
    const DiscoveredDevice device = DiscoveredDevice(
      name: 'Some Real Ultra',
      kind: TransportKind.ble,
      transportId: '00:11:22:33:44:55',
    );
    final Transport transport = emulatorAwareTransport(device);
    expect(transport, isA<BleTransport>());
    expect(transport, isNot(isA<FakeDevice>()));
  });
}

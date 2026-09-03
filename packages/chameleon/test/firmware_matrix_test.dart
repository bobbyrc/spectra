// The firmware version matrix of spec 4.3, driven end to end through the
// public API: one row per firmware the connect handshake has to survive.
import 'package:chameleon/chameleon.dart';
import 'package:test/test.dart';

DeviceSession _sessionFor(FakeDevice device) => DeviceSession(
  device,
  idlePollInterval: const Duration(days: 1),
  batteryDelay: Duration.zero,
);

FakeDevice _deviceFor(FakeFirmwareConfig config) => FakeDevice(
  firmware: FakeFirmware(config),
  chunkSize: 7,
  latency: const Duration(milliseconds: 1),
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 100));

int _countOf(FakeDevice device, int command) =>
    device.received.where((f) => f.command == command).length;

void main() {
  group('supported firmware reaches ready', () {
    final matrix = <String, FakeFirmwareConfig Function()>{
      'ultra 2.2': FakeFirmwareConfig.ultra22,
      'ultra 2.0': FakeFirmwareConfig.ultra20,
      'lite 2.2': FakeFirmwareConfig.lite22,
    };

    for (final entry in matrix.entries) {
      test('${entry.key}: ready, slots loaded, settings loaded', () async {
        final config = entry.value();
        final device = _deviceFor(config);
        final s = _sessionFor(device);
        final errors = <ChameleonException>[];
        final sub = s.backgroundErrors.listen(errors.add);
        await s.open();
        await _settle();
        expect(s.connectionState.value, isA<SessionReady>());
        expect(s.slots.current, hasLength(8));
        expect(s.slots.current[0].hfNick, 'Fake 1K');
        expect(s.settings.current, isNotNull);
        expect(s.deviceInfo.value!.version, config.version);
        expect(s.deviceInfo.value!.model, config.model);
        expect(errors, isEmpty);
        expect(
          s.deviceInfo.value!.capabilities.hasReader,
          config.model == DeviceModel.ultra,
        );
        await sub.cancel();
        await s.close();
      });
    }
  });

  test('2.2 reads nicknames with GET_ALL_SLOT_NICKS (1038)', () async {
    final device = _deviceFor(FakeFirmwareConfig.ultra22());
    final s = _sessionFor(device);
    await s.open();
    await _settle();
    expect(_countOf(device, 1038), 1);
    expect(_countOf(device, 1008), 0);
    expect(s.slots.current[0].hfNick, 'Fake 1K');
    await s.close();
  });

  test('2.0 falls back to GET_SLOT_TAG_NICK (1008) per slot', () async {
    final device = _deviceFor(FakeFirmwareConfig.ultra20());
    final s = _sessionFor(device);
    await s.open();
    await _settle();
    expect(_countOf(device, 1038), 0);
    expect(_countOf(device, 1008), 16);
    expect(s.slots.current[0].hfNick, 'Fake 1K');
    await s.close();
  });

  test('lite never exposes reader operations', () async {
    final s = _sessionFor(_deviceFor(FakeFirmwareConfig.lite22()));
    await s.open();
    await _settle();
    expect(s.deviceInfo.value!.capabilities.hasReader, isFalse);
    await expectLater(s.acquireReaderMode(), throwsA(isA<ReaderUnavailable>()));
    await expectLater(s.reader.scan14a(), throwsA(isA<ReaderUnavailable>()));
    await s.close();
  });

  group('unsupported firmware lands in limited', () {
    final matrix = <String, (FakeFirmwareConfig Function(), UnsupportedReason)>{
      'pre-2.0': (
        FakeFirmwareConfig.preTwoPointZero,
        UnsupportedReason.preTwoPointZero,
      ),
      'legacy 0.1': (
        FakeFirmwareConfig.legacy01,
        UnsupportedReason.legacyMustUpdate,
      ),
    };

    for (final entry in matrix.entries) {
      test(
        '${entry.key}: limited, and can still enter the bootloader',
        () async {
          final device = _deviceFor(entry.value.$1());
          final s = _sessionFor(device);
          await s.open();
          await _settle();
          final state = s.connectionState.value;
          expect(state, isA<SessionLimited>());
          expect((state as SessionLimited).reason, entry.value.$2);
          // Ordinary work is refused, the update path is not.
          await expectLater(s.slots.refresh(), throwsA(isA<SessionNotReady>()));
          await s.firmware.enterBootloader();
          expect(s.connectionState.value, isA<SessionUpdating>());
          expect(device.inBootloader, isTrue);
          await s.close();
        },
      );
    }
  });
}

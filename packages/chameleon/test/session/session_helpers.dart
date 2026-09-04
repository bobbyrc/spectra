// Shared scaffolding for the session tests: one definition of "wait a beat",
// one way to build a session over a fake, and one way to wait for the
// tolerant background load to finish.
import 'package:chameleon/chameleon.dart';

/// Lets pending microtasks and short timers run. Use
/// [awaitBackgroundLoad] instead when what is being waited for is the
/// background load: this is for everything else.
Future<void> settle([int ms = 20]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

/// A session over [device] with the idle poll effectively off and no battery
/// delay, which is what almost every test wants.
DeviceSession sessionFor(
  FakeDevice device, {
  Duration idlePollInterval = const Duration(days: 1),
  Duration batteryDelay = Duration.zero,
}) => DeviceSession(
  device,
  idlePollInterval: idlePollInterval,
  batteryDelay: batteryDelay,
);

/// A session over a fresh [FakeDevice] running [config], unless [device] is
/// given.
DeviceSession sessionForFirmware(
  FakeFirmwareConfig config, {
  FakeDevice? device,
}) => sessionFor(device ?? FakeDevice(firmware: FakeFirmware(config)));

/// Waits for the tolerant background load to finish: the battery read is its
/// last step, so a non-null battery means identity, mode, slots and settings
/// have all been attempted.
///
/// Throws rather than passing quietly if it never finishes, so a test that
/// waits for a load that cannot happen fails where it waited.
Future<void> awaitBackgroundLoad(
  DeviceSession session, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (session.battery.value == null) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError(
        'background load did not finish in $timeout '
        '(session is ${session.connectionState.value.runtimeType})',
      );
    }
    if (session.connectionState.value is SessionDisconnected) {
      throw StateError('session disconnected during the background load');
    }
    await settle(2);
  }
}

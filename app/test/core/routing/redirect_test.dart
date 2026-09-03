import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/routing/redirect.dart';
import 'package:spectra/core/routing/routes.dart';

const disconnected = SessionDisconnected(DisconnectCause.requested);
const connecting = SessionConnecting();
const limited = SessionLimited(UnsupportedReason.preTwoPointZero);
const updating = SessionUpdating();

SessionReady ready() => SessionReady(
  const DeviceInfo(
    model: DeviceModel.ultra,
    version: FirmwareVersion(major: 2, minor: 2),
    capabilities: Capabilities(<int>{}),
  ),
);

void main() {
  test('no session sends every route to connect', () {
    for (final location in <String>[
      AppRoutes.device,
      AppRoutes.slots,
      AppRoutes.tools,
      AppRoutes.settings,
    ]) {
      expect(
        redirectFor(state: disconnected, location: location),
        AppRoutes.connect,
        reason: location,
      );
    }
    expect(
      redirectFor(state: disconnected, location: AppRoutes.connect),
      isNull,
    );
  });

  test('connecting stays on the connect screen', () {
    expect(redirectFor(state: connecting, location: AppRoutes.connect), isNull);
    expect(
      redirectFor(state: connecting, location: AppRoutes.device),
      AppRoutes.connect,
    );
  });

  test('ready leaves the connect screen for the dashboard', () {
    expect(
      redirectFor(state: ready(), location: AppRoutes.connect),
      AppRoutes.device,
    );
    expect(redirectFor(state: ready(), location: AppRoutes.slots), isNull);
    expect(redirectFor(state: ready(), location: AppRoutes.frameLog), isNull);
  });

  test('limited allows only the dashboard and the update route', () {
    expect(redirectFor(state: limited, location: AppRoutes.device), isNull);
    expect(redirectFor(state: limited, location: AppRoutes.update), isNull);
    expect(
      redirectFor(state: limited, location: AppRoutes.slots),
      AppRoutes.device,
    );
    expect(
      redirectFor(state: limited, location: AppRoutes.connect),
      AppRoutes.device,
    );
  });

  test('updating locks navigation on the update screen', () {
    for (final location in <String>[
      AppRoutes.connect,
      AppRoutes.device,
      AppRoutes.slots,
      AppRoutes.frameLog,
    ]) {
      expect(
        redirectFor(state: updating, location: location),
        AppRoutes.update,
        reason: location,
      );
    }
    expect(redirectFor(state: updating, location: AppRoutes.update), isNull);
  });

  test('the recovery entry carries the transport id', () {
    expect(
      AppRoutes.recover('/dev/cu.usbmodem1'),
      '/tools/update?recover=%2Fdev%2Fcu.usbmodem1',
    );
  });
}

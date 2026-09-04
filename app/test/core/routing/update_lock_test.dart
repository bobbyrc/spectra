import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/routing/redirect.dart';
import 'package:spectra/core/routing/routes.dart';

void main() {
  const disconnected = SessionDisconnected(DisconnectCause.requested);

  test('a running flash pins every location to the update screen', () {
    expect(
      redirectFor(
        state: disconnected,
        location: AppRoutes.connect,
        updating: true,
      ),
      AppRoutes.update,
    );
    expect(
      redirectFor(
        state: SessionReady(
          const DeviceInfo(
            model: DeviceModel.ultra,
            version: FirmwareVersion(major: 2, minor: 2),
            capabilities: Capabilities(<int>{}),
          ),
        ),
        location: AppRoutes.slots,
        updating: true,
      ),
      AppRoutes.update,
    );
  });

  test('the flash lock outranks the disconnected redirect: the recovery '
      'path has no session at all, and that is the run that must not be '
      'interrupted', () {
    expect(
      redirectFor(
        state: disconnected,
        location: AppRoutes.slots,
        updating: true,
      ),
      AppRoutes.update,
      reason: 'without the lock this would go to /connect instead',
    );
  });

  test('the update screen itself is where it stays', () {
    expect(
      redirectFor(
        state: disconnected,
        location: AppRoutes.update,
        updating: true,
      ),
      isNull,
    );
  });

  test('with no flash running the connection state still decides', () {
    expect(
      redirectFor(state: disconnected, location: AppRoutes.slots),
      AppRoutes.connect,
    );
  });
}

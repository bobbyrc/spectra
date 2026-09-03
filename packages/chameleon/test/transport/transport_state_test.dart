// Uses only the public barrel: the platform transports in `chameleon_flutter`
// see exactly this surface.
import 'package:chameleon/chameleon.dart';
import 'package:test/test.dart';

void main() {
  test('permissionDenied and adapterOff are TransportStates', () {
    const TransportState denied = TransportPermissionDenied();
    const TransportState off = TransportAdapterOff();
    expect(denied, isA<TransportState>());
    expect(off, isA<TransportState>());
    expect(denied, isNot(isA<TransportClosed>()));
    expect(off, isNot(isA<TransportClosed>()));
  });

  test('the barrel exports the transport surface Phase 3 needs', () {
    expect(const TransportOpening(), isA<TransportState>());
    expect(const TransportOpen(), isA<TransportState>());
    expect(const TransportPairingRequired(), isA<TransportState>());
    expect(
      const TransportClosed(CloseCause.linkLost, error: PermissionDenied()),
      isA<TransportState>(),
    );
    expect(TransportKind.values, contains(TransportKind.ble));
    expect(
      const DiscoveredDevice(
        name: 'x',
        kind: TransportKind.usb,
        transportId: '/dev/x',
      ).isBootloader,
      isFalse,
    );
  });

  test('a transport reports the largest write it accepts', () {
    // Informational: the dispatcher never chunks, so a transport whose link
    // MTU is smaller must fragment internally.
    expect(FakeDevice().maxWriteLength, 4105);
  });
}

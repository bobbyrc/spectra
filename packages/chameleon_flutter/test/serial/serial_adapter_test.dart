import 'package:chameleon_flutter/src/serial/serial_adapter.dart';
import 'package:chameleon_flutter/src/serial/serial_ids.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a fresh instance every call. Deliberately not a `const`
/// literal: two `const` literals with the same arguments are canonicalised
/// to one instance, which would pass an equality test even without `==`.
SerialPortDescriptor describe({
  String path = '/dev/tty.usbmodem1101',
  String description = 'ChameleonUltra',
  int? vid = ChameleonUsbIds.applicationVid,
  int? pid = ChameleonUsbIds.applicationPid,
  String? manufacturer = ChameleonUsbIds.manufacturer,
  String? product = 'ChameleonUltra',
}) => SerialPortDescriptor(
  path: path,
  description: description,
  vid: vid,
  pid: pid,
  manufacturer: manufacturer,
  product: product,
);

void main() {
  group('SerialPortDescriptor', () {
    test('two descriptions of the same port are equal', () {
      expect(describe(), describe());
      expect(describe().hashCode, describe().hashCode);
      expect(describe(), isNot(same(describe())));
    });

    test('every field takes part in equality', () {
      final differing = <SerialPortDescriptor>[
        describe(path: '/dev/tty.usbmodem1102'),
        describe(description: 'something else'),
        describe(vid: 0x1915),
        describe(pid: null),
        describe(manufacturer: 'someone else'),
        describe(product: null),
      ];

      for (final d in differing) {
        expect(d, isNot(describe()), reason: '$d should differ');
      }
    });

    test('a de-duplicating scan can put descriptors in a set', () {
      expect({describe(), describe()}, hasLength(1));
    });
  });
}

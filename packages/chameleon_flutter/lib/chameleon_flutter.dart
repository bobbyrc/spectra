/// Platform transports and DFU channels for the chameleon SDK.
///
/// Every native dependency of Spectra lives in this package and nowhere
/// else (spec section 5).
library;

export 'src/ble/ble_adapter.dart';
// src/ble/ble_chunking.dart is deliberately not exported: `chunked` and
// `mtuWriteLength` are BleTransport's and BleDfuChannel's own arithmetic,
// used nowhere outside this package.
export 'src/ble/ble_failure.dart' show BleAdapterException, BleFailure;
export 'src/ble/ble_scanner.dart';
export 'src/ble/ble_transport.dart';
export 'src/ble/ble_uuids.dart';
export 'src/ble/universal_ble_adapter.dart';
export 'src/dfu/ble_dfu_channel.dart';
export 'src/dfu/slip.dart';
export 'src/dfu/slip_serial_dfu_channel.dart';
export 'src/guidance.dart';
export 'src/host_platform.dart';
export 'src/merged_scan.dart';
export 'src/serial/libserialport_adapter.dart';
export 'src/serial/serial_adapter.dart';
export 'src/serial/serial_adapter_factory.dart';
export 'src/serial/serial_failure.dart'
    show SerialAdapterException, SerialFailure;
export 'src/serial/serial_guidance.dart';
export 'src/serial/serial_ids.dart';
export 'src/serial/serial_scanner.dart';
export 'src/serial/serial_transport.dart';
export 'src/serial/usb_serial_adapter.dart';
export 'src/transports.dart';

/// Version of the platform package, mirrored from pubspec.yaml.
const String chameleonFlutterVersion = '0.1.0';

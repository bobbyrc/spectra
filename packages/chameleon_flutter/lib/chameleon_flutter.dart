/// Platform transports and DFU channels for the chameleon SDK.
///
/// Every native dependency of Spectra lives in this package and nowhere
/// else (spec section 5).
library;

export 'src/ble/ble_adapter.dart';
export 'src/ble/ble_chunking.dart';
export 'src/ble/ble_failure.dart' show BleAdapterException, BleFailure;
export 'src/ble/ble_scanner.dart';
export 'src/ble/ble_transport.dart';
export 'src/ble/ble_uuids.dart';
export 'src/ble/universal_ble_adapter.dart';
export 'src/guidance.dart';
export 'src/host_platform.dart';
export 'src/serial/libserialport_adapter.dart';
export 'src/serial/serial_adapter.dart';
export 'src/serial/serial_adapter_factory.dart';
export 'src/serial/serial_failure.dart';
export 'src/serial/serial_guidance.dart';
export 'src/serial/serial_ids.dart';
export 'src/serial/serial_transport.dart';
export 'src/serial/usb_serial_adapter.dart';

/// Version of the platform package, mirrored from pubspec.yaml.
const String chameleonFlutterVersion = '0.1.0';

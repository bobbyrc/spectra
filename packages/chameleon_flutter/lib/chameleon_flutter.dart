/// Platform transports and DFU channels for the chameleon SDK.
///
/// Every native dependency of Spectra lives in this package and nowhere
/// else (spec section 5).
library;

export 'src/ble/ble_uuids.dart';
export 'src/guidance.dart';
export 'src/host_platform.dart';
export 'src/serial/serial_ids.dart';

/// Version of the platform package, mirrored from pubspec.yaml.
const String chameleonFlutterVersion = '0.1.0';

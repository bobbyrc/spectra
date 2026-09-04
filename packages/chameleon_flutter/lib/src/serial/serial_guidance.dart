import '../guidance.dart';
import '../host_platform.dart';
import 'serial_failure.dart';

/// What to tell the user about [failure] on [platform], or null when there
/// is nothing useful to say (spec 5.2).
///
/// A pure function so the whole table is testable without a transport: every
/// failure on every platform has one answer, and no platform is ever handed
/// another platform's instructions.
///
/// - `permissionDenied` is the only case whose remedy differs per platform:
///   the dialout/udev group on Linux, an open COM port's ACL on Windows, the
///   sandbox entitlement on macOS, the USB permission dialog on Android.
///   iOS has no serial stack, so it has no advice either.
/// - `portBusy` names ModemManager on Linux, which is the usual culprit, and
///   elsewhere only says something else holds the port.
/// - `notFound` is the same everywhere: the port is gone.
/// - `disconnected` and `unknown` are not the user's to fix.
TransportGuidance? serialGuidance(
  SerialFailure failure,
  HostPlatform platform,
) => switch (failure) {
  SerialFailure.permissionDenied => switch (platform) {
    HostPlatform.linux => TransportGuidance.linuxSerialGroup,
    HostPlatform.windows => TransportGuidance.windowsPortAccessDenied,
    HostPlatform.macos => TransportGuidance.macosSerialEntitlement,
    HostPlatform.android => TransportGuidance.androidUsbPermission,
    HostPlatform.ios || HostPlatform.unknown => null,
  },
  SerialFailure.portBusy =>
    platform == HostPlatform.linux
        ? TransportGuidance.linuxModemManager
        : TransportGuidance.portBusyOther,
  SerialFailure.notFound => TransportGuidance.portNotFound,
  SerialFailure.disconnected || SerialFailure.unknown => null,
};

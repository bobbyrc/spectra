import '../host_platform.dart';
import 'libserialport_adapter.dart';
import 'serial_adapter.dart';
import 'usb_serial_adapter.dart';

/// The serial stack for this platform, or null where there is none.
///
/// Spec 5.4: libserialport_plus on Windows, macOS and Linux; usb_serial on
/// Android; iOS has no serial transport at all.
SerialPortAdapter? defaultSerialPortAdapter({HostPlatform? platform}) =>
    switch (platform ?? currentHostPlatform()) {
      HostPlatform.macos ||
      HostPlatform.windows ||
      HostPlatform.linux => LibSerialPortAdapter(platform: platform),
      HostPlatform.android => UsbSerialAdapter(),
      HostPlatform.ios || HostPlatform.unknown => null,
    };

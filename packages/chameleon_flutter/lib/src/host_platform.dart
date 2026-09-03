import 'dart:io';

/// The five targets in spec 5.4, plus a fallback for anything else (a test
/// runner on an unusual host). Passed into transports rather than read
/// inline so platform-specific behaviour is unit-testable.
enum HostPlatform { android, ios, macos, windows, linux, unknown }

/// The platform this process runs on.
HostPlatform currentHostPlatform() {
  if (Platform.isAndroid) return HostPlatform.android;
  if (Platform.isIOS) return HostPlatform.ios;
  if (Platform.isMacOS) return HostPlatform.macos;
  if (Platform.isWindows) return HostPlatform.windows;
  if (Platform.isLinux) return HostPlatform.linux;
  return HostPlatform.unknown;
}

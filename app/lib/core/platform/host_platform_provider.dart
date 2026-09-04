import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'host_platform_provider.g.dart';

/// Injection seam for `currentHostPlatform()` (`chameleon_flutter` reads the
/// real OS directly and takes no parameter, so there is nothing to override
/// there). A test overrides this provider to exercise a platform's branch
/// without depending on the host the suite runs on.
///
/// Distinct from `core/discovery/scanners.dart`'s `scannerPlatformProvider`
/// family, which feeds `ChameleonTransports.defaultScanners` a different
/// parameter (`HostPlatform?`, `null` meaning "ask the OS") for an unrelated
/// purpose.
@Riverpod(keepAlive: true)
HostPlatform hostPlatform(Ref ref) => currentHostPlatform();

/// True on the two platforms that actually background an app — the rest
/// keep a window open and a cable plugged in.
bool isMobile(HostPlatform platform) =>
    platform == HostPlatform.android || platform == HostPlatform.ios;

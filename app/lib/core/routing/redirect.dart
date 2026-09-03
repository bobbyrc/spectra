import 'package:chameleon/chameleon.dart';

import 'routes.dart';

/// Spec 7.2, whole: routing is driven by the connection state. Pure, so the
/// rule is tested without a widget tree and go_router only has to call it.
///
/// Returns the location to go to, or null to stay where we are.
String? redirectFor({
  required ConnectionState state,
  required String location,
}) {
  switch (state) {
    case SessionUpdating():
      // A running update locks navigation: the device is mid-flash and every
      // other screen would be lying about it.
      return location == AppRoutes.update ? null : AppRoutes.update;
    case SessionLimited():
      // Only a firmware update is possible, so only the reduced dashboard and
      // the update screen are reachable.
      final allowed =
          location == AppRoutes.device || location == AppRoutes.update;
      return allowed ? null : AppRoutes.device;
    case SessionConnecting():
    case SessionDisconnected():
      // The recovery entry is reachable with nothing connected: a device
      // left in its bootloader has no session and must still be
      // recoverable (spec 5.6).
      final allowed =
          location == AppRoutes.connect || location == AppRoutes.update;
      return allowed ? null : AppRoutes.connect;
    case SessionReady():
      return location == AppRoutes.connect ? AppRoutes.device : null;
  }
}

import 'package:chameleon/chameleon.dart';

/// The bootloader a `?recover=` link names, if it is still visible.
///
/// Only a device flagged `isBootloader` qualifies: the query parameter comes
/// off a URL and a run started against a device in application mode would
/// hang on a channel that never answers.
DiscoveredDevice? recoverTarget(
  List<DiscoveredDevice> devices,
  String? transportId,
) {
  if (transportId == null) return null;
  for (final device in devices) {
    if (device.transportId == transportId && device.isBootloader) {
      return device;
    }
  }
  return null;
}

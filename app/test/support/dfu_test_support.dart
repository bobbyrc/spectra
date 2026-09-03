import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/app.dart';
import 'package:spectra/core/dfu/dfu_runtime.dart';
import 'package:spectra/features/tools/state/firmware_package_source.dart';

import 'app_harness.dart';

/// A [FirmwarePackageSource] that always returns the same bytes, regardless
/// of the path asked for. Lets DFU tests skip the file system entirely
/// (spec 8.6).
final class MemoryFirmwarePackageSource implements FirmwarePackageSource {
  MemoryFirmwarePackageSource(this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List> read(String path) async => bytes;
}

/// `testApp` plus the package source and a short scan budget: the harness
/// owns the app root's overrides (ruling: nobody edits it), and a test-local
/// `ProviderScope` on top of it would be a second root. `appOverrides` is the
/// documented way to compose one more override.
///
/// Shared by every DFU-flow test (Tasks 7, 10, 12, 13) so the source and the
/// scan-timeout override are written once.
///
/// [openChannel] replaces the production opener, which hands out a
/// zero-latency channel: a run over that finishes inside a single pump, so a
/// test that has to act *during* a flash (cancel, or reading the activity
/// flag while it is set) needs a slower one.
Widget buildDfuTestApp({
  required FirmwarePackageSource source,
  Transport Function(DiscoveredDevice)? transport,
  DfuChannelOpener? openChannel,
}) => ProviderScope(
  overrides: <Override>[
    ...appOverrides(transport: transport ?? (_) => FakeDevice()),
    firmwarePackageSourceProvider.overrideWithValue(source),
    dfuScanTimeoutProvider.overrideWithValue(const Duration(seconds: 2)),
    if (openChannel != null)
      dfuChannelOpenerProvider.overrideWithValue(openChannel),
  ],
  child: const SpectraRoot(),
);

/// A [DfuChannelOpener] over a fake device that is already in its bootloader
/// and answers every DFU write after [latency], so a run takes many pumps to
/// finish instead of one. The device is closed when the test ends.
///
/// Its own device, not the standing `emulatorBootloader`: a run over this
/// channel is meant to be interrupted, so nothing should be able to observe
/// it as the device the app would reconnect to afterwards.
DfuChannelOpener slowBootloaderOpener({
  Duration latency = const Duration(milliseconds: 20),
}) {
  final device = FakeDevice()..firmware.bootloaderRequested = true;
  addTearDown(device.close);
  return (_) async => device.openDfuChannel(latency: latency);
}

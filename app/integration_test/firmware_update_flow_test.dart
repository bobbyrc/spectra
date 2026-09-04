import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:spectra/app.dart';
import 'package:spectra/core/dfu/dfu_runtime.dart';
import 'package:spectra/features/tools/state/firmware_package_source.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../test/fixtures/dfu_package_fixture.dart';
import 'support.dart';

final class _MemorySource implements FirmwarePackageSource {
  _MemorySource(this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List> read(String path) async => bytes;
}

/// The Phase 8 gate on a real engine: flash the fake bootloader in emulator
/// mode. No hardware is touched, and none is needed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('update the emulated device', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...appOverrides(transport: (_) => FakeDevice()),
          firmwarePackageSourceProvider.overrideWithValue(
            _MemorySource(buildDfuZip(size: 8192)),
          ),
          dfuScanTimeoutProvider.overrideWithValue(const Duration(seconds: 2)),
        ],
        child: const SpectraRoot(),
      ),
    );
    Future<void> settle([int frames = 20]) => pumpFrames(tester, count: frames);

    await tester.pump();
    await tester.tap(find.text(FakeScanner.emulatedUltra.name));
    await settle(30);
    expect(find.byType(SpectraAppShell), findsOneWidget);

    await tester.tap(find.text('Tools').last);
    await settle();
    await tester.tap(find.text('Firmware update'));
    await settle();

    await tester.enterText(
      find.byType(SpectraTextField).first,
      '/tmp/ultra-dfu-app.zip',
    );
    await tester.pump();
    await tester.tap(find.text('Load package'));
    await settle();
    await tester.tap(find.text('Install firmware'));
    await settle(100);

    expect(find.text('Firmware installed.'), findsOneWidget);
  });
}

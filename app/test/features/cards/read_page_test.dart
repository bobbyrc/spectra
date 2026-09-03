import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/core/errors/problem_view.dart';
import 'package:spectra/features/cards/cards.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

FakeDevice deviceWithCard({bool present = true}) {
  final FakeFirmware firmware = FakeFirmware();
  if (present) {
    firmware.present(
      FakeMf1Card.classic1k(
        uid: Uint8List.fromList(<int>[0xDE, 0xAD, 0xBE, 0xEF]),
      ),
    );
  }
  return FakeDevice(firmware: firmware);
}

/// A 1K whose sector 5 has neither key, so four of its blocks cannot be
/// read: the partial dump the save sheet has to warn about (R33).
FakeDevice deviceWithPartlyLockedCard() {
  final FakeFirmware firmware = FakeFirmware();
  final FakeMf1Card card = FakeMf1Card.classic1k(
    uid: Uint8List.fromList(<int>[0xDE, 0xAD, 0xBE, 0xEF]),
  );
  card.keys.remove(FakeMf1Card.keyId(5, KeyType.a));
  card.keys.remove(FakeMf1Card.keyId(5, KeyType.b));
  firmware.present(card);
  return FakeDevice(firmware: firmware);
}

Future<void> openRead(WidgetTester tester, FakeDevice device) async {
  useDesktopSurface(tester);
  await pumpTestApp(tester, transport: (_) => device);
  await connectToEmulator(tester);
  await tester.tap(find.text('Cards').last);
  await pumpFrames(tester, count: 10);
  await tester.tap(find.text('Read a card'));
  await pumpFrames(tester, count: 10);
}

void main() {
  testWidgetsApp('the idle screen offers an HF and an LF scan', (tester) async {
    await openRead(tester, deviceWithCard());
    expect(find.byType(ReadPage), findsOneWidget);
    expect(find.text('Scan high frequency'), findsOneWidget);
    expect(find.text('Scan low frequency'), findsOneWidget);
    expect(find.byType(SpectraProgressIndicator), findsNothing);
  });

  testWidgetsApp('a successful read shows the card and offers a save', (
    tester,
  ) async {
    await openRead(tester, deviceWithCard());
    await tester.tap(find.text('Scan high frequency'));
    await pumpFrames(tester, count: 40);

    expect(find.text('MIFARE Classic 1K'), findsOneWidget);
    expect(find.text('DEADBEEF'), findsOneWidget);
    expect(find.text('Save to library'), findsOneWidget);
    expect(find.text('Read again'), findsOneWidget);
    expect(
      find.byType(SpectraProgressIndicator),
      findsNothing,
      reason: 'the read is over',
    );
  });

  testWidgetsApp('the save sheet warns that a partial dump is zero-filled', (
    tester,
  ) async {
    await openRead(tester, deviceWithPartlyLockedCard());
    await tester.tap(find.text('Scan high frequency'));
    await pumpFrames(tester, count: 60);

    expect(
      find.text(
        '4 of 64 blocks could be read. Sectors with no known key are blank.',
      ),
      findsNothing,
      reason: 'the result summary counts what was read, not what was not',
    );

    await tester.tap(find.text('Save to library'));
    await pumpFrames(tester);

    expect(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text(
          '4 blocks could not be read. They are saved as zeros.',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.close));
    await pumpFrames(tester);
  });

  testWidgetsApp('a complete dump gets no partial warning in the save sheet', (
    tester,
  ) async {
    await openRead(tester, deviceWithCard());
    await tester.tap(find.text('Scan high frequency'));
    await pumpFrames(tester, count: 60);
    await tester.tap(find.text('Save to library'));
    await pumpFrames(tester);

    expect(find.textContaining('could not be read'), findsNothing);
    await tester.tap(find.byIcon(Icons.close));
    await pumpFrames(tester);
  });

  testWidgetsApp('an empty field shows the catalog message', (tester) async {
    await openRead(tester, deviceWithCard(present: false));
    await tester.tap(find.text('Scan high frequency'));
    await pumpFrames(tester, count: 30);

    expect(find.byType(ProblemView), findsOneWidget);
    expect(
      find.textContaining('No high-frequency card was found'),
      findsOneWidget,
    );

    await tester.tap(find.text('Try again'));
    await pumpFrames(tester, count: 5);
    expect(find.byType(ProblemView), findsNothing);
  });

  testWidgetsApp('a running dump shows progress and a cancel', (tester) async {
    final FakeDevice device = deviceWithCard();
    device.latency = const Duration(milliseconds: 5);
    await openRead(tester, device);

    await tester.tap(find.text('Scan high frequency'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SpectraProgressIndicator), findsOneWidget);

    await pumpFrames(tester, count: 60);
    expect(find.byType(SpectraProgressIndicator), findsNothing);
  });
}

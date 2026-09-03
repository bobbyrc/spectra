import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra/core/session/frame_log_provider.dart';
import 'package:spectra/features/tools/ui/frame_log_page.dart';
import 'package:spectra/l10n/app_localizations.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

/// Hosts [FrameLogPage] alone, under just the app's localizations and the
/// Spectra theme, with [frameLogEntriesProvider] under direct control — no
/// session, no router, so a rotation of the ring buffer can be driven by
/// hand rather than by pushing 512 real frames through a `FakeDevice`.
Widget _isolatedFrameLogPage(Stream<List<FrameLogEntry>> entries) {
  return ProviderScope(
    overrides: <Override>[
      frameLogEntriesProvider.overrideWith((ref) => entries),
    ],
    child: MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        AppLocalizations.delegate,
        ...SpectraUiLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SpectraTheme(
        colors: SpectraColors.light,
        brightness: Brightness.light,
        child: FrameLogPage(),
      ),
    ),
  );
}

FrameLogEntry _entry(int command) =>
    FrameLogEntry(DateTime.now(), FrameDirection.sent, Frame(command: command));

void main() {
  group('frameLogEntriesKey', () {
    test('is the same for two lists with the same length and last entry', () {
      final FrameLogEntry shared = _entry(1);
      final List<FrameLogEntry> a = <FrameLogEntry>[_entry(0), shared];
      final List<FrameLogEntry> b = <FrameLogEntry>[_entry(0), shared];

      expect(
        frameLogEntriesKey(AsyncData(a)),
        frameLogEntriesKey(AsyncData(b)),
      );
    });

    test('changes when a full ring buffer rotates (length pinned)', () {
      final List<FrameLogEntry> before = <FrameLogEntry>[_entry(0), _entry(1)];
      // Simulates FrameLog.add() once the buffer is at capacity: the
      // oldest entry drops, a new one is appended, length is unchanged.
      final List<FrameLogEntry> after = <FrameLogEntry>[_entry(1), _entry(2)];

      expect(before.length, after.length);
      expect(
        frameLogEntriesKey(AsyncData(before)),
        isNot(frameLogEntriesKey(AsyncData(after))),
      );
    });

    test('changes when the list grows', () {
      final List<FrameLogEntry> shorter = <FrameLogEntry>[_entry(0)];
      final List<FrameLogEntry> longer = <FrameLogEntry>[_entry(0), _entry(1)];

      expect(
        frameLogEntriesKey(AsyncData(shorter)),
        isNot(frameLogEntriesKey(AsyncData(longer))),
      );
    });
  });

  testWidgets('shows the newest entry once a full ring buffer rotates', (
    tester,
  ) async {
    final StreamController<List<FrameLogEntry>> controller =
        StreamController<List<FrameLogEntry>>();
    addTearDown(controller.close);

    await tester.pumpWidget(_isolatedFrameLogPage(controller.stream));

    final FrameLogEntry oldest = _entry(1001);
    final FrameLogEntry middle = _entry(1002);
    controller.add(<FrameLogEntry>[oldest, middle]);
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('cmd=1002'), findsOneWidget);
    expect(find.textContaining('cmd=1003'), findsNothing);

    // Same length as before (the ring buffer is full): the oldest entry
    // drops, a new one is appended. Length alone would look unchanged.
    final FrameLogEntry newest = _entry(1003);
    controller.add(<FrameLogEntry>[middle, newest]);
    // A second pump lets the rebuild the changed selected key triggers
    // actually run — the first pump only delivers the stream event.
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('cmd=1003'), findsOneWidget);
    expect(find.textContaining('cmd=1001'), findsNothing);
  });

  testWidgets('shows a back button that returns to Tools', (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openFrameLog(tester);

    expect(find.text('Frame log'), findsWidgets);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      find.text('Everything sent to and received from the device.'),
      findsOneWidget,
    );

    await settleApp(tester);
  });

  testWidgets('lists frames after a handshake and copies them', (tester) async {
    final List<MethodCall> clipboard = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') clipboard.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openFrameLog(tester);

    expect(find.text('Frame log'), findsWidgets);
    expect(find.textContaining('cmd='), findsWidgets);

    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(clipboard, hasLength(1));

    await settleApp(tester);
  });
}

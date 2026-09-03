import 'package:chameleon/chameleon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_harness.dart';

void main() {
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

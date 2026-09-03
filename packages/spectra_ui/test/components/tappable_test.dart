import 'package:flutter/semantics.dart' show SemanticsAction, SemanticsNode;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  group('SpectraTappable', () {
    testWidgets('takes focus with Tab and activates with Enter and Space', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        spectraHarness(
          child: SpectraTappable(
            onTap: () => taps++,
            semanticsLabel: 'Target',
            child: const SizedBox(width: 100, height: 48),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(primaryFocusIsInside(tester), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(taps, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(taps, 2);
    });

    testWidgets('publishes a tap action on its semantics node', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        spectraHarness(
          child: SpectraTappable(
            onTap: () {},
            semanticsLabel: 'Target',
            child: const SizedBox(width: 100, height: 48),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(SpectraTappable)),
        matchesSemantics(
          label: 'Target',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
    });

    testWidgets('a disabled target is not focusable and does not fire', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        spectraHarness(
          child: SpectraTappable(
            onTap: () => taps++,
            enabled: false,
            semanticsLabel: 'Target',
            child: const SizedBox(width: 100, height: 48),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(primaryFocusIsInside(tester), isFalse);
      await tester.tap(find.byType(SpectraTappable), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('paints an accent focus ring only while focused', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        spectraHarness(
          child: SpectraTappable(
            onTap: () {},
            semanticsLabel: 'Target',
            child: const SizedBox(width: 100, height: 48),
          ),
        ),
      );
      expect(ringColor(tester).a, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(ringColor(tester), SpectraColors.light.accent);
    });
  });

  group('every interactive component announces a tap action', () {
    testWidgets('SpectraButton', (WidgetTester tester) async {
      await tester.pumpWidget(
        spectraHarness(
          child: SpectraButton(label: 'Connect', onPressed: () {}),
        ),
      );
      final SemanticsNode node = tester.getSemantics(
        find.byType(SpectraButton),
      );
      expect(node.label, 'Connect');
      expect(hasTap(node), isTrue);
      expect(isButtonNode(node), isTrue);
    });

    testWidgets('SpectraListTile', (WidgetTester tester) async {
      await tester.pumpWidget(
        spectraHarness(
          child: SpectraListTile(
            title: 'Slot 1',
            subtitle: 'Empty',
            onTap: () {},
          ),
        ),
      );
      final SemanticsNode node = tester.getSemantics(
        find.byType(SpectraListTile),
      );
      expect(node.label, 'Slot 1, Empty');
      expect(hasTap(node), isTrue);
      expect(isButtonNode(node), isTrue);
    });

    testWidgets('SpectraSlotTile', (WidgetTester tester) async {
      await tester.pumpWidget(
        spectraHarness(
          child: SpectraSlotTile(number: 1, enabled: true, onTap: () {}),
        ),
      );
      final SemanticsNode node = tester.getSemantics(
        find.byType(SpectraSlotTile),
      );
      expect(hasTap(node), isTrue);
      expect(isButtonNode(node), isTrue);
    });

    testWidgets('SpectraCard', (WidgetTester tester) async {
      await tester.pumpWidget(
        spectraHarness(
          child: SpectraCard(
            semanticsLabel: 'Device card',
            onTap: () {},
            child: const SizedBox(width: 100, height: 60),
          ),
        ),
      );
      final SemanticsNode node = tester.getSemantics(find.byType(SpectraCard));
      expect(hasTap(node), isTrue);
      expect(isButtonNode(node), isTrue);
    });

    testWidgets('SpectraSectionHeader action', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        spectraHarness(
          child: SpectraSectionHeader(
            title: 'Slots',
            actionLabel: 'Refresh',
            onAction: () => taps++,
          ),
        ),
      );
      final SemanticsNode node = tester.getSemantics(
        find.byType(SpectraTappable),
      );
      expect(node.label, 'Refresh');
      expect(hasTap(node), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('SpectraDisclosure toggles from the keyboard', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        spectraHarness(
          height: 240,
          child: const SpectraDisclosure(
            summary: Text('Summary'),
            detail: Text('Detail'),
          ),
        ),
      );
      expect(find.text('Detail'), findsNothing);
      final SemanticsNode node = tester.getSemantics(
        find.byType(SpectraTappable),
      );
      expect(hasTap(node), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.pump(SpectraMotion.medium);
      expect(find.text('Detail'), findsOneWidget);
    });
  });
}

/// True when the focused node lives inside the tappable under test.
bool primaryFocusIsInside(WidgetTester tester) {
  final FocusNode? focused = tester.binding.focusManager.primaryFocus;
  if (focused == null) return false;
  final BuildContext? context = focused.context;
  if (context == null) return false;
  bool found = false;
  context.visitAncestorElements((Element element) {
    if (element.widget is SpectraTappable) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// The current colour of the tappable's focus ring.
Color ringColor(WidgetTester tester) {
  final AnimatedContainer container = tester.widget<AnimatedContainer>(
    find
        .descendant(
          of: find.byType(SpectraTappable),
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  return (container.foregroundDecoration! as BoxDecoration).border!.top.color;
}

bool isButtonNode(SemanticsNode node) =>
    node.getSemanticsData().flagsCollection.isButton;

bool hasTap(SemanticsNode node) =>
    node.getSemanticsData().hasAction(SemanticsAction.tap);

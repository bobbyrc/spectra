import 'package:test/test.dart';

import '../tool/src/string_rules.dart';

void main() {
  group('isLocalizedUiPath', () {
    test('spectra_ui components are covered', () {
      expect(
        isLocalizedUiPath('spectra_ui', 'lib/src/components/slot_tile.dart'),
        isTrue,
      );
    });

    test('spectra_ui tokens and theme are not', () {
      expect(
        isLocalizedUiPath('spectra_ui', 'lib/src/tokens/colors.dart'),
        isFalse,
      );
      expect(
        isLocalizedUiPath('spectra_ui', 'lib/src/theme/spectra_app.dart'),
        isFalse,
      );
    });

    test('app feature ui folders are covered at any depth', () {
      expect(
        isLocalizedUiPath('spectra', 'lib/features/slots/ui/slots_screen.dart'),
        isTrue,
      );
      expect(
        isLocalizedUiPath('spectra', 'lib/features/slots/ui/widgets/row.dart'),
        isTrue,
      );
    });

    test('app feature non-ui folders are not', () {
      expect(
        isLocalizedUiPath('spectra', 'lib/features/slots/slots.dart'),
        isFalse,
      );
      expect(
        isLocalizedUiPath('spectra', 'lib/features/slots/state/notifier.dart'),
        isFalse,
      );
    });

    test('the gallery is exempt: it is sample data, not product copy', () {
      expect(
        isLocalizedUiPath('spectra_ui_gallery', 'lib/pages/card_page.dart'),
        isFalse,
      );
    });

    test('test paths are never covered, in either package', () {
      expect(
        isLocalizedUiPath(
          'spectra_ui',
          'test/src/components/slot_tile_test.dart',
        ),
        isFalse,
      );
      expect(
        isLocalizedUiPath(
          'spectra',
          'test/features/slots/ui/slots_screen_test.dart',
        ),
        isFalse,
      );
    });
  });

  group('checkTextLiterals', () {
    List<String> rulesFor(String source) => checkTextLiterals(
      packageName: 'spectra_ui',
      relativePath: 'lib/src/components/demo.dart',
      source: source,
    ).map((v) => v.rule).toList();

    test('flags a bare string literal in Text', () {
      expect(rulesFor("Widget b() => Text('Slot 1');"), ['no-literal-text']);
    });

    test('flags a const string literal in Text', () {
      expect(rulesFor('Widget b() => const Text("Slot 1");'), [
        'no-literal-text',
      ]);
    });

    test('flags a multi-line Text( call', () {
      expect(rulesFor("Widget b() => Text(\n  'Slot 1',\n);"), [
        'no-literal-text',
      ]);
    });

    test('allows a localization lookup', () {
      expect(rulesFor('Widget b() => Text(l10n.slotTileEmpty);'), isEmpty);
    });

    test('allows an interpolated variable', () {
      expect(rulesFor('Widget b() => Text(label);'), isEmpty);
    });

    test('flags label:', () {
      expect(rulesFor("final s = Semantics(label: 'x');"), ['no-literal-text']);
    });

    test('flags hintText:', () {
      expect(
        rulesFor(
          'final f = TextField(decoration: InputDecoration(hintText: "x"));',
        ),
        ['no-literal-text'],
      );
    });

    test('flags subtitle:', () {
      expect(rulesFor("final t = SpectraListTile(title: t, subtitle: 'x');"), [
        'no-literal-text',
      ]);
    });

    test('flags errorText:', () {
      expect(
        rulesFor(
          'final f = TextField(decoration: InputDecoration(errorText: "x"));',
        ),
        ['no-literal-text'],
      );
    });

    test('flags labelText:', () {
      expect(
        rulesFor(
          'final f = TextField(decoration: InputDecoration(labelText: "x"));',
        ),
        ['no-literal-text'],
      );
    });

    test('honours the l10n-exempt marker', () {
      expect(
        rulesFor("Widget b() => Text('0x00'); // l10n-exempt: hex sample"),
        isEmpty,
      );
    });

    test('does not flag an empty literal', () {
      expect(rulesFor("Widget b() => Text('');"), isEmpty);
      expect(rulesFor("final s = Semantics(label: '');"), isEmpty);
    });

    test('flags a triple-quoted multi-line literal in Text', () {
      final v = checkTextLiterals(
        packageName: 'spectra_ui',
        relativePath: 'lib/src/components/demo.dart',
        source: "Text('''multi\nline''')",
      );
      expect(v.single.rule, 'no-literal-text');
      expect(v.single.import, startsWith('line 1:'));
    });

    test('flags a raw string literal in Text', () {
      expect(rulesFor("Widget b() => Text(r'raw');"), ['no-literal-text']);
    });

    test('flags a raw triple-quoted literal in Text', () {
      expect(rulesFor("Widget b() => Text(r'''raw triple''');"), [
        'no-literal-text',
      ]);
    });

    test('flags a triple-quoted literal in a named argument', () {
      expect(rulesFor('final s = Semantics(label: """x""");'), [
        'no-literal-text',
      ]);
    });

    test('does not flag an empty triple-quoted literal', () {
      expect(rulesFor("Widget b() => Text('''''');"), isEmpty);
    });

    test('reports the offending literal and line', () {
      final v = checkTextLiterals(
        packageName: 'spectra_ui',
        relativePath: 'lib/src/components/demo.dart',
        source: "// line one\nWidget b() => Text('Nope');\n",
      );
      expect(v.single.file, 'lib/src/components/demo.dart');
      expect(v.single.import, "line 2: 'Nope'");
    });

    test('files outside a ui path are never checked', () {
      final v = checkTextLiterals(
        packageName: 'spectra_ui',
        relativePath: 'lib/src/tokens/colors.dart',
        source: "Widget b() => Text('fine here');",
      );
      expect(v, isEmpty);
    });
  });
}

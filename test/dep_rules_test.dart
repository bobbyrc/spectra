import 'package:test/test.dart';

import '../tool/src/dep_rules.dart';

void main() {
  group('package allowlists', () {
    test('chameleon may not import flutter', () {
      final v = checkFile(
        packageName: 'chameleon',
        relativePath: 'lib/src/codec/frame.dart',
        imports: ['package:flutter/material.dart'],
      );
      expect(v.map((e) => e.rule), contains('package-allowlist'));
    });

    test('chameleon may import collection and dart core', () {
      final v = checkFile(
        packageName: 'chameleon',
        relativePath: 'lib/src/codec/frame.dart',
        imports: [
          'dart:typed_data',
          'package:collection/collection.dart',
          'lrc.dart',
        ],
      );
      expect(v, isEmpty);
    });

    test('spectra_ui may not import chameleon', () {
      final v = checkFile(
        packageName: 'spectra_ui',
        relativePath: 'lib/src/slot_tile.dart',
        imports: ['package:chameleon/chameleon.dart'],
      );
      expect(v.map((e) => e.rule), contains('package-allowlist'));
    });

    test('test files may import test-only packages', () {
      final v = checkFile(
        packageName: 'chameleon',
        relativePath: 'test/frame_test.dart',
        imports: [
          'package:test/test.dart',
          'package:fake_async/fake_async.dart',
        ],
      );
      expect(v, isEmpty);
    });

    test('chameleon_flutter test file may import archive and crypto, '
        'a lib file may not', () {
      final testFile = checkFile(
        packageName: 'chameleon_flutter',
        relativePath: 'test/dfu/dfu_channel_flash_test.dart',
        imports: ['package:archive/archive.dart', 'package:crypto/crypto.dart'],
      );
      expect(testFile, isEmpty);

      final libFile = checkFile(
        packageName: 'chameleon_flutter',
        relativePath: 'lib/src/dfu/ble_dfu_channel.dart',
        imports: ['package:archive/archive.dart', 'package:crypto/crypto.dart'],
      );
      expect(libFile.map((e) => e.rule), everyElement('package-allowlist'));
      expect(libFile, hasLength(2));
    });
  });

  group('app structure', () {
    test('feature may not import another feature internals', () {
      final v = checkFile(
        packageName: 'spectra',
        relativePath: 'lib/features/cards/ui/card_list.dart',
        imports: ['package:spectra/features/slots/state/slots_notifier.dart'],
      );
      expect(v.map((e) => e.rule), contains('feature-internals'));
    });

    test('feature may import another feature barrel', () {
      final v = checkFile(
        packageName: 'spectra',
        relativePath: 'lib/features/cards/ui/card_list.dart',
        imports: ['package:spectra/features/slots/slots.dart'],
      );
      expect(v, isEmpty);
    });

    test('drift only under data', () {
      final bad = checkFile(
        packageName: 'spectra',
        relativePath: 'lib/features/cards/state/cards_notifier.dart',
        imports: ['package:drift/drift.dart'],
      );
      expect(bad.map((e) => e.rule), contains('drift-in-data-only'));
      final ok = checkFile(
        packageName: 'spectra',
        relativePath: 'lib/data/cards_repository.dart',
        imports: ['package:drift/drift.dart'],
      );
      expect(ok, isEmpty);
    });

    test('no material import under features', () {
      final v = checkFile(
        packageName: 'spectra',
        relativePath: 'lib/features/slots/ui/slot_grid.dart',
        imports: ['package:flutter/material.dart'],
      );
      expect(v.map((e) => e.rule), contains('no-material-in-features'));
    });

    test('nobody imports chameleon src', () {
      final v = checkFile(
        packageName: 'spectra',
        relativePath: 'lib/core/session.dart',
        imports: ['package:chameleon/src/commands/device.dart'],
      );
      expect(v.map((e) => e.rule), contains('sdk-internals'));
    });

    test('drift_flutter counts as drift outside data', () {
      final v = checkFile(
        packageName: 'spectra',
        relativePath: 'lib/features/cards/state/cards_notifier.dart',
        imports: ['package:drift_flutter/drift_flutter.dart'],
      );
      expect(v.map((e) => e.rule), contains('drift-in-data-only'));
    });

    test('app structural rules do not apply to test paths', () {
      final v = checkFile(
        packageName: 'spectra',
        relativePath: 'integration_test/flow_test.dart',
        imports: [
          'package:drift/drift.dart',
          'package:spectra/features/slots/state/slots_notifier.dart',
        ],
      );
      expect(v, isEmpty);
    });
  });

  group('relative imports in the app package', () {
    test('relative import into another feature internals fires', () {
      final v = checkFile(
        packageName: 'spectra',
        relativePath: 'lib/features/cards/ui/x.dart',
        imports: ['../../slots/state/n.dart'],
      );
      expect(v.map((e) => e.rule), contains('feature-internals'));
      // Quoted as the file writes it, not as the rule resolves it: the
      // message has to point at a line someone can go and find.
      expect(v.single.import, '../../slots/state/n.dart');
    });

    test('a relative export into another feature fires too', () {
      final v = checkFile(
        packageName: 'spectra',
        relativePath: 'lib/features/cards/cards.dart',
        imports: ['../slots/ui/slot_picker.dart'],
      );
      expect(v.map((e) => e.rule), contains('feature-internals'));
    });

    test('a relative import inside the same feature is clean', () {
      final v = checkFile(
        packageName: 'spectra',
        relativePath: 'lib/features/cards/ui/x.dart',
        imports: [
          '../state/cards_notifier.dart',
          '../../../core/format/tag_labels.dart',
        ],
      );
      expect(v, isEmpty);
    });

    test('relative import of another feature barrel is clean', () {
      final v = checkFile(
        packageName: 'spectra',
        relativePath: 'lib/features/cards/ui/x.dart',
        imports: ['../../slots/slots.dart'],
      );
      expect(v, isEmpty);
    });

    test('relative import of data is clean for a feature', () {
      final v = checkFile(
        packageName: 'spectra',
        relativePath: 'lib/features/cards/ui/x.dart',
        imports: ['../../../data/cards_repository.dart'],
      );
      expect(v, isEmpty);
    });

    test(
      'direct drift import still fires alongside a relative data import',
      () {
        final v = checkFile(
          packageName: 'spectra',
          relativePath: 'lib/features/cards/state/x.dart',
          imports: [
            '../../../data/cards_repository.dart',
            'package:drift/drift.dart',
          ],
        );
        expect(v.map((e) => e.rule), contains('drift-in-data-only'));
      },
    );
  });

  test('extracts imports from source text', () {
    const src = '''
import 'dart:async';
import "package:meta/meta.dart";
export 'foo.dart';
part 'bar.g.dart';
// import 'not/real.dart';
''';
    expect(extractImports(src), [
      'dart:async',
      'package:meta/meta.dart',
      'foo.dart',
    ]);
  });
}

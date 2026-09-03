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

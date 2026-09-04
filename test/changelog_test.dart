import 'dart:io';

import 'package:test/test.dart';

import '../tool/src/changelog.dart';

const String _sample = '''
# Changelog

## [Unreleased]

## [1.0.0] - 2026-09-03

### Added

- Everything.

## [0.9.0] - 2026-08-01

### Added

- Less.
''';

void main() {
  test('skips Unreleased and returns the newest released entry', () {
    final ChangelogEntry entry = latestReleasedEntry(_sample);
    expect(entry.version, '1.0.0');
    expect(entry.date, '2026-09-03');
    expect(entry.body, contains('Everything.'));
    expect(entry.body, isNot(contains('Less.')));
  });

  test('throws when only Unreleased exists', () {
    expect(
      () => latestReleasedEntry('# Changelog\n\n## [Unreleased]\n'),
      throwsFormatException,
    );
  });

  group('the repository changelog', () {
    late String source;
    setUpAll(() => source = File('CHANGELOG.md').readAsStringSync());

    test('follows Keep a Changelog', () {
      expect(source, contains('Keep a Changelog'));
      expect(source, contains('Semantic Versioning'));
      expect(source, contains('## [Unreleased]'));
    });

    test('its newest entry is 1.0.0-rc.1 and matches app/pubspec.yaml', () {
      final ChangelogEntry entry = latestReleasedEntry(source);
      expect(entry.version, '1.0.0-rc.1');
      // app/pubspec.yaml carries the core version only; the pre-release
      // identity lives in the git tag (see tool/src/release_version.dart).
      final String core = entry.version.split('-').first;
      final String pubspec = File('app/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('version: $core+'));
    });

    test('the v1 entry names the shipped features', () {
      final ChangelogEntry entry = latestReleasedEntry(source);
      for (final String feature in const <String>[
        'Connect',
        'Slots',
        'Cards',
        'Firmware update',
        'Dictionaries',
      ]) {
        expect(entry.body, contains(feature), reason: 'missing $feature');
      }
    });
  });
}

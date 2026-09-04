import 'dart:io';

import 'package:test/test.dart';

import '../tool/src/release_version.dart';

const String _pubspec = '''
name: spectra
publish_to: none
version: 1.0.0+1

environment:
  sdk: ^3.13.0
''';

void main() {
  group('pubspecVersion', () {
    test('reads the version line', () {
      expect(pubspecVersion(_pubspec), '1.0.0+1');
    });

    test('throws when there is no version line', () {
      expect(() => pubspecVersion('name: spectra\n'), throwsFormatException);
    });
  });

  group('parseRelease', () {
    test('a final tag carries no pre-release', () {
      final ReleaseVersion v = parseRelease(
        tag: 'v1.0.0',
        pubspecSource: _pubspec,
      );
      expect(v.core, '1.0.0');
      expect(v.preRelease, isNull);
      expect(v.isPreRelease, isFalse);
      expect(v.buildName, '1.0.0');
      expect(v.appleBuildName, '1.0.0');
      expect(v.buildNumber, 1);
      expect(v.slug, 'spectra-1.0.0');
    });

    test('a release candidate keeps the pre-release in the build name', () {
      final ReleaseVersion v = parseRelease(
        tag: 'v1.0.0-rc.1',
        pubspecSource: _pubspec,
      );
      expect(v.preRelease, 'rc.1');
      expect(v.isPreRelease, isTrue);
      expect(v.buildName, '1.0.0-rc.1');
      expect(v.slug, 'spectra-1.0.0-rc.1');
    });

    test('appleBuildName drops the pre-release', () {
      // CFBundleShortVersionString has to be three numbers; a build named
      // 1.0.0-rc.1 is rejected by Apple's tooling.
      final ReleaseVersion v = parseRelease(
        tag: 'v1.0.0-rc.1',
        pubspecSource: _pubspec,
      );
      expect(v.appleBuildName, '1.0.0');
    });

    test('rejects a tag that does not start with v', () {
      expect(
        () => parseRelease(tag: '1.0.0', pubspecSource: _pubspec),
        throwsFormatException,
      );
    });

    test('rejects a tag whose core disagrees with the pubspec', () {
      expect(
        () => parseRelease(tag: 'v1.1.0', pubspecSource: _pubspec),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('app/pubspec.yaml'),
          ),
        ),
      );
    });

    test('outputs are the keys the workflow reads', () {
      final ReleaseVersion v = parseRelease(
        tag: 'v1.0.0-rc.1',
        pubspecSource: _pubspec,
      );
      expect(v.outputs, <String, String>{
        'tag': 'v1.0.0-rc.1',
        'version': '1.0.0-rc.1',
        'build_name': '1.0.0-rc.1',
        'apple_build_name': '1.0.0',
        'build_number': '1',
        'slug': 'spectra-1.0.0-rc.1',
        'prerelease': 'true',
      });
    });

    test('the repository pubspec agrees with v1.0.0-rc.1', () {
      // Guards the real file, not a fixture: the RC tag this phase creates
      // must match the landed app version.
      final ReleaseVersion v = parseRelease(
        tag: 'v1.0.0-rc.1',
        pubspecSource: File('app/pubspec.yaml').readAsStringSync(),
      );
      expect(v.buildName, '1.0.0-rc.1');
    });
  });
}

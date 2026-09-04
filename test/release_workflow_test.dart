import 'dart:io';

import 'package:test/test.dart';

String _read(String path) => File(path).readAsStringSync();

/// The body of a top-level `  <job>:` block in a workflow file: everything
/// after its heading line up to (not including) the next line that starts
/// a sibling top-level job.
String _jobBlock(String yaml, String job) {
  final List<String> lines = yaml.split('\n');
  final int start = lines.indexWhere((String l) => l == '  $job:');
  expect(start, greaterThanOrEqualTo(0), reason: 'job $job not found');
  final int end = lines.indexWhere(
    (String l) => RegExp(r'^  \w+:$').hasMatch(l),
    start + 1,
  );
  return lines.sublist(start + 1, end == -1 ? lines.length : end).join('\n');
}

void main() {
  group('ci.yml keeps its shape', () {
    late String ci;
    setUpAll(() => ci = _read('.github/workflows/ci.yml'));

    test('is callable by the release workflow', () {
      expect(ci, contains('workflow_call:'));
    });

    test('keeps every existing trigger, job and guard', () {
      expect(ci, contains('pull_request:'));
      expect(ci, contains('workflow_dispatch:'));
      expect(ci, contains('branches: [main]'));
      expect(ci, contains('group: ci-\${{ github.ref }}'));
      expect(ci, contains('FLUTTER_VERSION: 3.47.2'));
      for (final String job in const <String>[
        'check:',
        'integration:',
        'build:',
      ]) {
        expect(ci, contains('  $job'), reason: 'lost the $job job');
      }
      expect(ci, contains("if: github.event_name != 'pull_request'"));
      expect(ci, contains(r'flutter test "$f" -d macos'));
    });
  });

  group('release.yml', () {
    late String yaml;
    setUpAll(() => yaml = _read('.github/workflows/release.yml'));

    test('triggers on a v* tag and on manual dispatch', () {
      expect(yaml, contains('workflow_dispatch:'));
      expect(yaml, contains("- 'v*'"));
      expect(yaml, contains('tags:'));
    });

    test('runs the full CI workflow before packaging anything', () {
      expect(yaml, contains('uses: ./.github/workflows/ci.yml'));
    });

    test('preflight publishes the version outputs', () {
      expect(yaml, contains('tool/check_release.dart'));
      for (final String key in const <String>[
        'build_name',
        'apple_build_name',
        'build_number',
        'slug',
        'prerelease',
      ]) {
        expect(yaml, contains('$key:'), reason: 'missing output $key');
      }
    });

    test('builds a release binary for all five platforms', () {
      expect(yaml, contains('flutter build macos --release'));
      expect(yaml, contains('flutter build windows --release'));
      expect(yaml, contains('flutter build linux --release'));
      expect(yaml, contains('flutter build apk --release'));
      expect(yaml, contains('flutter build appbundle --release'));
      expect(yaml, contains('flutter build ios --release --no-codesign'));
    });

    test('calls every packaging script', () {
      expect(yaml, contains('tool/package/macos_dmg.sh'));
      expect(yaml, contains('tool/package/windows_installer.ps1'));
      expect(yaml, contains('tool/package/linux_appimage.sh'));
      expect(yaml, contains('tool/package/ios_ipa.sh'));
    });

    test(
      'every packaging script referenced exists on disk and is executable',
      () {
        final Set<String> scripts = RegExp(r'tool/package/\S+\.(?:sh|ps1)')
            .allMatches(yaml)
            .map((RegExpMatch m) => m.group(0)!)
            .toSet();
        expect(scripts, isNotEmpty);
        for (final String script in scripts) {
          final File file = File(script);
          expect(file.existsSync(), isTrue, reason: '$script is missing');
          if (script.endsWith('.sh')) {
            final int mode = file.statSync().mode;
            expect(
              mode & 0x49,
              isNot(0),
              reason: '$script is missing its executable bit',
            );
          }
        }
      },
    );

    test('every platform job uploads an artifact', () {
      for (final String job in const <String>[
        'macos',
        'windows',
        'linux',
        'android',
        'ios',
      ]) {
        expect(
          _jobBlock(yaml, job),
          contains('actions/upload-artifact@v4'),
          reason: '$job does not upload an artifact',
        );
      }
    });

    test('every action is pinned to a major version tag', () {
      final Iterable<String> uses = RegExp(r'uses: ([^\s]+)')
          .allMatches(yaml)
          .map((RegExpMatch m) => m.group(1)!)
          .where((String u) => !u.startsWith('./'));
      expect(uses, isNotEmpty);
      for (final String u in uses) {
        expect(u, matches(RegExp(r'@v\d+$')), reason: '$u is not pinned');
      }
      expect(uses, contains('actions/checkout@v4'));
      expect(uses, contains('subosito/flutter-action@v2'));
      expect(uses, contains('actions/upload-artifact@v4'));
      expect(uses, contains('actions/download-artifact@v4'));
      expect(uses, contains('softprops/action-gh-release@v2'));
      expect(uses, contains('actions/setup-java@v4'));
    });

    test('references the signing secrets by name only', () {
      for (final String secret in const <String>[
        'MACOS_CERT_P12',
        'MACOS_CERT_PASSWORD',
        'MACOS_SIGN_IDENTITY',
        'MACOS_NOTARY_APPLE_ID',
        'MACOS_NOTARY_TEAM_ID',
        'MACOS_NOTARY_PASSWORD',
        'WINDOWS_CERT_PFX',
        'WINDOWS_CERT_PASSWORD',
        'ANDROID_KEYSTORE_BASE64',
        'ANDROID_KEYSTORE_PASSWORD',
        'ANDROID_KEY_ALIAS',
        'ANDROID_KEY_PASSWORD',
      ]) {
        expect(
          yaml,
          contains('secrets.$secret'),
          reason: '$secret is not wired',
        );
      }
    });

    test('no signing step is gated by an if:, so forks still build', () {
      expect(yaml, isNot(contains('if: \${{ secrets.')));
    });

    test('publishes a pre-release driven by the tag, and never tags 1.0.0', () {
      expect(
        yaml,
        contains('prerelease: \${{ needs.preflight.outputs.prerelease'),
      );
      expect(yaml, isNot(contains('git tag')));
      expect(yaml, isNot(contains('v1.0.0\n')));
    });

    test('keeps the CI concurrency shape', () {
      expect(yaml, contains('concurrency:'));
      expect(yaml, contains('cancel-in-progress: false'));
      expect(yaml, contains('FLUTTER_VERSION: 3.47.2'));
    });
  });
}

import 'dart:io';

import 'package:test/test.dart';

String _read(String path) => File(path).readAsStringSync();

/// The packaging scripts and workflow file the runbook must name (spec 10,
/// task 10 coordinator ruling: "the runbook must reflect the tooling as it
/// landed").
const List<String> _releaseTooling = <String>[
  'tool/check_release.dart',
  'tool/print_changelog_entry.dart',
  'tool/package/macos_dmg.sh',
  'tool/package/windows_installer.ps1',
  'tool/package/linux_appimage.sh',
  'tool/package/ios_ipa.sh',
  '.github/workflows/release.yml',
];

/// Paths the runbook describes as *destinations to create*, not things that
/// already exist in the repo (e.g. a git-ignored local secret file the user
/// copies a template to).
const Set<String> _pathsExpectedAbsent = <String>{
  'app/android/key.properties',
  // Inside the unsigned .ipa, not a path in this repo.
  'Payload/Runner.app',
};

/// Pulls every backtick-quoted, slash-containing path-like token out of
/// [doc]. Glob patterns (containing `*`) and placeholder segments
/// (containing `<`/`>`) are skipped — they are not literal paths.
Iterable<String> _referencedPaths(String doc) sync* {
  for (final RegExpMatch span in RegExp(r'`([^`\n]+)`').allMatches(doc)) {
    final String token = span.group(1)!.split(RegExp(r'\s')).first;
    if (!token.contains('/')) continue;
    if (token.contains('<') || token.contains('>')) continue;
    if (token.contains('*')) continue;
    if (token.startsWith('http')) continue;
    yield token.endsWith('/') ? token.substring(0, token.length - 1) : token;
  }
}

void main() {
  group('docs/RELEASING.md', () {
    late String doc;
    setUpAll(() => doc = _read('docs/RELEASING.md'));

    test('names every secret the workflow reads', () {
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
        expect(doc, contains(secret), reason: 'missing secret $secret');
      }
    });

    test('carries the two open user decisions', () {
      expect(doc, contains('LICENSE'));
      expect(doc, contains('app icon'));
    });

    test('documents the TestFlight route and the RC-to-final steps', () {
      expect(doc, contains('TestFlight'));
      expect(doc, contains('v1.0.0-rc.1'));
      expect(doc, contains('v1.0.0'));
    });

    test('records that the vendored usb_serial override is release-blocking to re-check', () {
      expect(doc, contains('usb_serial'));
      expect(doc, contains('third_party'));
    });

    test('names every packaging script and the release workflow file', () {
      for (final String path in _releaseTooling) {
        expect(doc, contains(path), reason: 'runbook never names $path');
      }
    });

    test('every path the runbook references actually exists', () {
      final Set<String> checked = <String>{};
      for (final String path in _referencedPaths(doc)) {
        if (!checked.add(path)) continue;
        if (_pathsExpectedAbsent.contains(path)) continue;
        expect(
          FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound,
          isTrue,
          reason: 'docs/RELEASING.md references "$path", which does not exist',
        );
      }
      // Sanity: the extractor actually found real paths, so a broken regex
      // can't make this test vacuously pass.
      expect(checked.length, greaterThan(10));
    });

    test(
      'the only literal "tag v1.0.0 now" command lives in the Cutting '
      'section, and it is explicitly framed as a later decision elsewhere',
      () {
        final RegExp bareGitTag = RegExp(r'git tag -a v1\.0\.0(?!-)');
        final List<RegExpMatch> matches = bareGitTag.allMatches(doc).toList();
        expect(
          matches,
          hasLength(1),
          reason:
              'expected exactly one literal "git tag -a v1.0.0" command, '
              'inside "## Cutting v1.0.0"',
        );
        final int cuttingStart = doc.indexOf('## Cutting v1.0.0');
        expect(cuttingStart, greaterThan(0));
        expect(matches.single.start, greaterThan(cuttingStart));

        expect(doc, contains('later, separate decision'));
        expect(doc, contains('not tagged until'));
      },
    );
  });

  group('the H3 checklist', () {
    late String doc;
    late String h3;
    setUpAll(() {
      doc = _read('docs/hardware-checklist.md');
      h3 = doc.substring(doc.indexOf('## H3'));
    });

    test('is no longer a stub', () {
      expect(h3, isNot(contains('Written in Phase 10.')));
      expect(h3.length, greaterThan(2000));
    });

    test('every spec 10 hardware item is present', () {
      for (final String item in const <String>[
        'connect',
        'pairing',
        'slot round trip',
        'HF',
        'LF',
        'USB DFU',
        'BLE DFU',
        'interrupted',
      ]) {
        expect(h3.toLowerCase(), contains(item.toLowerCase()));
      }
    });

    test('every item is still pending', () {
      final Iterable<RegExpMatch> boxes = RegExp(
        r'^- \[( |x)\]',
        multiLine: true,
      ).allMatches(h3);
      expect(boxes, isNotEmpty);
      for (final RegExpMatch m in boxes) {
        expect(
          m.group(1),
          ' ',
          reason: 'an H3 box was ticked without a report',
        );
      }
      expect(h3, contains('pending'));
    });

    test('tells the user which artifact to install per platform', () {
      expect(h3, contains('.dmg'));
      expect(h3, contains('setup.exe'));
      expect(h3, contains('AppImage'));
      expect(h3, contains('.apk'));
    });

    test('has a sign-off list that gates v1.0.0', () {
      expect(h3, contains('sign-off'));
      expect(h3, contains('v1.0.0'));
    });

    test('still contains the pre-existing Phase 6 items', () {
      expect(h3.toLowerCase(), contains('reference'));
      expect(h3, contains('EM410x'));
    });
  });
}

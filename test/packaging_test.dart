import 'dart:io';

import 'package:test/test.dart';

String _read(String path) => File(path).readAsStringSync();

bool _isExecutable(String path) =>
    // 0o100 is the owner-execute bit.
    File(path).statSync().mode & 0x40 != 0;

void main() {
  group('macOS dmg script', () {
    late String script;
    setUpAll(() => script = _read('tool/package/macos_dmg.sh'));

    test('is executable and fails fast', () {
      expect(_isExecutable('tool/package/macos_dmg.sh'), isTrue);
      expect(script, contains('set -euo pipefail'));
    });

    test('signs with the release entitlements and the hardened runtime', () {
      expect(script, contains('app/macos/Runner/Release.entitlements'));
      expect(script, contains('--options runtime'));
      expect(script, contains('codesign'));
    });

    test('falls back to an ad-hoc signature with no identity', () {
      expect(script, contains(r'${MACOS_SIGN_IDENTITY:-}'));
      expect(script, contains('ad-hoc'));
      expect(script, contains('--sign -'));
    });

    test('notarizes only when all three credentials are present', () {
      expect(script, contains('notarytool submit'));
      expect(script, contains('stapler staple'));
      expect(script, contains(r'${MACOS_NOTARY_APPLE_ID:-}'));
      expect(script, contains(r'${MACOS_NOTARY_TEAM_ID:-}'));
      expect(script, contains(r'${MACOS_NOTARY_PASSWORD:-}'));
      expect(script, contains('skipping notarization'));
    });

    test('builds the dmg with hdiutil', () {
      expect(script, contains('hdiutil create'));
      expect(script, contains('/Applications'));
    });

    test('never echoes a secret', () {
      for (final String secret in const <String>[
        'MACOS_CERT_P12',
        'MACOS_CERT_PASSWORD',
        'MACOS_NOTARY_PASSWORD',
      ]) {
        expect(
          script,
          isNot(contains('echo "\$$secret')),
          reason: '$secret must never be echoed',
        );
      }
    });
  });
}

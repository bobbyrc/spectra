import 'dart:io';

import 'package:test/test.dart';

import '../tool/src/license_status.dart';

void main() {
  group('licenseStateOf', () {
    test('a missing file is missing', () {
      expect(licenseStateOf(null), LicenseState.missing);
    });

    test('the flutter create template is a TODO', () {
      expect(
        licenseStateOf('TODO: Add your license here.\n'),
        LicenseState.todo,
      );
    });

    test('anything else counts as chosen', () {
      expect(
        licenseStateOf('MIT License\n\nCopyright (c) 2026\n'),
        LicenseState.chosen,
      );
    });

    test('an empty file is still a TODO, not a licence', () {
      expect(licenseStateOf('   \n'), LicenseState.todo);
    });
  });

  test('the repository still has an undecided licence', () {
    // The user chooses the licence, not an agent. This test documents the
    // current state; when a licence is chosen, update the expectation.
    final Map<String, LicenseState> states = licenseStates(Directory.current);
    expect(
      states.keys,
      containsAll(<String>[
        'packages/chameleon',
        'packages/chameleon_flutter',
        'packages/spectra_ui',
        'app',
      ]),
    );
    expect(states.values, isNot(everyElement(LicenseState.chosen)));
  });

  test('check_release exits 0 despite the licence TODO', () async {
    final ProcessResult r = await Process.run('dart', <String>[
      'run',
      'tool/check_release.dart',
      '--tag',
      'v1.0.0-rc.1',
    ]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(r.stdout, contains('license: '));
    expect(r.stdout, contains('build_name=1.0.0-rc.1'));
  });

  test('check_release rejects a tag with no changelog entry', () async {
    final ProcessResult r = await Process.run('dart', <String>[
      'run',
      'tool/check_release.dart',
      '--tag',
      'v9.9.9',
    ]);
    expect(r.exitCode, 1);
  });
}

import 'dart:io';

import 'package:test/test.dart';

String _read(String path) => File(path).readAsStringSync();

bool _isExecutable(String path) =>
    // 0o100 is the owner-execute bit.
    File(path).statSync().mode & 0x40 != 0;

void main() {
  group('iOS ipa script', () {
    late String script;
    setUpAll(() => script = _read('tool/package/ios_ipa.sh'));

    test('is executable and fails fast', () {
      expect(_isExecutable('tool/package/ios_ipa.sh'), isTrue);
      expect(script, contains('set -euo pipefail'));
    });

    test('wraps the app in a Payload directory', () {
      expect(script, contains('Payload'));
      expect(script, contains('zip -r'));
    });

    test('says out loud that the ipa is unsigned', () {
      expect(script, contains('unsigned'));
      expect(script, contains('docs/RELEASING.md'));
    });

    test('runs end to end against a fake unsigned Runner.app', () async {
      final Directory tempDir = Directory.systemTemp.createTempSync(
        'ios_ipa_test_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final String appPath = '${tempDir.path}/Runner.app';
      Directory(appPath).createSync(recursive: true);
      File('$appPath/Info.plist').writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Runner</string>
<key>CFBundleIdentifier</key><string>dev.spectra.spectra</string>
</dict></plist>
''');
      final File executable = File('$appPath/Runner')
        ..writeAsStringSync('#!/bin/sh\n');
      Process.runSync('chmod', <String>['+x', executable.path]);

      final String outIpa = '${tempDir.path}/out/spectra-ios-unsigned.ipa';

      final ProcessResult result = await Process.run('bash', <String>[
        'tool/package/ios_ipa.sh',
        appPath,
        outIpa,
      ]);

      expect(
        result.exitCode,
        0,
        reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
      );
      expect(File(outIpa).existsSync(), isTrue);

      final ProcessResult listing = await Process.run('unzip', <String>[
        '-l',
        outIpa,
      ]);
      expect(listing.exitCode, 0);
      expect(listing.stdout, contains('Payload/Runner.app/Info.plist'));

      expect(result.stdout, contains('unsigned'));
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}

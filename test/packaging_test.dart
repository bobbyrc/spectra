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

    test(
      'runs end to end against a fake app with no signing configured',
      () async {
        final Directory tempDir = Directory.systemTemp.createTempSync(
          'macos_dmg_test_',
        );
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final String appPath = '${tempDir.path}/Spectra.app';
        final Directory macosDir = Directory('$appPath/Contents/MacOS')
          ..createSync(recursive: true);
        File('$appPath/Contents/Info.plist').writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>spectra</string>
<key>CFBundleIdentifier</key><string>dev.spectra.spectra</string>
</dict></plist>
''');
        final File executable = File('${macosDir.path}/spectra')
          ..writeAsStringSync('#!/bin/sh\n');
        Process.runSync('chmod', <String>['+x', executable.path]);

        final String outDmg = '${tempDir.path}/out/spectra.dmg';

        final ProcessResult result = await Process.run(
          'bash',
          <String>['tool/package/macos_dmg.sh', appPath, outDmg],
          environment: <String, String>{'RUNNER_TEMP': tempDir.path},
        );

        expect(
          result.exitCode,
          0,
          reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
        );
        expect(File(outDmg).existsSync(), isTrue);
        expect(
          result.stdout,
          contains(
            'macos_dmg: no signing identity and no notary credentials '
            '— ad-hoc signed, not notarized',
          ),
        );
      },
      timeout: const Timeout(Duration(seconds: 20)),
      // hdiutil and codesign only exist on macOS; the Linux `check` job
      // still runs the static assertions above.
      skip: Platform.isMacOS ? false : 'needs hdiutil/codesign (macOS only)',
    );
  });

  group('Windows installer', () {
    late String ps1;
    late String iss;
    setUpAll(() {
      ps1 = _read('tool/package/windows_installer.ps1');
      iss = _read('tool/package/windows/spectra.iss');
    });

    test('stops on the first error', () {
      expect(ps1, contains(r"$ErrorActionPreference = 'Stop'"));
    });

    test('produces both an installer and a portable zip', () {
      expect(ps1, contains('ISCC'));
      expect(ps1, contains('Compress-Archive'));
      expect(ps1, contains('-windows-setup.exe'));
      expect(ps1, contains('-windows.zip'));
    });

    test('signing degrades when the certificate is absent', () {
      expect(ps1, contains('WINDOWS_CERT_PFX'));
      expect(ps1, contains('WINDOWS_CERT_PASSWORD'));
      expect(ps1, contains('signtool'));
      expect(ps1, contains('skipping code signing'));
    });

    test('resolves ISCC from PATH, then the default install path, then '
        'fails clearly', () {
      expect(ps1, contains("Get-Command 'ISCC.exe'"));
      expect(ps1, contains(r'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'));
      expect(ps1, contains('choco install innosetup'));
      expect(ps1, contains('ISCC.exe not found on PATH'));
    });

    test('quotes paths passed to native executables', () {
      expect(ps1, contains('/f "\$pfxPath"'));
      expect(ps1, contains('/td SHA256 "\$Path"'));
      expect(ps1, contains('"\$iss"'));
    });

    test('the Inno script names the landed app identity', () {
      expect(iss, contains('AppName=Spectra'));
      expect(iss, contains('dev.spectra.spectra'));
      expect(iss, contains('spectra.exe'));
      expect(iss, contains('{#AppVersion}'));
      expect(iss, contains('ArchitecturesInstallIn64BitMode=x64compatible'));
    });

    test('AppId is a stable GUID, not the bundle identifier string', () {
      expect(iss, contains(RegExp(r'#define AppId "\{\{[0-9A-Fa-f-]{36}\}"')));
    });
  });

  group('Linux AppImage', () {
    late String script;
    late String desktop;
    setUpAll(() {
      script = _read('tool/package/linux_appimage.sh');
      desktop = _read('tool/package/linux/spectra.desktop');
    });

    test('is executable and fails fast', () {
      expect(_isExecutable('tool/package/linux_appimage.sh'), isTrue);
      expect(script, contains('set -euo pipefail'));
    });

    test('runs appimagetool without FUSE', () {
      // GitHub runners have no FUSE; the AppImage has to extract itself.
      expect(script, contains('appimagetool'));
      expect(script, contains('--appimage-extract-and-run'));
    });

    test('emits both the AppImage and a tarball', () {
      expect(script, contains('linux-x86_64.AppImage'));
      expect(script, contains('linux-x64.tar.gz'));
    });

    test('writes an AppRun that launches the landed binary name', () {
      expect(script, contains('AppRun'));
      expect(script, contains('spectra'));
      expect(script, contains('usr/lib'));
    });

    test('lays out the whole bundle intact at usr/lib/spectra, not split into '
        'usr/bin', () {
      // A Flutter Linux bundle resolves data/ and lib/ relative to its
      // own real executable path, not the working directory: splitting
      // the binary out to usr/bin (leaving data/ and lib/ behind) builds
      // but cannot launch.
      expect(script, contains('usr/lib/spectra'));
      expect(script, contains('HERE/usr/lib/spectra/spectra'));
    });

    test('the desktop entry uses the landed application id', () {
      expect(desktop, contains('Name=Spectra'));
      expect(desktop, contains('Exec=spectra'));
      expect(desktop, contains('Categories=Utility;'));
      expect(desktop, contains('Icon=dev.spectra.spectra'));
    });

    test('runs end to end against a fake bundle: tarball, AppDir layout, and '
        'a graceful skip when appimagetool is absent', () async {
      final Directory tempDir = Directory.systemTemp.createTempSync(
        'linux_appimage_test_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      // A minimal fake Flutter Linux bundle: binary, data/, lib/ side by
      // side, exactly what `flutter build linux` produces.
      final String bundlePath = '${tempDir.path}/bundle';
      Directory('$bundlePath/data').createSync(recursive: true);
      Directory('$bundlePath/lib').createSync(recursive: true);
      File('$bundlePath/data/flutter_assets.txt')
          .writeAsStringSync('fake asset\n');
      File('$bundlePath/lib/libflutter_linux_gtk.so.txt')
          .writeAsStringSync('fake lib\n');
      final File executable = File('$bundlePath/spectra')
        ..writeAsStringSync('#!/bin/sh\necho fake spectra\n');
      Process.runSync('chmod', <String>['+x', executable.path]);

      final String outDir = '${tempDir.path}/out';

      final ProcessResult result = await Process.run('bash', <String>[
        'tool/package/linux_appimage.sh',
        bundlePath,
        '1.0.0-test',
        outDir,
      ]);

      expect(
        result.exitCode,
        0,
        reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
      );

      // The tarball always lands, regardless of appimagetool.
      expect(
        File('$outDir/spectra-1.0.0-test-linux-x64.tar.gz').existsSync(),
        isTrue,
      );

      // Find the AppDir the script built, from its own stdout, and check
      // the layout the launch-path ruling requires: the whole bundle
      // intact at usr/lib/spectra, not split into usr/bin.
      final RegExpMatch? match = RegExp(r'wrote AppDir at (\S+)')
          .firstMatch(result.stdout as String);
      expect(match, isNotNull, reason: 'stdout: ${result.stdout}');
      final String appDir = match!.group(1)!;
      addTearDown(() => Directory(appDir).parent.deleteSync(recursive: true));

      expect(File('$appDir/usr/lib/spectra/spectra').existsSync(), isTrue);
      expect(Directory('$appDir/usr/lib/spectra/data').existsSync(), isTrue);
      expect(Directory('$appDir/usr/lib/spectra/lib').existsSync(), isTrue);
      expect(_read('$appDir/AppRun'), contains('usr/lib/spectra/spectra'));

      // This machine (macOS, or any runner without appimagetool) must
      // skip the AppImage step with a clear notice, not fail.
      if (Process.runSync('which', <String>['appimagetool']).exitCode != 0) {
        expect(result.stdout, contains('appimagetool not found on PATH'));
        expect(
          File('$outDir/spectra-1.0.0-test-linux-x86_64.AppImage').existsSync(),
          isFalse,
        );
      }
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}

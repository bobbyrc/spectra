/// Release preflight (spec 10). Validates the tag against
/// `app/pubspec.yaml` and `CHANGELOG.md`, reports the licence state as a
/// warning, and emits the workflow outputs.
///
///   dart run tool/check_release.dart --tag v1.0.0-rc.1
library;

import 'dart:io';

import 'src/changelog.dart';
import 'src/license_status.dart';
import 'src/release_version.dart';

void main(List<String> args) {
  final int i = args.indexOf('--tag');
  if (i < 0 || i + 1 >= args.length) {
    stderr.writeln('usage: dart run tool/check_release.dart --tag vX.Y.Z');
    exit(64);
  }
  final String tag = args[i + 1];

  final ReleaseVersion version;
  final ChangelogEntry entry;
  try {
    version = parseRelease(
      tag: tag,
      pubspecSource: File('app/pubspec.yaml').readAsStringSync(),
    );
    entry = latestReleasedEntry(File('CHANGELOG.md').readAsStringSync());
  } on FormatException catch (e) {
    stderr.writeln('check_release: ${e.message}');
    exit(1);
  }

  if (entry.version != version.buildName) {
    stderr.writeln(
      'check_release: CHANGELOG.md\'s newest entry is ${entry.version} but '
      'the tag builds ${version.buildName}; add the entry before tagging',
    );
    exit(1);
  }

  // A licence TODO never fails the release: the user picks the licence.
  licenseStates(Directory.current).forEach((String pkg, LicenseState state) {
    final String note = switch (state) {
      LicenseState.chosen => 'ok',
      LicenseState.todo => 'TODO — the user has not chosen a licence yet',
      LicenseState.missing => 'no LICENSE file yet',
    };
    stdout.writeln('license: $pkg: $note');
  });

  final String? outputPath = Platform.environment['GITHUB_OUTPUT'];
  final StringBuffer buffer = StringBuffer();
  version.outputs.forEach((String k, String v) => buffer.writeln('$k=$v'));
  stdout.write(buffer);
  if (outputPath != null && outputPath.isNotEmpty) {
    File(outputPath)
        .writeAsStringSync(buffer.toString(), mode: FileMode.append);
  }
  stdout.writeln('check_release: ok (${version.buildName})');
}

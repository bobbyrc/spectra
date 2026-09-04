/// Prints the newest released `CHANGELOG.md` entry's body (spec 10: the
/// release workflow uses this for the GitHub release body instead of a
/// `sed`/`head` extraction that can truncate or bleed into the next entry).
///
///   dart run tool/print_changelog_entry.dart
library;

import 'dart:io';

import 'src/changelog.dart';

void main() {
  final String source = File('CHANGELOG.md').readAsStringSync();
  stdout.write(latestReleasedEntry(source).body);
}

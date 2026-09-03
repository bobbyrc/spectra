import 'dart:io';

import 'src/dep_rules.dart';

const _members = {
  'chameleon': 'packages/chameleon',
  'chameleon_flutter': 'packages/chameleon_flutter',
  'spectra_ui': 'packages/spectra_ui',
  'spectra_ui_gallery': 'packages/spectra_ui/example',
  'spectra': 'app',
};

int runDepLint(Directory root) {
  var count = 0;
  for (final entry in _members.entries) {
    final dir = Directory('${root.path}/${entry.value}');
    if (!dir.existsSync()) continue;
    for (final sub in const ['lib', 'test', 'integration_test']) {
      final d = Directory('${dir.path}/$sub');
      if (!d.existsSync()) continue;
      for (final f in d.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final rel = f.path.substring(dir.path.length + 1);
        final violations = checkFile(
          packageName: entry.key,
          relativePath: rel,
          imports: extractImports(f.readAsStringSync()),
        );
        for (final v in violations) {
          stderr.writeln('${entry.value}/$v');
          count++;
        }
      }
    }
  }
  return count;
}

void main() {
  final count = runDepLint(Directory.current);
  if (count > 0) {
    stderr.writeln('dep_lint: $count violation(s)');
    exit(1);
  }
  stdout.writeln('dep_lint: ok');
}

/// Reports each package's LICENSE state without judging it. Choosing a
/// licence is the user's decision (AGENTS.md, "Decisions made overnight"),
/// so the release preflight warns and carries on.
library;

import 'dart:io';

enum LicenseState { chosen, todo, missing }

/// Directories that ship a LICENSE, relative to the workspace root.
const List<String> licensedPackages = <String>[
  'packages/chameleon',
  'packages/chameleon_flutter',
  'packages/spectra_ui',
  'app',
];

LicenseState licenseStateOf(String? contents) {
  if (contents == null) return LicenseState.missing;
  final String text = contents.trim();
  if (text.isEmpty || text.startsWith('TODO')) return LicenseState.todo;
  return LicenseState.chosen;
}

Map<String, LicenseState> licenseStates(Directory root) {
  return <String, LicenseState>{
    for (final String pkg in licensedPackages)
      pkg: licenseStateOf(_read('${root.path}/$pkg/LICENSE')),
  };
}

String? _read(String path) {
  final File file = File(path);
  return file.existsSync() ? file.readAsStringSync() : null;
}

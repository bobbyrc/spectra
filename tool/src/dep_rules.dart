/// Pure evaluation of the dependency rules from spec section 2 and 8.4.
library;

final class Violation {
  const Violation(this.rule, this.file, this.import, this.message);
  final String rule;
  final String file;
  final String import;
  final String message;

  @override
  String toString() => '$file: [$rule] $import: $message';
}

/// Packages each workspace member may import, besides itself and `dart:`.
///
/// This is a deliberate superset of the spec section 2 table: `crypto` and
/// `freezed_annotation` for `chameleon`, `intl` for `spectra_ui`, and
/// `go_router` for the gallery are needed in practice even though the table
/// doesn't list them. `freezed` (the generator) is never imported by source,
/// only run via build_runner, so it is absent here on purpose. See
/// `docs/research/DECISIONS.md` for the reasoning.
const Map<String, Set<String>> allowlists = {
  'chameleon': {
    'meta',
    'collection',
    'freezed_annotation',
    'archive',
    'crypto',
  },
  'chameleon_flutter': {
    'chameleon',
    'flutter',
    'universal_ble',
    'libserialport_plus',
    'usb_serial',
  },
  'spectra_ui': {
    'flutter',
    'material_ui',
    'google_fonts',
    'flutter_animate',
    'flutter_localizations',
    'intl',
  },
  'spectra_ui_gallery': {'flutter', 'spectra_ui', 'material_ui', 'go_router'},
  'serial_probe': {'flutter', 'chameleon', 'chameleon_flutter'},
};

/// Packages any member may import from `test/` or `integration_test/`.
const Set<String> testOnly = {
  'test',
  'flutter_test',
  'fake_async',
  'mocktail',
  'alchemist',
  'integration_test',
};

const String appPackage = 'spectra';

List<String> extractImports(String source) {
  final out = <String>[];
  final re = RegExp(
    r'''^\s*(import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );
  for (final m in re.allMatches(source)) {
    out.add(m.group(2)!);
  }
  return out;
}

String? _packageOf(String import) {
  if (!import.startsWith('package:')) return null;
  final rest = import.substring('package:'.length);
  final slash = rest.indexOf('/');
  return slash < 0 ? rest : rest.substring(0, slash);
}

bool _isTestPath(String p) =>
    p.startsWith('test/') || p.startsWith('integration_test/');

/// Resolves a relative import (e.g. `'../../slots/slots.dart'`) written in
/// [relativePath] to a path from the package root, normalising `.` and
/// `..` segments. No `package:path` dependency needed for this.
String _resolveRelativeImport(String relativePath, String imp) {
  final lastSlash = relativePath.lastIndexOf('/');
  final fileDir = lastSlash < 0 ? '' : relativePath.substring(0, lastSlash);
  final segments = fileDir.isEmpty ? <String>[] : fileDir.split('/');
  for (final part in imp.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (segments.isNotEmpty) segments.removeLast();
    } else {
      segments.add(part);
    }
  }
  return segments.join('/');
}

/// For the app package, resolves a relative import written in
/// [relativePath] to the `package:spectra/...` form the structural rules
/// expect, so those rules see through relative imports the same way they
/// see `package:` imports. Returns null when the import isn't relative or
/// doesn't resolve under `lib/`.
String? _resolveAppRelativeImport(String relativePath, String imp) {
  if (imp.startsWith('dart:')) return null;
  final resolved = _resolveRelativeImport(relativePath, imp);
  if (!resolved.startsWith('lib/')) return null;
  return 'package:$appPackage/${resolved.substring('lib/'.length)}';
}

List<Violation> checkFile({
  required String packageName,
  required String relativePath,
  required List<String> imports,
}) {
  final out = <Violation>[];
  final isTest = _isTestPath(relativePath);
  for (final imp in imports) {
    final pkg = _packageOf(imp);
    if (pkg == null) {
      // dart: or relative import.
      if (packageName == appPackage && !isTest) {
        final synthImp = _resolveAppRelativeImport(relativePath, imp);
        if (synthImp != null) {
          out.addAll(_checkApp(relativePath, synthImp, appPackage));
        }
      }
      continue;
    }

    if (pkg == 'chameleon' &&
        imp.startsWith('package:chameleon/src/') &&
        packageName != 'chameleon') {
      out.add(
        Violation(
          'sdk-internals',
          relativePath,
          imp,
          'commands and internals are private to the SDK',
        ),
      );
    }

    if (packageName == appPackage) {
      if (!isTest) out.addAll(_checkApp(relativePath, imp, pkg));
      continue;
    }

    if (pkg == packageName) continue;
    final allowed = allowlists[packageName];
    if (allowed == null) continue; // unknown package: no rule
    final ok =
        allowed.contains(pkg) ||
        (_isTestPath(relativePath) && testOnly.contains(pkg));
    if (!ok) {
      out.add(
        Violation(
          'package-allowlist',
          relativePath,
          imp,
          '$packageName may not depend on $pkg',
        ),
      );
    }
  }
  return out;
}

List<Violation> _checkApp(String path, String imp, String pkg) {
  final out = <Violation>[];
  final inFeatures = path.startsWith('lib/features/');
  if (inFeatures && pkg == 'flutter' && imp.endsWith('/material.dart')) {
    out.add(
      Violation(
        'no-material-in-features',
        path,
        imp,
        'import package:material_ui/material_ui.dart (or '
            'package:flutter/widgets.dart), never the SDK Material library: '
            'the two define the same names and importing both does not '
            'compile',
      ),
    );
  }
  if ((pkg == 'drift' || pkg.startsWith('drift_')) &&
      !path.startsWith('lib/data/')) {
    out.add(
      Violation(
        'drift-in-data-only',
        path,
        imp,
        'Drift may only appear under lib/data/',
      ),
    );
  }
  if (inFeatures && imp.startsWith('package:$appPackage/features/')) {
    final me = path.split('/')[2];
    final target = imp.substring('package:$appPackage/features/'.length);
    final parts = target.split('/');
    final other = parts.first;
    final isBarrel = parts.length == 2 && parts[1] == '$other.dart';
    if (other != me && !isBarrel) {
      out.add(
        Violation(
          'feature-internals',
          path,
          imp,
          'feature $me may only import features/$other/$other.dart',
        ),
      );
    }
  }
  return out;
}

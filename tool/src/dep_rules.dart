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

List<Violation> checkFile({
  required String packageName,
  required String relativePath,
  required List<String> imports,
}) {
  final out = <Violation>[];
  for (final imp in imports) {
    final pkg = _packageOf(imp);
    if (pkg == null) continue; // dart: or relative

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
      out.addAll(_checkApp(relativePath, imp, pkg));
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
        'use spectra_ui components instead of raw Material',
      ),
    );
  }
  if (pkg == 'drift' && !path.startsWith('lib/data/')) {
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

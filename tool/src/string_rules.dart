/// Spec 7.6: "a lint fails on string literals in `ui/` folders". This is
/// that lint, kept deliberately textual (a regex scan of the raw source)
/// rather than analyzer-based — the analyzer plugin API is not worth the
/// weight for one rule.
///
/// The scan is a heuristic: it does not parse Dart, so it cannot tell a
/// literal inside a `//` line comment (other than the `l10n-exempt` marker
/// line) or a block comment from real code, and it does not understand
/// string interpolation beyond "this argument is not a bare string
/// literal". It is deliberately conservative about *where* it looks
/// (`isLocalizedUiPath`) rather than clever about parsing.
library;

import 'dep_rules.dart' show Violation;

/// `Text(` (optionally `const`), then optional whitespace/newlines, then a
/// bare string literal. Deliberately does not match `Text.rich(` — spec
/// 7.6 is about plain text content, and `Text.rich` composes `TextSpan`s
/// whose own literals are covered separately if/when that becomes an issue.
final RegExp _textCall = RegExp(
  r'''\bText\(\s*(?:const\s+)?(['"])((?:\\.|(?!\1)[^\\\n])*)\1''',
);

/// Named arguments whose value is user-facing copy when given a bare
/// string literal.
final RegExp _namedArg = RegExp(
  r'''\b(?:label|title|hintText|helperText|semanticsLabel|tooltip):\s*'''
  r'''(['"])((?:\\.|(?!\1)[^\\\n])*)\1''',
);

final RegExp _featureUi = RegExp(r'^lib/features/[^/]+/ui/');

/// True when [relativePath] in [packageName] holds user-facing UI whose
/// copy must be localized (spec 7.6): the design-system kit's components,
/// or the app's per-feature `ui/` folders at any depth. Everything else —
/// tokens, theme, state, data, the gallery's sample pages, and all test
/// paths — is out of scope.
bool isLocalizedUiPath(String packageName, String relativePath) {
  if (packageName == 'spectra_ui') {
    return relativePath.startsWith('lib/src/components/');
  }
  if (packageName == appPackageForLocalization) {
    return _featureUi.hasMatch(relativePath);
  }
  return false;
}

/// The app package name, kept local to this file so `string_rules.dart`
/// has no dependency on `dep_rules.dart`'s `appPackage` beyond `Violation`.
const String appPackageForLocalization = 'spectra';

/// Flags bare string literals handed to `Text(` or to a handful of
/// known user-facing named arguments, in files `isLocalizedUiPath` covers.
/// A line carrying `// l10n-exempt` is skipped, for genuinely
/// non-user-facing text such as a hex sample or a debug affordance. Empty
/// literals (`''`, `""`) are never flagged.
List<Violation> checkTextLiterals({
  required String packageName,
  required String relativePath,
  required String source,
}) {
  if (!isLocalizedUiPath(packageName, relativePath)) {
    return const <Violation>[];
  }

  final List<_Hit> hits = <_Hit>[
    ..._matches(source, _textCall),
    ..._matches(source, _namedArg),
  ]..sort((a, b) => a.start.compareTo(b.start));

  final List<Violation> out = <Violation>[];
  for (final _Hit hit in hits) {
    if (hit.literal.isEmpty) continue;
    final int lineStart = source.lastIndexOf('\n', hit.start) + 1;
    int lineEnd = source.indexOf('\n', hit.start);
    if (lineEnd < 0) lineEnd = source.length;
    final String line = source.substring(lineStart, lineEnd);
    if (line.contains('l10n-exempt')) continue;

    final int lineNumber =
        '\n'.allMatches(source.substring(0, hit.start)).length + 1;
    out.add(
      Violation(
        'no-literal-text',
        relativePath,
        'line $lineNumber: ${hit.quote}${hit.literal}${hit.quote}',
        'user-facing text must come from SpectraUiLocalizations; '
            'mark genuinely non-user-facing strings with // l10n-exempt',
      ),
    );
  }
  return out;
}

class _Hit {
  const _Hit(this.start, this.quote, this.literal);
  final int start;
  final String quote;
  final String literal;
}

Iterable<_Hit> _matches(String source, RegExp pattern) sync* {
  for (final RegExpMatch m in pattern.allMatches(source)) {
    final String quote = m.group(1)!;
    final String literal = m.group(2)!;
    // `Match` exposes only whole-match offsets, not per-group offsets, so
    // derive the opening quote's position from the end of the match: it is
    // always `quote + literal + quote` immediately before `m.end`.
    final int quoteStart = m.end - literal.length - 2 * quote.length;
    yield _Hit(quoteStart, quote, literal);
  }
}

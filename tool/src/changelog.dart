/// Reads `CHANGELOG.md`, which follows Keep a Changelog 1.1.0 (spec 10:
/// "semantic versions, a changelog").
library;

/// One `## [x.y.z] - date` section.
class ChangelogEntry {
  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.body,
  });

  final String version;
  final String date;

  /// Everything under the heading, up to the next heading.
  final String body;
}

final RegExp _heading = RegExp(
  r'^## \[([^\]]+)\](?:\s*-\s*(\d{4}-\d{2}-\d{2}))?\s*$',
  multiLine: true,
);

/// The newest entry that is not `[Unreleased]`.
ChangelogEntry latestReleasedEntry(String source) {
  final List<RegExpMatch> headings = _heading.allMatches(source).toList();
  for (int i = 0; i < headings.length; i++) {
    final RegExpMatch h = headings[i];
    final String version = h.group(1)!;
    if (version.toLowerCase() == 'unreleased') continue;
    final int start = h.end;
    final int end = i + 1 < headings.length
        ? headings[i + 1].start
        : source.length;
    return ChangelogEntry(
      version: version,
      date: h.group(2) ?? '',
      body: source.substring(start, end).trim(),
    );
  }
  throw const FormatException('CHANGELOG.md has no released entry');
}

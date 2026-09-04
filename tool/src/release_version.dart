/// Reconciles a `v*` git tag with `app/pubspec.yaml` and derives every
/// version string the release workflow needs (spec 10: semantic versions).
library;

/// The version identity of one release build.
class ReleaseVersion {
  const ReleaseVersion({
    required this.tag,
    required this.core,
    required this.preRelease,
    required this.buildNumber,
  });

  /// The git tag, including the leading `v`.
  final String tag;

  /// `major.minor.patch`.
  final String core;

  /// The part after `-`, or null for a final release.
  final String? preRelease;

  /// The `+N` from `app/pubspec.yaml`.
  final int buildNumber;

  bool get isPreRelease => preRelease != null;

  /// What `flutter build --build-name` gets everywhere but Apple.
  String get buildName => preRelease == null ? core : '$core-$preRelease';

  /// CFBundleShortVersionString must be three dotted numbers, so Apple
  /// targets get the core only; the RC identity lives in the tag and in the
  /// artifact file names.
  String get appleBuildName => core;

  /// The artifact file-name stem.
  String get slug => 'spectra-$buildName';

  /// `key=value` pairs the workflow copies into `GITHUB_OUTPUT`.
  Map<String, String> get outputs => <String, String>{
    'tag': tag,
    'version': buildName,
    'build_name': buildName,
    'apple_build_name': appleBuildName,
    'build_number': '$buildNumber',
    'slug': slug,
    'prerelease': '$isPreRelease',
  };
}

final RegExp _tagPattern = RegExp(r'^v(\d+\.\d+\.\d+)(?:-([0-9A-Za-z.-]+))?$');
final RegExp _versionLine = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true);

/// The `version:` line of a pubspec, e.g. `1.0.0+1`.
String pubspecVersion(String pubspecSource) {
  final RegExpMatch? match = _versionLine.firstMatch(pubspecSource);
  if (match == null) {
    throw const FormatException('no version: line in the pubspec');
  }
  return match.group(1)!;
}

/// Parses [tag] and checks it against the pubspec's own version.
ReleaseVersion parseRelease({
  required String tag,
  required String pubspecSource,
}) {
  final RegExpMatch? match = _tagPattern.firstMatch(tag);
  if (match == null) {
    throw FormatException(
      'release tag "$tag" is not vMAJOR.MINOR.PATCH[-PRERELEASE]',
    );
  }
  final String core = match.group(1)!;
  final String raw = pubspecVersion(pubspecSource);
  final List<String> parts = raw.split('+');
  if (parts.first != core) {
    throw FormatException(
      'tag "$tag" says $core but app/pubspec.yaml says ${parts.first}; '
      'bump the pubspec or fix the tag',
    );
  }
  final int buildNumber = parts.length > 1 ? int.parse(parts[1]) : 1;
  return ReleaseVersion(
    tag: tag,
    core: core,
    preRelease: match.group(2),
    buildNumber: buildNumber,
  );
}

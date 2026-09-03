import 'dart:typed_data';

/// Bytes as upper-case hex. The one hex formatter in the app: the SDK keeps
/// its own `hexOf` internal (see `package:chameleon`'s library directive),
/// so this is the app's copy rather than a reach into `src/`.
String toHex(List<int> bytes, {String separator = ''}) => bytes
    .map((int b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(separator);

final RegExp _notHexSeparator = RegExp(r'[\s:_-]');
final RegExp _hexOnly = RegExp(r'^[0-9a-fA-F]*$');

/// Parses a hex string, tolerating spaces, colons, underscores and dashes.
/// Returns null when the text is not an even-length run of hex digits, so a
/// caller validates by checking for null rather than catching.
Uint8List? parseHex(String text) {
  final String cleaned = text.replaceAll(_notHexSeparator, '');
  if (cleaned.length.isOdd) return null;
  if (!_hexOnly.hasMatch(cleaned)) return null;
  final Uint8List out = Uint8List(cleaned.length ~/ 2);
  for (int i = 0; i < out.length; i++) {
    out[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

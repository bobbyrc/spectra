/// `[0, 3, 7]` -> `"0, 3 and 7"`; a single sector -> `"0"`.
///
/// Sector indexes are shown 0-based, the way both card sheets and the SDK
/// count them — unlike slot numbers, which are printed 1..8 on the device
/// and converted at the last moment.
///
/// Shared by the load-to-slot and write-to-card sheets, which said the same
/// sentence about the same list from two private copies of this function
/// (review M4). The comma-and-"and" joining is deliberately not localized:
/// it is a list of numbers, and the surrounding sentence — which *is*
/// localized — supplies every word around it.
String formatSectorList(List<int> sectors) {
  final List<String> parts = sectors.map((int s) => '$s').toList();
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.single;
  final String head = parts.sublist(0, parts.length - 1).join(', ');
  return '$head and ${parts.last}';
}

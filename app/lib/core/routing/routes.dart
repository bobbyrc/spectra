/// Every location in the app, in one place, so no screen types a path.
abstract final class AppRoutes {
  static const String connect = '/connect';
  static const String device = '/device';
  static const String slots = '/slots';
  static const String cards = '/cards';
  static const String tools = '/tools';
  static const String frameLog = '/tools/frame-log';
  static const String update = '/tools/update';
  static const String settings = '/settings';

  /// The key lists (spec 7.2 puts dictionaries in the Tools tab).
  static const String dictionaries = '$tools/dictionaries';

  /// One key list's detail screen.
  static String dictionary(String id) =>
      '$dictionaries/${Uri.encodeComponent(id)}';

  /// The bootloader recovery entry (spec 5.5): the update screen, told which
  /// bootloader to talk to. Phase 8 reads the `recover` query parameter.
  static String recover(String transportId) =>
      '$update?recover=${Uri.encodeComponent(transportId)}';

  /// The slot editor (spec 7.2: a deep route pushed on top of its tab).
  /// [index] is the wire index, 0..7.
  static String slot(int index) => '$slots/$index';

  /// The read screen (spec 7.7 step 3), pushed on top of the Cards tab.
  static const String cardRead = '$cards/read';

  /// One saved card's detail and editor (spec 7.7 step 4).
  static String card(String id) => '$cards/${Uri.encodeComponent(id)}';
}

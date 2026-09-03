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

  /// The bootloader recovery entry (spec 5.5): the update screen, told which
  /// bootloader to talk to. Phase 8 reads the `recover` query parameter.
  static String recover(String transportId) =>
      '$update?recover=${Uri.encodeComponent(transportId)}';

  /// The slot editor (spec 7.2: a deep route pushed on top of its tab).
  /// [index] is the wire index, 0..7.
  static String slot(int index) => '$slots/$index';
}

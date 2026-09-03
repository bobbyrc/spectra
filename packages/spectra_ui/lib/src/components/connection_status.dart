/// The connection states the chip can show. The app maps its own session
/// state onto this; `spectra_ui` never sees a device type.
enum SpectraConnectionStatus {
  disconnected,
  connecting,
  connected,

  /// Connected, but only a firmware update is possible.
  limited,

  /// A firmware update is running.
  updating,
}

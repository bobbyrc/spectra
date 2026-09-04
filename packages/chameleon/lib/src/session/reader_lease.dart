/// Handle returned by `DeviceSession.acquireReaderMode`.
///
/// Release it when the reader operation is done; the last release restores
/// emulator mode. Releasing twice is a no-op, so a lease can be released in
/// a `finally` block and again by an owner that outlives it.
final class ReaderLease {
  ReaderLease(this._onRelease);

  final Future<void> Function() _onRelease;
  bool _released = false;

  bool get isReleased => _released;

  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _onRelease();
  }
}

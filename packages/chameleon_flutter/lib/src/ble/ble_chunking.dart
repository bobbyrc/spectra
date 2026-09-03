/// The two arithmetic helpers every BLE writer in this package needs: how
/// big a single ATT write may be, and how to cut a frame into that size.
///
/// They live together because they are one calculation used in two steps,
/// and they are pure so the transport (Task 5) and the DFU channel (Task
/// 12) share one tested implementation instead of each rolling their own.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Splits [bytes] into consecutive chunks of at most [size] bytes.
///
/// The chunks are views onto [bytes], not copies, so the caller must not
/// mutate the source while iterating. Empty input yields no chunks: there
/// is nothing to write. Lazy — nothing is computed until iterated.
Iterable<Uint8List> chunked(Uint8List bytes, int size) sync* {
  if (size <= 0) {
    throw ArgumentError.value(size, 'size', 'must be positive');
  }
  for (var offset = 0; offset < bytes.length; offset += size) {
    yield Uint8List.sublistView(
      bytes,
      offset,
      math.min(offset + size, bytes.length),
    );
  }
}

/// The largest payload a single ATT write may carry.
///
/// A negotiated ATT MTU includes [attOverhead] bytes of opcode and handle
/// (3 for a write request), so the usable payload is `mtu - attOverhead`.
/// When the platform reports nothing — Web has no MTU API, and Windows and
/// Linux may decline — or reports a value at or below the minimum, the
/// result is [floor], the size the caller knows is always safe.
int mtuWriteLength(
  int? reportedMtu, {
  required int floor,
  int attOverhead = 3,
}) {
  if (reportedMtu == null) return floor;
  return math.max(floor, reportedMtu - attOverhead);
}

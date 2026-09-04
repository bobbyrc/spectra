import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'active_device.dart';

part 'frame_log_provider.g.dart';

/// Spec 9: the ring buffer is always on, and viewing and exporting it are
/// available in every build. It belongs to the session, so it is null when
/// nothing is connected.
@riverpod
FrameLog? frameLog(Ref ref) =>
    ref.watch(activeSessionProvider)?.session.frameLog;

/// A snapshot of the log once a second. [FrameLog] is a plain ring buffer
/// with no change notification — polling is what keeps the SDK free of a
/// stream nothing else needs.
@riverpod
Stream<List<FrameLogEntry>> frameLogEntries(Ref ref) async* {
  final log = ref.watch(frameLogProvider);
  if (log == null) {
    yield const <FrameLogEntry>[];
    return;
  }
  yield log.entries;
  yield* Stream<void>.periodic(const Duration(seconds: 1))
      .map((_) => log.entries);
}

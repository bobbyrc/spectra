import 'dart:collection';

import '../codec/frame.dart';

enum FrameDirection { sent, received }

final class FrameLogEntry {
  FrameLogEntry(this.at, this.direction, this.frame);
  final DateTime at;
  final FrameDirection direction;
  final Frame frame;
}

/// Ring buffer of frames in both directions. Always on; small.
final class FrameLog {
  FrameLog({this.capacity = 512});
  final int capacity;
  final Queue<FrameLogEntry> _entries = Queue();

  void add(FrameDirection direction, Frame frame) {
    _entries.addLast(FrameLogEntry(DateTime.now(), direction, frame));
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
  }

  List<FrameLogEntry> get entries => List.unmodifiable(_entries);

  String export() {
    final b = StringBuffer();
    for (final e in _entries) {
      final arrow = e.direction == FrameDirection.sent ? '>' : '<';
      final hex = e.frame.data
          .map((x) => x.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      b.writeln(
        '${e.at.toIso8601String()} $arrow cmd=${e.frame.command} '
        'status=0x${e.frame.status.toRadixString(16)} len=${e.frame.data.length} $hex',
      );
    }
    return b.toString();
  }
}

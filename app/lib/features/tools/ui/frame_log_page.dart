import 'package:chameleon/chameleon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/session/frame_log_provider.dart';
import '../../../l10n/app_localizations.dart';
import 'tool_sub_page_scaffold.dart';

/// Spec 9: the ring buffer is always on, and viewing and exporting it are in
/// every build. Export is the clipboard — no share plugin, because a bug
/// report is pasted, not attached.
class FrameLogPage extends ConsumerWidget {
  const FrameLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // The 1 Hz poll (frame_log_provider.dart) emits a fresh List instance
    // every tick even when nothing was sent or received, so watching the
    // whole AsyncValue would rebuild this page once a second regardless.
    // Watching frameLogEntriesKey instead only rebuilds when the log
    // actually changed; the entries themselves are then read fresh,
    // cheaply, off the same tick.
    ref.watch(frameLogEntriesProvider.select(frameLogEntriesKey));
    final List<FrameLogEntry> entries =
        ref.read(frameLogEntriesProvider).value ?? const <FrameLogEntry>[];

    return ToolSubPageScaffold(
      title: l10n.frameLogTitle,
      body: ListView(
        padding: const EdgeInsets.all(SpectraSpacing.lg),
        children: <Widget>[
          SpectraSectionHeader(
            title: l10n.frameLogTitle,
            actionLabel: l10n.frameLogCopy,
            onAction: () async {
              final String text = ref.read(frameLogProvider)?.export() ?? '';
              await Clipboard.setData(ClipboardData(text: text));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l10n.frameLogCopied)));
            },
          ),
          if (entries.isEmpty) SpectraCard(child: Text(l10n.frameLogEmpty)),
          for (final FrameLogEntry entry in entries.reversed)
            SpectraListTile(
              // The wire dump, not user-facing copy: it must match what
              // FrameLog.export() writes so what is on screen and what is
              // pasted into a bug report are the same shape.
              title: _line(entry), // l10n-exempt
              subtitle: entry.at.toIso8601String(),
            ),
        ],
      ),
    );
  }

  static String _line(FrameLogEntry entry) {
    final String arrow = entry.direction == FrameDirection.sent ? '>' : '<';
    return '$arrow cmd=${entry.frame.command} '
        'status=0x${entry.frame.status.toRadixString(16)} '
        'len=${entry.frame.data.length}';
  }
}

/// The key [FrameLogPage] selects on. Length alone is not enough: the ring
/// buffer (`FrameLog`, capacity 512) pins its length once full, and every
/// entry after that replaces the oldest one rather than growing the list —
/// so a full log would silently stop refreshing the page if length were the
/// only thing watched. Hashing the length together with the newest entry's
/// identity catches both a plain append (length changes) and a full-buffer
/// rotation (length is unchanged, but the newest entry is a new object).
///
/// `@visibleForTesting` so a plain unit test can check its equality
/// directly, without needing to observe a widget rebuild to prove it.
@visibleForTesting
int frameLogEntriesKey(AsyncValue<List<FrameLogEntry>> value) {
  final List<FrameLogEntry>? entries = value.value;
  if (entries == null || entries.isEmpty) return entries?.length ?? 0;
  return Object.hash(entries.length, entries.last);
}

import 'package:chameleon/chameleon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/session/frame_log_provider.dart';
import '../../../l10n/app_localizations.dart';

/// Spec 9: the ring buffer is always on, and viewing and exporting it are in
/// every build. Export is the clipboard — no share plugin, because a bug
/// report is pasted, not attached.
///
/// A leading back button (Task 10 review: the shell's own AppBar sits above
/// the branch navigator and keeps showing "Tools", so a sub-route needs its
/// own way back) closes this page and returns to the Tools list.
class FrameLogPage extends ConsumerWidget {
  const FrameLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // The 1 Hz poll (frame_log_provider.dart) emits a fresh List instance
    // every tick even when nothing was sent or received, so watching the
    // whole AsyncValue would rebuild this page once a second regardless.
    // Watching just the length instead only rebuilds when the log actually
    // grew (or was cleared by a disconnect); the entries themselves are then
    // read fresh, cheaply, off the same tick.
    ref.watch(
      frameLogEntriesProvider.select(
        (AsyncValue<List<FrameLogEntry>> v) => v.value?.length ?? 0,
      ),
    );
    final List<FrameLogEntry> entries =
        ref.read(frameLogEntriesProvider).value ?? const <FrameLogEntry>[];

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(l10n.frameLogTitle),
      ),
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

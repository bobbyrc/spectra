import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/discovery/discovery_provider.dart';
import '../../../core/platform/host_platform_provider.dart';
import '../../../l10n/app_localizations.dart';

/// Desktop fallback for a port enumeration that finds nothing (spec 5.2).
/// Renders nothing on mobile, where there are no port paths to type.
class ManualPortField extends ConsumerStatefulWidget {
  const ManualPortField({super.key});

  @override
  ConsumerState<ManualPortField> createState() => _ManualPortFieldState();
}

class _ManualPortFieldState extends ConsumerState<ManualPortField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    ref.read(manualPortsProvider.notifier).add(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Mobile has no port paths to type; `HostPlatform.unknown` gets the
    // desktop affordance rather than nothing at all.
    if (isMobile(ref.watch(hostPlatformProvider))) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SpectraDisclosure(
      summary: Text(l10n.connectManualPortTitle),
      detail: Row(
        children: <Widget>[
          Expanded(
            child: SpectraTextField(
              label: l10n.connectManualPortLabel,
              hint: l10n.connectManualPortHint,
              controller: _controller,
              onSubmitted: (_) => _add(),
            ),
          ),
          const SizedBox(width: SpectraSpacing.md),
          SpectraButton(label: l10n.connectManualPortAdd, onPressed: _add),
        ],
      ),
    );
  }
}

import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/discovery/discovery_provider.dart';
import '../../../l10n/app_localizations.dart';

part 'manual_port_field.g.dart';

/// Injection seam for `currentHostPlatform()` (`chameleon_flutter` reads the
/// real OS directly and takes no parameter, so there is nothing to override
/// there). [ManualPortField] is the only widget that needs to know the host
/// platform, so the seam lives beside it rather than in
/// `core/discovery/scanners.dart`'s `scannerPlatformProvider` family, which
/// feeds `ChameleonTransports.defaultScanners` a different parameter
/// (`HostPlatform?`, `null` meaning "ask the OS") for an unrelated purpose.
/// A test overrides this provider directly to exercise both branches of
/// [ManualPortField.build] without depending on the host the suite runs on.
@Riverpod(keepAlive: true)
HostPlatform hostPlatform(Ref ref) => currentHostPlatform();

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
    const Set<HostPlatform> desktop = <HostPlatform>{
      HostPlatform.macos,
      HostPlatform.windows,
      HostPlatform.linux,
    };
    if (!desktop.contains(ref.watch(hostPlatformProvider))) {
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

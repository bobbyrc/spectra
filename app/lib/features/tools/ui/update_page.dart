import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
import '../../../core/flags/feature_flags.dart';
import '../../../core/routing/sub_page_scaffold.dart';
import '../../../core/session/active_device.dart';
import '../../../l10n/app_localizations.dart';
import '../state/firmware_package_source.dart';
import '../state/update_controller.dart';

/// Firmware update (spec 7.7 step 6, 4.5, 5.6).
///
/// Two entry points: the Tools tab with a device connected, and the connect
/// screen's "Recover" action, which passes the bootloader's transport id in
/// [recoverTransportId] (Task 12 wires that half).
class UpdatePage extends ConsumerStatefulWidget {
  const UpdatePage({this.recoverTransportId, super.key});

  /// The bootloader a "Recover" action named, from `?recover=`.
  final String? recoverTransportId;

  @override
  ConsumerState<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends ConsumerState<UpdatePage> {
  final TextEditingController _path = TextEditingController();

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final UpdateState state = ref.watch(updateControllerProvider);
    final UpdateController controller = ref.read(
      updateControllerProvider.notifier,
    );
    final FeatureFlags flags = ref.watch(featureFlagsProvider);
    final LoadedFirmwarePackage? package = state.package;
    final String? deviceName = ref.watch(activeSessionProvider)?.device.name;
    final String? target = widget.recoverTransportId;
    final bool busy = state.running || state.loading;

    return SubPageScaffold(
      title: l10n.updateTitle,
      body: ListView(
        padding: const EdgeInsets.all(SpectraSpacing.lg),
        children: <Widget>[
          if (target != null) ...<Widget>[
            SpectraCard(child: Text(l10n.updateRecoverTarget(target))),
            const SizedBox(height: SpectraSpacing.md),
            SpectraCard(child: Text(l10n.updateRecoverInstructions)),
            const SizedBox(height: SpectraSpacing.md),
          ],
          SpectraSectionHeader(title: l10n.updatePackageSection),
          SpectraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.updateReleasesHint(firmwareReleasesUrl)),
                const SizedBox(height: SpectraSpacing.md),
                SpectraTextField(
                  label: l10n.updatePackagePathLabel,
                  hint: l10n.updatePackagePathHint,
                  controller: _path,
                  enabled: !busy,
                ),
                const SizedBox(height: SpectraSpacing.md),
                SpectraButton(
                  label: l10n.updateLoadPackage,
                  variant: SpectraButtonVariant.secondary,
                  busy: state.loading,
                  onPressed: busy
                      ? null
                      : () => controller.loadPackage(_path.text),
                ),
              ],
            ),
          ),
          if (package != null) ...<Widget>[
            const SizedBox(height: SpectraSpacing.md),
            SpectraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.updatePackageSummary(
                      package.fileName,
                      package.imageCount,
                      package.totalBytes,
                    ),
                  ),
                  const SizedBox(height: SpectraSpacing.sm),
                  Text(switch (package.targetModel) {
                    DeviceModel.ultra => l10n.updatePackageForUltra,
                    DeviceModel.lite => l10n.updatePackageForLite,
                    null => l10n.updatePackageForUnknown,
                  }),
                ],
              ),
            ),
          ],
          if (state.error != null) ...<Widget>[
            const SizedBox(height: SpectraSpacing.md),
            ProblemView(
              error: state.error!,
              variant: SpectraButtonVariant.secondary,
              onAction: controller.reset,
            ),
          ],
          const SizedBox(height: SpectraSpacing.md),
          if (deviceName != null)
            SpectraCard(child: Text(l10n.updateTargetConnected(deviceName)))
          else
            SpectraCard(child: Text(l10n.updateNoTarget)),
          const SizedBox(height: SpectraSpacing.md),
          SpectraButton(
            label: l10n.updateStart,
            onPressed: package == null || busy || deviceName == null
                ? null
                : () => controller.start(),
          ),
          if (!flags.dfuOverBleEnabled) ...<Widget>[
            const SizedBox(height: SpectraSpacing.md),
            SpectraCard(child: Text(l10n.updateBleNotice)),
          ],
        ],
      ),
    );
  }
}

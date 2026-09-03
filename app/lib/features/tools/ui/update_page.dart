import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/discovery/discovery_provider.dart';
import '../../../core/errors/problem_view.dart';
import '../../../core/flags/feature_flags.dart';
import '../../../core/routing/sub_page_scaffold.dart';
import '../../../core/session/active_device.dart';
import '../../../l10n/app_localizations.dart';
import '../state/firmware_package_source.dart';
import '../state/recover_target.dart';
import '../state/update_controller.dart';
import '../state/update_steps.dart';

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
    final DiscoveredDevice? recover = recoverTarget(
      ref.watch(discoveryProvider).value?.devices ?? const <DiscoveredDevice>[],
      widget.recoverTransportId,
    );
    final String? targetName = recover?.name ?? deviceName;
    final bool busy = state.running || state.loading;

    return SubPageScaffold(
      title: l10n.updateTitle,
      body: ListView(
        padding: const EdgeInsets.all(SpectraSpacing.lg),
        children: <Widget>[
          if (widget.recoverTransportId != null) ...<Widget>[
            SpectraCard(
              child: Text(l10n.updateRecoverTarget(widget.recoverTransportId!)),
            ),
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
          if (targetName != null)
            SpectraCard(child: Text(l10n.updateTargetConnected(targetName)))
          else
            SpectraCard(child: Text(l10n.updateNoTarget)),
          const SizedBox(height: SpectraSpacing.md),
          if (state.running) ...<Widget>[
            SpectraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SpectraStepIndicator(
                    steps: updateStepLabels(l10n),
                    currentIndex: updateStepIndex(state.phase),
                  ),
                  const SizedBox(height: SpectraSpacing.md),
                  SpectraProgressIndicator(
                    label: l10n.updateProgressLabel,
                    // Null until the transfer reports its first byte count:
                    // the reboot and the two scans have no fraction to show,
                    // and an indeterminate bar says exactly that.
                    value: state.fraction,
                    detail: state.progress == null
                        ? null
                        : l10n.updateProgressDetail(
                            state.progress!.bytesSent,
                            state.progress!.bytesTotal,
                          ),
                    onCancel: controller.cancel,
                  ),
                  const SizedBox(height: SpectraSpacing.md),
                  Text(l10n.updateDoNotDisconnect),
                ],
              ),
            ),
            const SizedBox(height: SpectraSpacing.md),
          ],
          if (state.completed) ...<Widget>[
            SpectraCard(child: Text(l10n.updateSucceeded)),
            const SizedBox(height: SpectraSpacing.md),
          ],
          if (!state.running)
            SpectraButton(
              label: l10n.updateStart,
              onPressed: package == null || busy || targetName == null
                  ? null
                  : () => controller.start(bootloader: recover),
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

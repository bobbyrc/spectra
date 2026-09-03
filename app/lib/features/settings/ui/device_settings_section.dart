import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
import '../../../core/session/session_streams.dart';
import '../../../l10n/app_localizations.dart';
import '../state/device_settings_controller.dart';
import '../state/settings_labels.dart';
import 'option_sheet.dart';

/// Spec 7.7 step 7: LEDs, buttons, sleep and pairing.
///
/// The values come from `settingsProvider` — the session's write-through
/// cache (spec 4.3) — not from this widget's own state, so a change made
/// with the device's buttons shows up here too.
class DeviceSettingsSection extends ConsumerWidget {
  const DeviceSettingsSection({super.key});

  /// The firmware accepts 5..60 seconds (1039/1040); these are the values
  /// worth offering.
  static const List<int> sleepOptions = <int>[5, 8, 15, 30, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DeviceSettings? settings = ref.watch(settingsProvider).value;
    final DeviceSettingsEditState edit = ref.watch(
      deviceSettingsControllerProvider,
    );
    final DeviceSettingsController controller = ref.read(
      deviceSettingsControllerProvider.notifier,
    );

    if (settings == null) {
      return SpectraCard(child: Text(l10n.settingsNoDevice));
    }
    final bool busy = edit.busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SpectraSectionHeader(title: l10n.settingsDeviceTitle),
        if (edit.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: SpectraSpacing.md),
            child: ProblemView(
              error: edit.error!,
              variant: SpectraButtonVariant.secondary,
              onAction: controller.clearError,
            ),
          ),
        SpectraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SpectraListTile(
                title: l10n.settingsAnimation,
                subtitle: animationLabel(settings.animation, l10n),
                onTap: busy
                    ? null
                    : () => unawaited(
                        _pickAnimation(context, controller, settings, l10n),
                      ),
              ),
              for (final (
                    String label,
                    ButtonFunction current,
                    DeviceButton button,
                    bool long,
                  )
                  row
                  in <(String, ButtonFunction, DeviceButton, bool)>[
                    (
                      l10n.settingsButtonA,
                      settings.buttonA,
                      DeviceButton.a,
                      false,
                    ),
                    (
                      l10n.settingsButtonB,
                      settings.buttonB,
                      DeviceButton.b,
                      false,
                    ),
                    (
                      l10n.settingsLongButtonA,
                      settings.longButtonA,
                      DeviceButton.a,
                      true,
                    ),
                    (
                      l10n.settingsLongButtonB,
                      settings.longButtonB,
                      DeviceButton.b,
                      true,
                    ),
                  ])
                SpectraListTile(
                  title: row.$1,
                  subtitle: buttonFunctionLabel(row.$2, l10n),
                  onTap: busy
                      ? null
                      : () => unawaited(
                          _pickButton(context, controller, row, l10n),
                        ),
                ),
              if (settings.sleepTimeoutSeconds case final int seconds)
                SpectraListTile(
                  title: l10n.settingsSleep,
                  subtitle: l10n.settingsSleepSeconds(seconds),
                  onTap: busy
                      ? null
                      : () => unawaited(
                          _pickSleep(context, controller, seconds, l10n),
                        ),
                ),
            ],
          ),
        ),
        const SizedBox(height: SpectraSpacing.md),
        SpectraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SpectraListTile(
                title: l10n.settingsBlePairing,
                subtitle: l10n.settingsBlePairingWarning,
                trailing: Switch(
                  value: settings.blePairingEnabled,
                  onChanged: busy
                      ? null
                      : (bool v) =>
                            unawaited(controller.setBlePairingEnabled(v)),
                ),
              ),
              const SizedBox(height: SpectraSpacing.md),
              _PairingKeyField(
                initialValue: settings.blePairingKey,
                enabled: !busy,
              ),
              const SizedBox(height: SpectraSpacing.md),
              SpectraButton(
                label: l10n.settingsDeleteBonds,
                variant: SpectraButtonVariant.secondary,
                onPressed: busy
                    ? null
                    : () => unawaited(_deleteBonds(context, controller, l10n)),
              ),
            ],
          ),
        ),
        const SizedBox(height: SpectraSpacing.md),
        if (edit.dirty) ...<Widget>[
          SpectraCard(child: Text(l10n.settingsUnsaved)),
          const SizedBox(height: SpectraSpacing.sm),
        ],
        SpectraButton(
          label: l10n.settingsSave,
          busy: busy,
          onPressed: busy
              ? null
              : () => unawaited(_save(context, controller, l10n)),
        ),
        const SizedBox(height: SpectraSpacing.sm),
        SpectraButton(
          label: l10n.settingsResetDevice,
          variant: SpectraButtonVariant.secondary,
          onPressed: busy
              ? null
              : () => unawaited(_reset(context, controller, l10n)),
        ),
      ],
    );
  }
}

Future<void> _pickAnimation(
  BuildContext context,
  DeviceSettingsController controller,
  DeviceSettings settings,
  AppLocalizations l10n,
) async {
  final AnimationMode? mode = await showOptionSheet<AnimationMode>(
    context: context,
    title: l10n.settingsAnimation,
    options: AnimationMode.values,
    labelOf: (AnimationMode m) => animationLabel(m, l10n),
    selected: settings.animation,
  );
  if (mode == null) return;
  await controller.setAnimation(mode);
}

Future<void> _pickButton(
  BuildContext context,
  DeviceSettingsController controller,
  (String, ButtonFunction, DeviceButton, bool) row,
  AppLocalizations l10n,
) async {
  final ButtonFunction? fn = await showOptionSheet<ButtonFunction>(
    context: context,
    title: row.$1,
    options: ButtonFunction.values,
    labelOf: (ButtonFunction f) => buttonFunctionLabel(f, l10n),
    selected: row.$2,
  );
  if (fn == null) return;
  await controller.setButton(row.$3, fn, long: row.$4);
}

Future<void> _pickSleep(
  BuildContext context,
  DeviceSettingsController controller,
  int current,
  AppLocalizations l10n,
) async {
  final int? seconds = await showOptionSheet<int>(
    context: context,
    title: l10n.settingsSleep,
    options: DeviceSettingsSection.sleepOptions,
    labelOf: l10n.settingsSleepSeconds,
    selected: current,
  );
  if (seconds == null) return;
  await controller.setSleepTimeout(seconds);
}

Future<void> _save(
  BuildContext context,
  DeviceSettingsController controller,
  AppLocalizations l10n,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  await controller.saveToDevice();
  if (!context.mounted) return;
  messenger.showSnackBar(SnackBar(content: Text(l10n.settingsSaved)));
}

Future<void> _deleteBonds(
  BuildContext context,
  DeviceSettingsController controller,
  AppLocalizations l10n,
) async {
  final bool? confirmed = await SpectraDialog.show<bool>(
    context: context,
    title: l10n.settingsDeleteBondsTitle,
    content: Text(l10n.settingsDeleteBondsBody),
    actions: (BuildContext context) => <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: Text(l10n.commonCancel),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: Text(l10n.settingsDeleteBonds),
      ),
    ],
  );
  if (confirmed != true) return;
  if (!context.mounted) return;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  await controller.deleteBonds();
  if (!context.mounted) return;
  messenger.showSnackBar(SnackBar(content: Text(l10n.settingsBondsDeleted)));
}

Future<void> _reset(
  BuildContext context,
  DeviceSettingsController controller,
  AppLocalizations l10n,
) async {
  final bool? confirmed = await SpectraDialog.show<bool>(
    context: context,
    title: l10n.settingsResetTitle,
    content: Text(l10n.settingsResetBody),
    actions: (BuildContext context) => <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: Text(l10n.commonCancel),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: Text(l10n.settingsResetDevice),
      ),
    ],
  );
  if (confirmed != true) return;
  await controller.resetToFactory();
}

class _PairingKeyField extends ConsumerStatefulWidget {
  const _PairingKeyField({required this.initialValue, required this.enabled});

  final String initialValue;
  final bool enabled;

  @override
  ConsumerState<_PairingKeyField> createState() => _PairingKeyFieldState();
}

class _PairingKeyFieldState extends ConsumerState<_PairingKeyField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initialValue,
  );
  bool _invalid = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _onChanged(String value) async {
    final bool ok = isValidPairingKey(value);
    setState(() => _invalid = !ok);
    if (!ok) return;
    await ref
        .read(deviceSettingsControllerProvider.notifier)
        .setBlePairingKey(value);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SpectraTextField(
      label: l10n.settingsBlePairingKey,
      controller: _text,
      enabled: widget.enabled,
      errorText: _invalid ? l10n.settingsBlePairingKeyInvalid : null,
      onChanged: (String v) => unawaited(_onChanged(v)),
    );
  }
}

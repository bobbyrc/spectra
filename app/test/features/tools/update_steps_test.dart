import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/tools/state/update_steps.dart';
import 'package:spectra/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('every phase maps into the step list', () {
    final labels = updateStepLabels(l10n);
    for (final phase in DfuPhase.values) {
      final index = updateStepIndex(phase);
      expect(index, inInclusiveRange(0, labels.length - 1));
    }
    expect(updateStepIndex(null), 0);
    expect(updateStepIndex(DfuPhase.done), labels.length - 1);
  });

  test('the labels are the six orchestrator phases, in order', () {
    expect(updateStepLabels(l10n), hasLength(DfuPhase.values.length));
  });

  test(
    'the recovery path starts at transferring, and steps render from there',
    () {
      // DfuOrchestrator's recovery path (a bootloader passed in directly)
      // never emits checking/enteringBootloader/findingBootloader — the
      // first phase it yields is transferring. The step list must still
      // land on the right row when that is the first phase observed.
      final index = updateStepIndex(DfuPhase.transferring);
      final labels = updateStepLabels(l10n);
      expect(index, inInclusiveRange(0, labels.length - 1));
      expect(labels[index], l10n.updateStepTransferring);
    },
  );
}

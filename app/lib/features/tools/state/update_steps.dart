import 'package:chameleon/chameleon.dart';

import '../../../l10n/app_localizations.dart';

/// The six `DfuPhase`s as step labels, in the order the orchestrator reports
/// them (`DfuOrchestrator`'s `DfuPhase` enum: checking, enteringBootloader,
/// findingBootloader, transferring, findingDevice, done).
List<String> updateStepLabels(AppLocalizations l10n) => <String>[
  l10n.updateStepChecking,
  l10n.updateStepBootloader,
  l10n.updateStepFindingBootloader,
  l10n.updateStepTransferring,
  l10n.updateStepFindingDevice,
  l10n.updateStepDone,
];

/// Where [phase] sits in [updateStepLabels]. Null — nothing reported yet —
/// is the first step, because the run is about to begin there.
///
/// Every phase maps by its own identity, not by counting events observed:
/// the orchestrator's recovery path (a bootloader chosen directly, spec 5.6)
/// never emits `checking`, `enteringBootloader` or `findingBootloader` — it
/// starts straight at `transferring` — so the step list must still land on
/// the right row when that is the first phase seen.
int updateStepIndex(DfuPhase? phase) => switch (phase) {
  null => 0,
  DfuPhase.checking => 0,
  DfuPhase.enteringBootloader => 1,
  DfuPhase.findingBootloader => 2,
  DfuPhase.transferring => 3,
  DfuPhase.findingDevice => 4,
  DfuPhase.done => 5,
};

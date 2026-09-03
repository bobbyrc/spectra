import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
import '../../../l10n/app_localizations.dart';
import '../state/dictionaries_provider.dart';
import '../state/dictionary_codec.dart';

/// The words for an import failure [parseDictionaries] itself raised. Spec 9
/// keeps errors typed to the UI, so this switches on the problem rather than
/// showing the exception's text. Anything that is *not* a
/// [DictionaryImportException] — a repository failure partway through —
/// goes through [ProblemView] and the shared catalog instead, so a storage
/// failure is never worded as a parse failure (Phase 6 ruling 21).
String importProblemMessage(
  DictionaryImportProblem problem,
  AppLocalizations l10n,
) => switch (problem) {
  DictionaryImportProblem.notReadable => l10n.dictImportNotReadable,
  DictionaryImportProblem.noKeys => l10n.dictImportNoKeys,
  DictionaryImportProblem.badKey => l10n.dictImportBadKey,
};

/// Spec 7.3: import from the reference app's export, a plain `.dic` list, or
/// Spectra's own. Pasting works on all five platforms and needs no new
/// dependency; see this phase's plan for why there is no file dialog.
///
/// Resolves to the number of lists written, or null when the sheet was
/// dismissed without a fully successful import. A *partial* import (some
/// lists written, then a failure) never resolves this future — the sheet
/// stays open and shows both the count already written and the problem
/// that stopped the rest, the `showCardImportSheet` contract.
Future<int?> showDictionaryImportSheet(BuildContext context) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<int>(
    context: context,
    title: l10n.dictImportTitle,
    builder: (BuildContext context) => const _ImportForm(),
  );
}

class _ImportForm extends ConsumerStatefulWidget {
  const _ImportForm();

  @override
  ConsumerState<_ImportForm> createState() => _ImportFormState();
}

class _ImportFormState extends ConsumerState<_ImportForm> {
  final TextEditingController _text = TextEditingController();

  /// Set only when the last attempt did not fully succeed — a
  /// [DictionaryImportException] (always `written == 0`) or a repository
  /// failure partway through (possibly `written > 0`). Null again on a
  /// fresh attempt, and on the button that dismisses [ProblemView].
  ImportOutcome? _failure;

  /// True from the moment [_import] is called until its await returns.
  ///
  /// `DictionaryLibrary.importText` drops a call made while one is already
  /// in flight — it returns `ImportOutcome(written: 0)` with no error, which
  /// is indistinguishable from "nothing to write" — so a second tap that
  /// lands before the first import's write has set `state` to
  /// `AsyncLoading` (and so before `ref.watch(dictionaryLibraryProvider)
  /// .isLoading` can disable the button) must never reach the notifier at
  /// all. This flag, checked locally rather than through the notifier,
  /// closes that gap (pre-flight ruling M8): a double-tap can never pop the
  /// sheet claiming a second import happened.
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // The Import button's disabled-while-empty state has to track the
    // field as the user types, not just the widget's own rebuilds.
    _text.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    _text.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (_submitting) return;
    final NavigatorState navigator = Navigator.of(context);
    setState(() {
      _submitting = true;
      _failure = null;
    });
    final ImportOutcome outcome = await ref
        .read(dictionaryLibraryProvider.notifier)
        .importText(_text.text);
    if (!mounted) return;
    if (outcome.ok && outcome.written > 0) {
      navigator.pop(outcome.written);
      return;
    }
    setState(() {
      _submitting = false;
      _failure = outcome;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<void> write = ref.watch(dictionaryLibraryProvider);
    final bool busy = write.isLoading || _submitting;
    final ImportOutcome? failure = _failure;
    final Object? error = failure?.error;
    final DictionaryImportException? typedFailure =
        error is DictionaryImportException ? error : null;
    // An error this sheet's own [_import] raised is always also in
    // [write] (`importText` sets the notifier's state before returning),
    // so [failure] takes priority there. But a failure can also land in
    // [write] with no [failure] set at all — a write another part of the
    // app started through the same notifier, or (pre-flight ruling M9) a
    // repository failure surfaced outside an import attempt — and that
    // has nowhere else to go, so it is shown through the same catalog
    // rather than silently disappearing behind a form with no error on
    // screen.
    final bool showExternalError = failure == null && write.hasError;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.dictImportHint),
        const SizedBox(height: SpectraSpacing.md),
        SpectraTextField(
          label: l10n.dictImportLabel,
          controller: _text,
          // A `.dic` paste is one key per line; the field must accept
          // newlines to hold it (see SpectraTextField's [maxLines] doc).
          maxLines: 8,
          minLines: 3,
          errorText: typedFailure == null
              ? null
              : importProblemMessage(typedFailure.problem, l10n),
        ),
        if (failure != null && typedFailure == null) ...<Widget>[
          const SizedBox(height: SpectraSpacing.md),
          if (failure.written > 0) Text(l10n.dictImported(failure.written)),
          const SizedBox(height: SpectraSpacing.md),
          ProblemView(
            error: error!,
            variant: SpectraButtonVariant.secondary,
            onAction: () => setState(() => _failure = null),
          ),
        ],
        if (showExternalError) ...<Widget>[
          const SizedBox(height: SpectraSpacing.md),
          ProblemView(
            error: write.error!,
            variant: SpectraButtonVariant.secondary,
            onAction: ref.read(dictionaryLibraryProvider.notifier).reset,
          ),
        ],
        const SizedBox(height: SpectraSpacing.lg),
        SpectraButton(
          label: l10n.dictImportConfirm,
          busy: busy,
          onPressed: busy || _text.text.trim().isEmpty
              ? null
              : () => unawaited(_import()),
        ),
      ],
    );
  }
}

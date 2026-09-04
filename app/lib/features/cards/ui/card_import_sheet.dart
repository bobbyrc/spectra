import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
import '../../../l10n/app_localizations.dart';
import '../state/card_import.dart';
import '../state/saved_cards_provider.dart';

/// The words for an import failure that [parseCardsJson] itself raised.
/// Spec 9 keeps errors typed to the UI, so this switches on the problem
/// rather than showing the exception's text.
///
/// A failure that is *not* a [CardImportException] — a repository error
/// partway through the write, say — never reaches here: [_ImportFormState]
/// routes that case through [ProblemView] and the shared [ErrorCatalog]
/// instead, so a storage failure is never worded as "not a card export"
/// (Phase 6 ruling 21). A [CardImportException] always carries
/// `ImportOutcome.written == 0` — [parseCardsJson] reads the whole paste
/// before anything is written — so this is only ever shown alongside a
/// nothing-written result.
String importProblemMessage(CardImportProblem problem, AppLocalizations l10n) =>
    switch (problem) {
      CardImportProblem.notJson => l10n.cardsImportNotJson,
      CardImportProblem.noCards => l10n.cardsImportNoCards,
      CardImportProblem.unsupportedTagType => l10n.cardsImportUnsupported,
      CardImportProblem.badBytes => l10n.cardsImportBadBytes,
    };

/// Spec 7.3: import from the reference app's export, or Spectra's own.
///
/// v1 has no native file-open dialog (a decision recorded in the Task 10
/// brief, and in `docs/research/DECISIONS.md` per Task 14): adding one is a
/// new dependency plus per-platform setup on five targets, and a spec
/// section 2 amendment, the same gate `crypto` went through. Pasting the
/// exported text works on every platform today and needs nothing new.
///
/// Resolves to the number of cards written, or null when the sheet was
/// dismissed without a fully successful import. A *partial* import (some
/// cards written, then a failure) never resolves this future — the sheet
/// stays open and shows both the count already written and the problem
/// that stopped the rest, so the user sees the honest outcome before
/// deciding to dismiss.
Future<int?> showCardImportSheet(BuildContext context) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<int>(
    context: context,
    title: l10n.cardsImportTitle,
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
  /// [CardImportException] (always `written == 0`) or a repository failure
  /// partway through (possibly `written > 0`). Null again on a fresh
  /// attempt, and on the button that dismisses [ProblemView].
  ImportOutcome? _failure;

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
    final NavigatorState navigator = Navigator.of(context);
    setState(() => _failure = null);
    final ImportOutcome outcome = await ref
        .read(cardLibraryProvider.notifier)
        .importJson(_text.text);
    if (!mounted) return;
    if (outcome.ok) {
      navigator.pop(outcome.written);
      return;
    }
    setState(() => _failure = outcome);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool busy = ref.watch(cardLibraryProvider).isLoading;
    final ImportOutcome? failure = _failure;
    final Object? error = failure?.error;
    final CardImportException? typedFailure = error is CardImportException
        ? error
        : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.cardsImportHint),
        const SizedBox(height: SpectraSpacing.md),
        SpectraTextField(
          label: l10n.cardsImportLabel,
          controller: _text,
          errorText: typedFailure == null
              ? null
              : importProblemMessage(typedFailure.problem, l10n),
        ),
        if (failure != null && typedFailure == null) ...<Widget>[
          const SizedBox(height: SpectraSpacing.md),
          if (failure.written > 0) Text(l10n.cardsImported(failure.written)),
          const SizedBox(height: SpectraSpacing.md),
          ProblemView(
            error: error!,
            variant: SpectraButtonVariant.secondary,
            onAction: () => setState(() => _failure = null),
          ),
        ],
        const SizedBox(height: SpectraSpacing.lg),
        SpectraButton(
          label: l10n.cardsImportConfirm,
          busy: busy,
          onPressed: busy || _text.text.trim().isEmpty
              ? null
              : () => unawaited(_import()),
        ),
      ],
    );
  }
}

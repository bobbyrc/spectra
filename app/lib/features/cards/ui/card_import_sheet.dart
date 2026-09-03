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
/// (Phase 6 ruling 21).
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
/// dismissed without a successful import.
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
  CardImportException? _typedFailure;
  Object? _otherFailure;

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
    setState(() {
      _typedFailure = null;
      _otherFailure = null;
    });
    final int count = await ref
        .read(cardLibraryProvider.notifier)
        .importJson(_text.text);
    if (!mounted) return;
    if (count == 0) {
      final Object? failure = ref.read(cardLibraryProvider).error;
      setState(() {
        if (failure is CardImportException) {
          _typedFailure = failure;
        } else {
          _otherFailure =
              failure ??
              const CardImportException(
                CardImportProblem.notJson,
                'no cards were written',
              );
        }
      });
      return;
    }
    navigator.pop(count);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool busy = ref.watch(cardLibraryProvider).isLoading;
    final CardImportException? typedFailure = _typedFailure;
    final Object? otherFailure = _otherFailure;
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
        if (otherFailure != null) ...<Widget>[
          const SizedBox(height: SpectraSpacing.md),
          ProblemView(
            error: otherFailure,
            variant: SpectraButtonVariant.secondary,
            onAction: () => setState(() => _otherFailure = null),
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

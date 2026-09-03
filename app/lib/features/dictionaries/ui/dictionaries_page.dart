import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
import '../../../core/routing/sub_page_scaffold.dart';
import '../../../data/data.dart';
import '../../../l10n/app_localizations.dart';
import '../state/built_in_keys.dart';
import '../state/dictionaries_provider.dart';
import '../state/selected_dictionary.dart';

/// Spec 7.7 step 7: the key lists. Layout only — every mutation goes
/// through [DictionaryLibrary], and the selection is [SelectedDictionaryId].
///
/// A tile's [SpectraListTile.onTap] is left null: the `:id` detail route
/// (`DictionaryDetailPage`) is Task 7's, and landing a tap that opens
/// go_router's error page is exactly what pre-flight ruling M11 forbids.
class DictionariesPage extends ConsumerWidget {
  const DictionariesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<KeyDictionary> all =
        ref.watch(dictionariesProvider).value ?? const <KeyDictionary>[];
    final String? selectedId = ref.watch(selectedDictionaryProvider).value?.id;
    final AsyncValue<void> write = ref.watch(dictionaryLibraryProvider);
    final bool busy = write.isLoading;

    return SubPageScaffold(
      title: l10n.dictTitle,
      body: ListView(
        padding: const EdgeInsets.all(SpectraSpacing.lg),
        children: <Widget>[
          SpectraSectionHeader(
            title: l10n.dictTitle,
            actionLabel: l10n.dictNew,
            onAction: busy ? null : () => unawaited(_create(context, ref)),
          ),
          if (write.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: SpectraSpacing.md),
              child: ProblemView(
                error: write.error!,
                variant: SpectraButtonVariant.secondary,
                onAction: ref.read(dictionaryLibraryProvider.notifier).reset,
              ),
            ),
          for (final KeyDictionary dictionary in all)
            Padding(
              padding: const EdgeInsets.only(bottom: SpectraSpacing.sm),
              child: SpectraListTile(
                title: dictionaryDisplayName(dictionary, l10n),
                subtitle: l10n.dictKeyCount(dictionary.keys.length),
                leading: Icon(
                  isBuiltIn(dictionary) ? Icons.lock_outline : Icons.key,
                ),
                // M1: the "in use" marker is its own widget, not folded
                // into the subtitle string.
                trailing: dictionary.id == selectedId
                    ? Text(l10n.dictInUse)
                    : TextButton(
                        onPressed: busy
                            ? null
                            : () => unawaited(
                                ref
                                    .read(selectedDictionaryIdProvider.notifier)
                                    .select(dictionary.id),
                              ),
                        child: Text(l10n.dictUse),
                      ),
              ),
            ),
          if (all.length == 1) SpectraCard(child: Text(l10n.dictEmpty)),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? name = await showDictionaryNameSheet(
      context,
      title: l10n.dictNameTitle,
    );
    if (name == null) return;
    await ref.read(dictionaryLibraryProvider.notifier).create(name);
  }
}

/// The name a list is shown under. The built-in list has no stored name —
/// it is synthesized, and its name is copy (`built_in_keys.dart`).
String dictionaryDisplayName(KeyDictionary d, AppLocalizations l10n) =>
    isBuiltIn(d)
    ? l10n.dictBuiltInName
    : (d.name.trim().isEmpty ? l10n.dictUnnamed : d.name);

/// The one name prompt: create, rename and duplicate all use it. Resolves
/// to the trimmed name, or null when the sheet was dismissed.
Future<String?> showDictionaryNameSheet(
  BuildContext context, {
  required String title,
  String initialValue = '',
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<String>(
    context: context,
    title: title,
    builder: (BuildContext context) =>
        _NameForm(l10n: l10n, initialValue: initialValue),
  );
}

class _NameForm extends StatefulWidget {
  const _NameForm({required this.l10n, required this.initialValue});

  final AppLocalizations l10n;
  final String initialValue;

  @override
  State<_NameForm> createState() => _NameFormState();
}

class _NameFormState extends State<_NameForm> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initialValue,
  )..addListener(_onChanged);

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _text.removeListener(_onChanged);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool valid = _text.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SpectraTextField(
          label: widget.l10n.dictNameLabel,
          controller: _text,
          autofocus: true,
        ),
        const SizedBox(height: SpectraSpacing.lg),
        SpectraButton(
          label: widget.l10n.dictNameConfirm,
          onPressed: valid
              ? () => Navigator.of(context).pop(_text.text.trim())
              : null,
        ),
      ],
    );
  }
}

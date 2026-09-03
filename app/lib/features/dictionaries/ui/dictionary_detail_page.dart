import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
import '../../../core/format/hex.dart';
import '../../../core/routing/routes.dart';
import '../../../core/routing/sub_page_scaffold.dart';
import '../../../data/data.dart';
import '../../../l10n/app_localizations.dart';
import '../state/built_in_keys.dart';
import '../state/dictionaries_provider.dart';
import 'dictionaries_page.dart';

/// One key list (spec 7.7 step 7). Layout only: every mutation goes through
/// [DictionaryLibrary], which writes the whole list back — a dictionary is
/// read and written whole (`tables.dart`).
///
/// Spec 8.5's one-public-type rule is relaxed here (Global Constraints):
/// the private key row and key form below are this screen and nothing else.
class DictionaryDetailPage extends ConsumerWidget {
  const DictionaryDetailPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<KeyDictionary> all =
        ref.watch(dictionariesProvider).value ?? const <KeyDictionary>[];
    final KeyDictionary? dictionary = all
        .where((KeyDictionary d) => d.id == id)
        .firstOrNull;
    if (dictionary == null) {
      // A route to a list that has since been deleted — including the
      // moment right after this screen's own Delete button lands.
      return SubPageScaffold(
        title: l10n.dictTitle,
        body: Padding(
          padding: const EdgeInsets.all(SpectraSpacing.lg),
          child: SpectraCard(child: Text(l10n.dictNotFound)),
        ),
      );
    }

    final AsyncValue<void> write = ref.watch(dictionaryLibraryProvider);
    final bool busy = write.isLoading;
    final bool readOnly = isBuiltIn(dictionary);
    final DictionaryLibrary library = ref.read(
      dictionaryLibraryProvider.notifier,
    );

    return SubPageScaffold(
      title: dictionaryDisplayName(dictionary, l10n),
      body: ListView(
        padding: const EdgeInsets.all(SpectraSpacing.lg),
        children: <Widget>[
          if (write.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: SpectraSpacing.md),
              child: ProblemView(
                error: write.error!,
                variant: SpectraButtonVariant.secondary,
                onAction: library.reset,
              ),
            ),
          SpectraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(dictionaryDisplayName(dictionary, l10n)),
                if (readOnly) ...<Widget>[
                  const SizedBox(height: SpectraSpacing.sm),
                  Text(l10n.dictBuiltInNote),
                ],
                const SizedBox(height: SpectraSpacing.md),
                Wrap(
                  spacing: SpectraSpacing.sm,
                  children: <Widget>[
                    if (!readOnly)
                      SpectraButton(
                        label: l10n.dictRename,
                        variant: SpectraButtonVariant.secondary,
                        onPressed: busy
                            ? null
                            : () => unawaited(
                                _rename(context, library, dictionary, l10n),
                              ),
                      ),
                    SpectraButton(
                      label: l10n.dictDuplicate,
                      variant: SpectraButtonVariant.secondary,
                      onPressed: busy
                          ? null
                          : () => unawaited(
                              _duplicate(context, library, dictionary, l10n),
                            ),
                    ),
                    if (!readOnly)
                      SpectraButton(
                        label: l10n.dictDelete,
                        variant: SpectraButtonVariant.secondary,
                        onPressed: busy
                            ? null
                            : () => unawaited(
                                _delete(context, library, dictionary, l10n),
                              ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: SpectraSpacing.lg),
          SpectraSectionHeader(title: l10n.dictKeysTitle),
          if (dictionary.keys.isEmpty)
            SpectraCard(child: Text(l10n.dictNoKeys)),
          for (int i = 0; i < dictionary.keys.length; i++)
            SpectraListTile(
              title: toHex(dictionary.keys[i]),
              trailing: readOnly
                  ? null
                  : IconButton(
                      tooltip: l10n.dictRemoveKey,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: busy
                          ? null
                          : () => unawaited(
                              library.setKeys(
                                dictionary,
                                <Uint8List>[...dictionary.keys]..removeAt(i),
                              ),
                            ),
                    ),
            ),
          if (!readOnly) ...<Widget>[
            const SizedBox(height: SpectraSpacing.lg),
            _KeyForm(dictionary: dictionary, busy: busy),
          ],
        ],
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    DictionaryLibrary library,
    KeyDictionary dictionary,
    AppLocalizations l10n,
  ) async {
    final String? name = await showDictionaryNameSheet(
      context,
      title: l10n.dictRenameTitle,
      initialValue: dictionary.name,
    );
    if (name == null) return;
    await library.rename(dictionary, name);
  }

  Future<void> _duplicate(
    BuildContext context,
    DictionaryLibrary library,
    KeyDictionary dictionary,
    AppLocalizations l10n,
  ) async {
    final GoRouter router = GoRouter.of(context);
    final String? name = await showDictionaryNameSheet(
      context,
      title: l10n.dictDuplicateTitle,
      initialValue: l10n.dictDuplicateSuffix(
        dictionaryDisplayName(dictionary, l10n),
      ),
    );
    if (name == null) return;
    // Navigate to the copy: it is the only way this screen can show its
    // name, since the built-in list this ran from never changes id.
    final String? newId = await library.duplicate(dictionary, name);
    if (newId != null) router.go(AppRoutes.dictionary(newId));
  }

  Future<void> _delete(
    BuildContext context,
    DictionaryLibrary library,
    KeyDictionary dictionary,
    AppLocalizations l10n,
  ) async {
    final GoRouter router = GoRouter.of(context);
    final bool? confirmed = await SpectraDialog.show<bool>(
      context: context,
      title: l10n.dictDeleteTitle,
      content: Text(l10n.dictDeleteBody),
      actions: (BuildContext context) => <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.dictDelete),
        ),
      ],
    );
    if (confirmed != true) return;
    await library.remove(dictionary.id);
    router.go(AppRoutes.dictionaries);
  }
}

/// Adds one key. Validation is [parseMifareKey] plus a duplicate check —
/// a dictionary with the same key twice costs a wasted authentication
/// attempt on every sector.
class _KeyForm extends ConsumerStatefulWidget {
  const _KeyForm({required this.dictionary, required this.busy});

  final KeyDictionary dictionary;
  final bool busy;

  @override
  ConsumerState<_KeyForm> createState() => _KeyFormState();
}

class _KeyFormState extends ConsumerState<_KeyForm> {
  final TextEditingController _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Uint8List? key = parseMifareKey(_text.text);
    if (key == null) {
      setState(() => _error = l10n.dictKeyInvalid);
      return;
    }
    final String hex = toHex(key);
    if (widget.dictionary.keys.map<String>(toHex).contains(hex)) {
      setState(() => _error = l10n.dictKeyDuplicate);
      return;
    }
    setState(() => _error = null);
    await ref.read(dictionaryLibraryProvider.notifier).setKeys(
      widget.dictionary,
      <Uint8List>[...widget.dictionary.keys, key],
    );
    if (!mounted) return;
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SpectraTextField(
          label: l10n.dictKeyLabel,
          hint: l10n.dictKeyHint,
          controller: _text,
          errorText: _error,
        ),
        const SizedBox(height: SpectraSpacing.md),
        SpectraButton(
          label: l10n.dictAddKey,
          onPressed: widget.busy ? null : () => unawaited(_add()),
        ),
      ],
    );
  }
}

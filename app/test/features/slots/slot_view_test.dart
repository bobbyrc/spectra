import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/format/tag_labels.dart';
import 'package:spectra/features/slots/state/slot_view.dart';
import 'package:spectra/l10n/app_localizations.dart';
import 'package:spectra/l10n/app_localizations_en.dart';

Slot _slot(
  int index, {
  TagType hf = TagType.undefined,
  TagType lf = TagType.undefined,
  bool hfOn = false,
  bool lfOn = false,
  String hfNick = '',
  String lfNick = '',
}) => Slot(
  index: index,
  hfType: hf,
  lfType: lf,
  hfEnabled: hfOn,
  lfEnabled: lfOn,
  hfNick: hfNick,
  lfNick: lfNick,
);

void main() {
  final AppLocalizations l10n = AppLocalizationsEn();

  test('the number the device prints is one-based', () {
    expect(SlotView(slot: _slot(0), isActive: false).number, 1);
    expect(SlotView(slot: _slot(7), isActive: false).index, 7);
  });

  test('a slot is enabled when either sense is', () {
    expect(SlotView(slot: _slot(0), isActive: false).isEnabled, isFalse);
    expect(
      SlotView(slot: _slot(0, lfOn: true), isActive: false).isEnabled,
      isTrue,
    );
  });

  test('the HF nickname wins, then LF, then null', () {
    expect(
      SlotView(
        slot: _slot(0, hfNick: 'badge', lfNick: 'fob'),
        isActive: false,
      ).nickname,
      'badge',
    );
    expect(
      SlotView(slot: _slot(0, lfNick: 'fob'), isActive: false).nickname,
      'fob',
    );
    expect(SlotView(slot: _slot(0), isActive: false).nickname, isNull);
  });

  test('only defined types are shown, HF before LF', () {
    final SlotView view = SlotView(
      slot: _slot(0, hf: TagType.mifare1k, lf: TagType.em410x),
      isActive: false,
    );
    expect(view.presentTypes, <TagType>[TagType.mifare1k, TagType.em410x]);
    expect(slotTypeLabels(view.presentTypes, l10n), <String>[
      'MIFARE Classic 1K',
      'EM410x',
    ]);
  });

  test('an empty slot shows no type labels at all', () {
    final SlotView view = SlotView(slot: _slot(3), isActive: false);
    expect(view.presentTypes, isEmpty);
    expect(slotTypeLabels(view.presentTypes, l10n), isEmpty);
  });

  test('buildSlotViews marks exactly the active index', () {
    final List<SlotView> views = buildSlotViews(<Slot>[
      _slot(0),
      _slot(1),
      _slot(2),
    ], 1);
    expect(views.map((SlotView v) => v.isActive), <bool>[false, true, false]);
  });

  test('a null active index marks nothing', () {
    final List<SlotView> views = buildSlotViews(<Slot>[_slot(0)], null);
    expect(views.single.isActive, isFalse);
  });

  test('no slots means no views', () {
    expect(buildSlotViews(const <Slot>[], 0), isEmpty);
  });
}

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/format/tag_labels.dart';
import 'package:spectra/l10n/app_localizations.dart';
import 'package:spectra/l10n/app_localizations_en.dart';

void main() {
  final AppLocalizations l10n = AppLocalizationsEn();

  test('a product name is the part number, not translated copy', () {
    expect(tagTypeLabel(TagType.mifare1k, l10n), 'MIFARE Classic 1K');
    expect(tagTypeLabel(TagType.ntag215, l10n), 'NTAG215');
    expect(tagTypeLabel(TagType.em410x, l10n), 'EM410x');
  });

  test('the undefined type reads as the localized empty label', () {
    expect(tagTypeLabel(TagType.undefined, l10n), l10n.slotTypeEmpty);
  });

  test('every TagType has a label', () {
    for (final TagType type in TagType.values) {
      expect(tagTypeLabel(type, l10n), isNotEmpty, reason: type.name);
    }
  });

  test('sense labels are localized', () {
    expect(senseLabel(Sense.hf, l10n), l10n.slotSenseHf);
    expect(senseLabel(Sense.lf, l10n), l10n.slotSenseLf);
  });
}

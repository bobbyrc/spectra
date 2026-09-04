import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/format/sector_list.dart';

void main() {
  test('one sector is just its index', () {
    expect(formatSectorList(<int>[0]), '0');
    expect(formatSectorList(<int>[15]), '15');
  });

  test('two sectors are joined with and', () {
    expect(formatSectorList(<int>[3, 7]), '3 and 7');
  });

  test('three or more take commas and a final and', () {
    expect(formatSectorList(<int>[0, 3, 7]), '0, 3 and 7');
    expect(
      formatSectorList(List<int>.generate(16, (int i) => i)),
      '0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 and 15',
    );
  });

  test('an empty list is an empty string, not a crash', () {
    // Both callers gate on `sectors.isNotEmpty`, so this is the defensive
    // branch rather than a rendered one.
    expect(formatSectorList(<int>[]), '');
  });
}

import 'package:chameleon/src/commands/iso14443_4.dart';
import 'package:test/test.dart';

void main() {
  test('iso14443_4CommandIds is exactly 6000..6005', () {
    expect(iso14443_4CommandIds, {6000, 6001, 6002, 6003, 6004, 6005});
  });
}

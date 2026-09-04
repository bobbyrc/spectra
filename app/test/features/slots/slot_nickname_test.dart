import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/slots/state/slot_nickname.dart';

void main() {
  test('the wire limit is 32 bytes', () {
    expect(slotNicknameMaxBytes, 32);
  });

  test('an empty name is valid — it clears the nickname', () {
    expect(validateSlotNickname(''), isNull);
  });

  test('32 ASCII characters fit', () {
    expect(validateSlotNickname('a' * 32), isNull);
  });

  test('33 ASCII characters do not', () {
    expect(validateSlotNickname('a' * 33), SlotNicknameError.tooLong);
  });

  test('the limit is bytes, not characters', () {
    // Each of these is 4 UTF-8 bytes, so nine of them overflow 32.
    expect(validateSlotNickname('😀' * 8), isNull);
    expect(validateSlotNickname('😀' * 9), SlotNicknameError.tooLong);
  });
}

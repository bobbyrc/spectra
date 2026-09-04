import 'dart:convert';

/// The firmware's nickname limit, in UTF-8 bytes.
///
/// SET_SLOT_TAG_NICK (1007) takes `slot(1) sense(1) utf8<=32`
/// (`docs/research/chameleon-protocol.md`, command table). The SDK enforces
/// the same limit in `SetSlotTagNick.encode`, but with an `ArgumentError` —
/// not a `ChameleonException` the error catalog knows — and its
/// `maxNickBytes` constant is internal to `packages/chameleon/lib/src`, so
/// the app declares its own and validates *before* sending.
const int slotNicknameMaxBytes = 32;

enum SlotNicknameError { tooLong }

/// Null when [value] can be sent as a slot nickname. An empty name is
/// valid: the firmware stores an empty nickname, which is how a name is
/// cleared.
SlotNicknameError? validateSlotNickname(String value) =>
    utf8.encode(value).length > slotNicknameMaxBytes
    ? SlotNicknameError.tooLong
    : null;

/// ISO14443-4 commands 6000-6005 (Ultra only). All hardware-validate; the
/// wiki does not document payloads. Reach them through RawCommand:
///
/// | 6000 | APDU_RECV | 6001 | APDU_SEND | 6002 | SET_ANTI_COLL |
/// | 6003 | STATIC_RESP | 6004 | READER_APDU | 6005 | EMV_SCAN |
library;

const Set<int> iso14443_4CommandIds = {6000, 6001, 6002, 6003, 6004, 6005};

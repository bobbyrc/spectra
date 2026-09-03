/// Firmware status codes (app_status.h).
abstract final class Status {
  static const int hfTagOk = 0x00;
  static const int hfTagNo = 0x01;
  static const int hfErrStat = 0x02;
  static const int hfErrCrc = 0x03;
  static const int hfCollision = 0x04;
  static const int hfErrBcc = 0x05;
  static const int mfErrAuth = 0x06;
  static const int hfErrParity = 0x07;
  static const int hfErrAts = 0x08;
  static const int lfTagOk = 0x40;
  static const int lfTagNoFound = 0x41;
  static const int lfTagLoginRequired = 0x42;
  static const int parErr = 0x60;
  static const int deviceModeError = 0x66;
  static const int invalidCmd = 0x67;
  static const int success = 0x68;
  static const int notImplemented = 0x69;
  static const int flashWriteFail = 0x70;
  static const int flashReadFail = 0x71;
  static const int invalidSlotType = 0x72;
  static const int memErr = 0x73;
  static const int createResponseErr = 0x74;
  static const int cmdErr = 0x75;
}

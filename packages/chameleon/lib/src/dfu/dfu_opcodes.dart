/// Nordic Secure DFU v1 control-point opcodes, result codes and object types.
///
/// Every multi-byte field in a control payload is little-endian.
abstract final class DfuOp {
  static const int create = 0x01;
  static const int setPrn = 0x02;
  static const int calcCrc = 0x03;
  static const int execute = 0x04;
  static const int select = 0x06;

  /// Serial transport only: ask the bootloader for its SLIP MTU. nrfutil's
  /// `DfuTransportSerial.__get_mtu` sends this and reads a little-endian
  /// uint16 back; the BLE bootloader answers "opcode not supported".
  static const int getSerialMtu = 0x07;

  static const int response = 0x60;

  static const int resultSuccess = 0x01;
  static const int resultOpcodeNotSupported = 0x02;
  static const int resultInvalidParameter = 0x03;
  static const int resultInsufficientResources = 0x04;
  static const int resultInvalidObject = 0x05;
  static const int resultUnsupportedType = 0x07;
  static const int resultNotPermitted = 0x08;
  static const int resultOperationFailed = 0x0A;

  /// Object type 1: the init packet (.dat).
  static const int typeCommand = 1;

  /// Object type 2: the firmware image (.bin).
  static const int typeData = 2;
}

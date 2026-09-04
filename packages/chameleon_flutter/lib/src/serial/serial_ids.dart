/// USB identifiers and line settings for the Chameleon over CDC-ACM
/// (spec 5.2, 5.5; `docs/research/chameleon-protocol.md`).
abstract final class ChameleonUsbIds {
  static const int applicationVid = 0x6868;
  static const int applicationPid = 0x8686;
  static const int bootloaderVid = 0x1915;
  static const int bootloaderPid = 0x521F;
  static const String manufacturer = 'Proxgrind';

  static const int baudRate = 115200;
  static const int dataBits = 8;
  static const int stopBits = 1;
}

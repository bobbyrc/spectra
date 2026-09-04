import 'dart:typed_data';

import '../codec/bytes.dart';
import '../codec/frame.dart';
import '../model/enums.dart';
import '../model/models.dart';
import '../protocol/command.dart';
import '../protocol/errors.dart';
import '../protocol/status.dart';
import 'fake_card.dart';
import 'fake_device_handlers.dart';
import 'fake_emulator_handlers.dart';
import 'fake_firmware_config.dart';
import 'fake_reader_handlers.dart';
import 'fake_slot.dart';

/// Answers frames the way the firmware does. Pure: no timers, no streams.
///
/// The handlers live in extensions next door ([FakeDeviceHandlers],
/// [FakeReaderHandlers], [FakeEmulatorHandlers]); this class owns the state
/// they mutate and the dispatch that reaches them.
final class FakeFirmware {
  FakeFirmware([FakeFirmwareConfig? config])
    : config = config ?? FakeFirmwareConfig() {
    settings = defaultSettings(this.config.settingsVersion);
    savedSettings = settings;
    slots[0]
      ..hfType = TagType.mifare1k
      ..hfEnabled = true
      ..hfNick = 'Fake 1K'
      ..lfType = TagType.em410x
      ..lfEnabled = true;
  }

  final FakeFirmwareConfig config;
  final List<FakeSlot> slots = List.generate(8, (_) => FakeSlot());
  DeviceMode mode = DeviceMode.emulator;
  int activeSlot = 0;
  late DeviceSettings settings;
  late DeviceSettings savedSettings;
  bool slotsSaved = true;
  BatteryInfo battery = const BatteryInfo(millivolts: 4100, percent: 92);
  bool bootloaderRequested = false;
  FakeCard? hfCard;
  FakeCard? lfCard;

  /// Puts a card in the field. LF cards answer LF scans, everything else HF.
  void present(FakeCard card) {
    if (card is FakeLfCard) {
      lfCard = card;
    } else {
      hfCard = card;
    }
  }

  void removeCards() {
    hfCard = null;
    lfCard = null;
  }

  /// The slot every emulator command reads and writes.
  FakeSlot get slot => slots[activeSlot];

  /// Answers one request frame, or null when the firmware stays silent.
  Frame? handle(Frame req) {
    final cmd = req.command;
    if (cmd == 1010) {
      bootloaderRequested = true;
      return null;
    }
    if (cmd == 1035 && !config.respondsToCapabilities) {
      return statusFrame(cmd, Status.invalidCmd);
    }
    if (!config.effectiveCapabilities.contains(cmd)) {
      return statusFrame(cmd, Status.invalidCmd);
    }
    final range = CommandRange.forId(cmd);
    final isReader =
        range == CommandRange.hfReader || range == CommandRange.lfReader;
    if (isReader && mode != DeviceMode.reader) {
      return statusFrame(cmd, Status.deviceModeError);
    }
    try {
      return _dispatch(cmd, range, ByteReader(req.data));
    } on MalformedResponse {
      return statusFrame(cmd, Status.parErr);
    } on RangeError {
      // An index the emulation memory cannot hold: the device rejects the
      // parameters rather than faulting.
      return statusFrame(cmd, Status.parErr);
    }
  }

  Frame _dispatch(int cmd, CommandRange range, ByteReader r) => switch (range) {
    CommandRange.device => handleDevice(cmd, r),
    CommandRange.hfReader => handleHfReader(cmd, r),
    CommandRange.lfReader => handleLfReader(cmd, r),
    CommandRange.hfEmulator => handleHfEmulator(cmd, r),
    CommandRange.lfEmulator => handleLfEmulator(cmd, r),
    CommandRange.iso14443_4 => statusFrame(cmd, Status.notImplemented),
  };

  /// A reply frame with an explicit status.
  Frame statusFrame(int cmd, int status, [List<int>? data]) => Frame(
    command: cmd,
    status: status,
    data: data == null ? null : Uint8List.fromList(data),
  );

  /// A reply frame carrying the success status of the command's range.
  Frame okFrame(int cmd, [List<int>? data]) =>
      statusFrame(cmd, CommandRange.forId(cmd).successStatus, data);

  /// Rejects an out-of-range slot the way a short payload is rejected: the
  /// caller turns [MalformedResponse] into PAR_ERR.
  int slotIndex(int i) {
    if (i < 0 || i > 7) throw const MalformedResponse('slot out of range');
    return i;
  }

  /// The HF14A anti-collision payload shared by scan and emulator replies.
  static Uint8List antiCollBytes(
    Uint8List uid,
    Uint8List atqa,
    int sak,
    Uint8List ats,
  ) => ByteWriter()
      .u8(uid.length)
      .bytes(uid)
      .bytes(atqa)
      .u8(sak)
      .u8(ats.length)
      .bytes(ats)
      .toBytes();

  /// Factory settings for a given settings-struct version. v5 has no sleep
  /// timeout; v6 adds one.
  static DeviceSettings defaultSettings(int version) => DeviceSettings(
    version: version,
    animation: AnimationMode.full,
    buttonA: ButtonFunction.nextSlot,
    buttonB: ButtonFunction.prevSlot,
    longButtonA: ButtonFunction.cloneUid,
    longButtonB: ButtonFunction.battery,
    blePairingEnabled: false,
    blePairingKey: '123456',
    sleepTimeoutSeconds: version >= 6 ? 8 : null,
  );
}

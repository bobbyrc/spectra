import '../commands/lf_emulator.dart' show emuLfIdLengths;
import '../model/enums.dart';
import '../model/models.dart';

/// How a [FakeFirmware] presents itself: model, firmware version and the
/// command ids it admits to supporting.
///
/// The named constructors cover the version matrix the connect handshake has
/// to survive: 2.2, 2.0 (no GET_ALL_SLOT_NICKS, settings v5),
/// a Lite, a pre-2.0 device that does not answer GET_DEVICE_CAPABILITIES at
/// all, and the legacy 0.1 firmware.
final class FakeFirmwareConfig {
  FakeFirmwareConfig({
    this.model = DeviceModel.ultra,
    this.version = const FirmwareVersion(major: 2, minor: 2),
    this.gitVersion = 'v2.2.0-fake',
    this.chipId = '0102030405060708',
    this.address = '00:11:22:33:44:55',
    this.capabilities,
    this.respondsToCapabilities = true,
    this.settingsVersion = 6,
  });

  factory FakeFirmwareConfig.ultra22() => FakeFirmwareConfig();

  factory FakeFirmwareConfig.ultra20() => FakeFirmwareConfig(
    version: const FirmwareVersion(major: 2, minor: 0),
    gitVersion: 'v2.0.0-fake',
    capabilities: defaultCapabilities(DeviceModel.ultra)
      ..removeAll({1038, 1039, 1040}),
    settingsVersion: 5,
  );

  factory FakeFirmwareConfig.lite22() =>
      FakeFirmwareConfig(model: DeviceModel.lite);

  factory FakeFirmwareConfig.preTwoPointZero() => FakeFirmwareConfig(
    version: const FirmwareVersion(major: 1, minor: 0),
    respondsToCapabilities: false,
  );

  /// The 0.1 firmware: no GET_DEVICE_CAPABILITIES, so the session falls back
  /// to a limited feature set.
  factory FakeFirmwareConfig.legacy01() => FakeFirmwareConfig(
    version: const FirmwareVersion(major: 0, minor: 1),
    gitVersion: 'v0.1.0-fake',
    respondsToCapabilities: false,
    settingsVersion: 5,
  );

  final DeviceModel model;
  final FirmwareVersion version;
  final String gitVersion;
  final String chipId;
  final String address;
  final Set<int>? capabilities;
  final bool respondsToCapabilities;
  final int settingsVersion;

  /// Computed once so tests can mutate it to simulate missing commands.
  late final Set<int> effectiveCapabilities =
      capabilities ?? defaultCapabilities(model);

  /// What a stock device of [model] answers — and nothing more.
  ///
  /// This is exactly the set [FakeFirmware] has handlers for, so a session
  /// built on the fake never believes in a command that would come back
  /// NOT_IMPLEMENTED. Real firmware advertises more (the Ultralight version,
  /// signature and counter commands, MF0 write modes, the SEOS pair
  /// 4042-4044, ISO14443-4 6000-6005, IoProx emulation 5008/5009); those are
  /// deliberately absent here rather than advertised and refused, and the
  /// version matrix stays meaningful through the ids the fake does answer:
  /// GET_ALL_SLOT_NICKS (1038-1040) is the 2.2-only feature the 2.0 factory
  /// removes.
  ///
  /// The Lite has no reader, so it answers neither HF nor LF reader commands.
  static Set<int> defaultCapabilities(DeviceModel model) {
    final ids = <int>{
      // Device: 1000-1040 except SET_SLOT_DATA_CONFIG (1022), which the
      // firmware itself does not use.
      for (var i = 1000; i <= 1040; i++)
        if (i != 1022) i,
      // HF emulator: anti-collision, MF1 emulation memory and config,
      // detection log, NTAG pages and page count.
      4000, 4001,
      for (var i = 4004; i <= 4022; i++) i,
      4030,
      // LF emulator: the id set/get pairs whose length is documented
      // (EM410x, HID Prox, Viking, PAC, Jablotron, Idteck). IoProx
      // (5008/5009) has no documented length and is left out.
      for (final id in emuLfIdLengths.keys) ...[id, id + 1],
    };
    if (model == DeviceModel.ultra) {
      ids.addAll({
        // HF reader: scan, MF1 support/PRNG detection, auth, read/write,
        // check-keys-of-sectors and the two raw commands.
        2000, 2001, 2002, 2007, 2008, 2009, 2012, 2100, 2101,
        // LF reader: EM410x, HID Prox, Viking and PAC scans.
        3000, 3002, 3004, 3014,
      });
    }
    return ids;
  }
}

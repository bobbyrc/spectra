import '../model/enums.dart';
import '../model/models.dart';

/// How a [FakeFirmware] presents itself: model, firmware version and the
/// command ids it admits to supporting.
///
/// The named constructors cover the version matrix the connect handshake has
/// to survive: 2.2 (with SEOS), 2.0 (no GET_ALL_SLOT_NICKS, settings v5),
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
      ..removeAll({1038, 1039, 1040, 4042, 4043, 4044}),
    settingsVersion: 5,
  );

  factory FakeFirmwareConfig.lite22() =>
      FakeFirmwareConfig(model: DeviceModel.lite);

  factory FakeFirmwareConfig.preTwoPointZero() => FakeFirmwareConfig(
    version: const FirmwareVersion(major: 1, minor: 0),
    respondsToCapabilities: false,
  );

  factory FakeFirmwareConfig.legacy01() =>
      FakeFirmwareConfig(version: const FirmwareVersion(major: 0, minor: 1));

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

  /// Everything a stock device of [model] answers. The Lite has no reader.
  static Set<int> defaultCapabilities(DeviceModel model) {
    final ids = <int>{
      for (var i = 1000; i <= 1040; i++)
        if (i != 1022) i,
      for (var i = 4000; i <= 4044; i++)
        if (i != 4002 && i != 4003) i,
      for (var i = 5000; i <= 5013; i++) i,
    };
    if (model == DeviceModel.ultra) {
      ids.addAll({
        for (var i = 2000; i <= 2017; i++) i,
        2020,
        2100,
        2101,
        2200,
        2201,
        for (var i = 3000; i <= 3006; i++) i,
        for (var i = 3009; i <= 3016; i++) i,
        3018,
        3019,
        3020,
        3030,
        3031,
        for (var i = 6000; i <= 6005; i++) i,
      });
    }
    return ids;
  }
}

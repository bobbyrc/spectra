import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'models.freezed.dart';

String hexOf(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();

@freezed
abstract class FirmwareVersion with _$FirmwareVersion {
  const FirmwareVersion._();
  const factory FirmwareVersion({required int major, required int minor}) =
      _FirmwareVersion;

  String get label => '$major.$minor';
  bool get isLegacy => major == 0 && minor == 1;
  bool isBefore(FirmwareVersion other) =>
      major < other.major || (major == other.major && minor < other.minor);
}

@freezed
abstract class Capabilities with _$Capabilities {
  const Capabilities._();
  const factory Capabilities(Set<int> commandIds) = _Capabilities;

  bool supports(int commandId) => commandIds.contains(commandId);
  bool get hasReader => supports(2000);
}

@freezed
abstract class DeviceIdentity with _$DeviceIdentity {
  const factory DeviceIdentity(String chipId) = _DeviceIdentity;
}

@freezed
abstract class DeviceInfo with _$DeviceInfo {
  const factory DeviceInfo({
    required DeviceModel model,
    required FirmwareVersion version,
    required Capabilities capabilities,
    String? gitVersion,
    DeviceIdentity? identity,
    String? bleAddress,
  }) = _DeviceInfo;
}

@freezed
abstract class Slot with _$Slot {
  const factory Slot({
    required int index,
    required TagType hfType,
    required TagType lfType,
    required bool hfEnabled,
    required bool lfEnabled,
    @Default('') String hfNick,
    @Default('') String lfNick,
  }) = _Slot;
}

@freezed
abstract class BatteryInfo with _$BatteryInfo {
  const factory BatteryInfo({required int millivolts, required int percent}) =
      _BatteryInfo;
}

@freezed
abstract class DeviceSettings with _$DeviceSettings {
  const factory DeviceSettings({
    required int version,
    required AnimationMode animation,
    required ButtonFunction buttonA,
    required ButtonFunction buttonB,
    required ButtonFunction longButtonA,
    required ButtonFunction longButtonB,
    required bool blePairingEnabled,
    required String blePairingKey,
    int? sleepTimeoutSeconds,
  }) = _DeviceSettings;
}

@freezed
abstract class Hf14aTag with _$Hf14aTag {
  const Hf14aTag._();
  const factory Hf14aTag({
    required Uint8List uid,
    required Uint8List atqa,
    required int sak,
    required Uint8List ats,
  }) = _Hf14aTag;

  String get uidHex => hexOf(uid);
}

@freezed
abstract class Mf1EmulatorConfig with _$Mf1EmulatorConfig {
  const factory Mf1EmulatorConfig({
    required bool detectionEnabled,
    required bool gen1a,
    required bool gen2,
    required bool blockAntiColl,
    required Mf1WriteMode writeMode,
  }) = _Mf1EmulatorConfig;
}

@freezed
abstract class SectorKeys with _$SectorKeys {
  const factory SectorKeys({
    required int sector,
    Uint8List? keyA,
    Uint8List? keyB,
  }) = _SectorKeys;
}

@freezed
abstract class Mf1KeyCheckResult with _$Mf1KeyCheckResult {
  const factory Mf1KeyCheckResult(List<SectorKeys> sectors) =
      _Mf1KeyCheckResult;
}

/// One nonce capture from MF1 detection mode. hardware-validate.
@freezed
abstract class DetectionLogEntry with _$DetectionLogEntry {
  const factory DetectionLogEntry({
    required int block,
    required KeyType keyType,
    required bool isNested,
    required Uint8List uid,
    required int nt,
    required int nr,
    required int ar,
  }) = _DetectionLogEntry;
}

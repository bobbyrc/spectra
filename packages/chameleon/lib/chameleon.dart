/// Clean-room Dart SDK for the Chameleon Ultra and Chameleon Lite.
///
/// Pure Dart: this library never imports Flutter. Everything an app needs is
/// exported here; `lib/src` is private. Commands are deliberately internal
/// (spec 3.2): an app talks to the device through the facades on
/// [DeviceSession], never by building a `Command` of its own.
library;

// Codec. The frame is public because the frame log carries frames; the byte
// readers, the LRC and the command catalogs stay internal.
export 'src/codec/frame.dart' show Frame;
export 'src/codec/frame_decoder.dart'
    show
        BadLrcDiagnostic,
        DecodeDiagnostic,
        FrameDecoder,
        OversizedFrameDiagnostic,
        ResyncDiagnostic;

// DFU (spec 4.5).
export 'src/dfu/dfu_channel.dart';
export 'src/dfu/dfu_orchestrator.dart';
export 'src/dfu/dfu_package.dart';
export 'src/dfu/dfu_types.dart';
export 'src/dfu/fake_bootloader.dart';
export 'src/dfu/fake_dfu_channel.dart';
export 'src/dfu/secure_dfu.dart' show SecureDfu;
export 'src/dfu/serial_mtu.dart';

// Dump formats (spec 3.5, 8.2).
export 'src/dump/dump_format.dart';
export 'src/dump/em410x.dart';
export 'src/dump/mf1_dump_read_result.dart';
export 'src/dump/mf1_dump_write_result.dart';
export 'src/dump/mifare_classic.dart';
export 'src/dump/mifare_geometry.dart';
export 'src/dump/ultralight.dart';

// The fake device, so apps and their tests can run with no hardware
// (spec 4.4).
export 'src/fake/fake_card.dart';
export 'src/fake/fake_device.dart';
export 'src/fake/fake_firmware.dart';
export 'src/fake/fake_firmware_config.dart';
export 'src/fake/fake_scanner.dart';
export 'src/fake/fake_slot.dart';

// Model. `hexOf` and the generated freezed classes are implementation detail.
export 'src/model/enums.dart';
export 'src/model/models.dart'
    show
        BatteryInfo,
        Capabilities,
        DetectionLogEntry,
        DeviceIdentity,
        DeviceInfo,
        DeviceSettings,
        FirmwareVersion,
        Hf14aTag,
        Mf1EmulatorConfig,
        Mf1KeyCheckResult,
        SectorKeys,
        Slot;

// Errors (spec 9). The raw firmware status codes stay internal: a caller
// sees a typed `DeviceError`, never a status int to compare (spec 3.3).
export 'src/protocol/errors.dart';

// Session, state and the typed facades (spec 4.3, 8.1).
export 'src/session/cancel_token.dart';
export 'src/session/connection_state.dart';
export 'src/session/device_session.dart';
export 'src/session/facades/device.dart';
export 'src/session/facades/emulator.dart';
export 'src/session/facades/firmware.dart';
export 'src/session/facades/reader.dart';
export 'src/session/facades/settings.dart';
export 'src/session/facades/slots.dart';
export 'src/session/reader_lease.dart';
export 'src/session/state_stream.dart';

// Transport seam: implemented per platform in `chameleon_flutter`.
export 'src/transport/frame_log.dart';
export 'src/transport/scanner.dart';
export 'src/transport/transport.dart';

/// Version of the SDK, mirrored from pubspec.yaml.
const String chameleonSdkVersion = '0.1.0';

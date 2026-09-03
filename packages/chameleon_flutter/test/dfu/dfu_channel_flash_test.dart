import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_ble_adapter.dart';

/// A serial link whose other end is [bootloader]: every SLIP frame written
/// is decoded and dispatched, and every reply is SLIP-framed back.
///
/// The WriteObject opcode and the "opcode plus raw data, no length prefix"
/// layout are the channel's own (`slip_serial_dfu_channel.dart`, taken from
/// nrfutil's `__stream_data`).
final class _BootloaderSerialTransport implements Transport {
  _BootloaderSerialTransport(this.bootloader);

  static const int _writeObjectOpcode = 0x08;

  final FakeBootloader bootloader;
  final SlipDecoder _decoder = SlipDecoder();
  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  final StreamController<TransportState> _state =
      StreamController<TransportState>.broadcast();
  TransportState _current = const TransportOpen();
  bool _closed = false;

  @override
  TransportKind get kind => TransportKind.usb;
  @override
  Stream<Uint8List> get incoming => _incoming.stream;
  @override
  Stream<TransportState> get state => _state.stream;
  @override
  TransportState get currentState => _current;
  @override
  final int maxWriteLength = 4105;
  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _current = const TransportClosed(CloseCause.requested);
    if (!_state.isClosed) {
      _state.add(_current);
      await _state.close();
    }
    if (!_incoming.isClosed) await _incoming.close();
  }

  @override
  Future<void> write(Uint8List bytes) async {
    for (final frame in _decoder.add(bytes)) {
      if (frame.isNotEmpty && frame[0] == _writeObjectOpcode) {
        bootloader.handleData(Uint8List.sublistView(frame, 1));
        continue;
      }
      final reply = bootloader.handleControl(frame);
      scheduleMicrotask(() {
        if (!_incoming.isClosed) _incoming.add(Slip.encode(reply));
      });
    }
  }
}

/// A BLE adapter whose DFU service is [bootloader].
base class _BootloaderBleAdapter extends FakeBleAdapter {
  _BootloaderBleAdapter(this.bootloader);

  final FakeBootloader bootloader;

  @override
  Future<void> write(
    String deviceId, {
    required String service,
    required String characteristic,
    required Uint8List value,
    bool withResponse = true,
  }) async {
    await super.write(
      deviceId,
      service: service,
      characteristic: characteristic,
      value: value,
      withResponse: withResponse,
    );
    if (characteristic == NordicDfuUuids.packet) {
      bootloader.handleData(value);
      return;
    }
    final reply = bootloader.handleControl(value);
    scheduleMicrotask(
      () => emitNotification(NordicDfuUuids.controlPoint, reply),
    );
  }
}

/// nrfutil stores the SHA-256 of the image byte-reversed in the init packet
/// (`packages/chameleon/lib/src/dfu/dfu_package.dart`, `DfuImage.hashMatches`;
/// hardware-validate, H2). Mirrors `packages/chameleon/test/dfu/proto_builder.dart`.
Uint8List _varint(int v) {
  final out = <int>[];
  var rest = v;
  while (rest >= 0x80) {
    out.add((rest & 0x7F) | 0x80);
    rest >>= 7;
  }
  out.add(rest);
  return Uint8List.fromList(out);
}

Uint8List _field(int number, int wire, List<int> payload) =>
    Uint8List.fromList(<int>[..._varint((number << 3) | wire), ...payload]);

Uint8List _varintField(int number, int v) => _field(number, 0, _varint(v));

Uint8List _bytesField(int number, List<int> b) =>
    _field(number, 2, <int>[..._varint(b.length), ...b]);

Uint8List _initPacket(Uint8List bin, {int hwVersion = 0}) {
  final hash = sha256.convert(bin).bytes.reversed.toList();
  final hashMsg = <int>[..._varintField(1, 3), ..._bytesField(2, hash)];
  final init = <int>[
    ..._varintField(1, 1),
    ..._varintField(2, hwVersion),
    ..._bytesField(3, _varint(0x0100)),
    ..._varintField(4, 4),
    ..._varintField(7, bin.length),
    ..._bytesField(8, hashMsg),
  ];
  final command = <int>[..._varintField(1, 1), ..._bytesField(2, init)];
  final signed = <int>[
    ..._bytesField(1, command),
    ..._varintField(2, 0),
    ..._bytesField(3, List<int>.filled(64, 0)),
  ];
  return _bytesField(2, signed);
}

Uint8List _zip(Uint8List bin) {
  final manifest = jsonEncode(<String, Object>{
    'manifest': <String, Object>{
      'application': <String, String>{
        'bin_file': 'app.bin',
        'dat_file': 'app.dat',
      },
    },
  });
  final archive = Archive()
    ..add(
      ArchiveFile.bytes(
        'manifest.json',
        Uint8List.fromList(utf8.encode(manifest)),
      ),
    )
    ..add(ArchiveFile.bytes('app.bin', bin))
    ..add(ArchiveFile.bytes('app.dat', _initPacket(bin)));
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

void main() {
  final Uint8List image = Uint8List.fromList(
    List<int>.generate(5000, (i) => i & 0xFF),
  );
  final DfuImage dfuImage = DfuPackage.fromZip(_zip(image)).images.single;

  test('SlipSerialDfuChannel flashes the whole image', () async {
    final bootloader = FakeBootloader();
    final transport = _BootloaderSerialTransport(bootloader);
    final channel = SlipSerialDfuChannel(transport);
    await channel.open();
    // The bootloader offered SLIP_MTU 2051, so writes grew to 1024.
    expect(channel.maxDataWrite, 1024);

    final progress = <int>[];
    await SecureDfu(channel)
        .run(dfuImage, onProgress: (p) => progress.add(p.bytesSent));
    await channel.close();

    expect(bootloader.completed, isTrue);
    expect(bootloader.flashed, image);
    expect(progress.last, image.length);
  });

  test('BleDfuChannel flashes the whole image', () async {
    final bootloader = FakeBootloader()..supportsSerialMtu = false;
    final adapter = _BootloaderBleAdapter(bootloader);
    final channel = BleDfuChannel(
      deviceId: 'CU',
      adapter: adapter,
      platform: HostPlatform.linux,
    );
    await channel.open();

    await SecureDfu(channel).run(dfuImage);
    await channel.close();

    expect(bootloader.completed, isTrue);
    expect(bootloader.flashed, image);
    await adapter.dispose();
  });
}

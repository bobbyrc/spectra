import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/tools/state/firmware_package_source.dart';

import '../../fixtures/dfu_package_fixture.dart';

final class _MemorySource implements FirmwarePackageSource {
  _MemorySource(this.files);
  final Map<String, Uint8List> files;

  @override
  Future<Uint8List> read(String path) async {
    final bytes = files[path.trim()];
    if (bytes == null) throw DfuError('no file at $path');
    return bytes;
  }
}

void main() {
  test('loads an Ultra package and summarises it', () async {
    final source = _MemorySource(<String, Uint8List>{
      '/tmp/ultra-dfu-app.zip': buildDfuZip(size: 4096),
    });

    final loaded = await loadFirmwarePackage(
      source,
      ' /tmp/ultra-dfu-app.zip ',
    );

    expect(loaded.fileName, 'ultra-dfu-app.zip');
    expect(loaded.targetModel, DeviceModel.ultra);
    expect(loaded.totalBytes, 4096);
    expect(loaded.imageCount, 1);
  });

  test('a Lite package reports the Lite as its target', () async {
    final source = _MemorySource(<String, Uint8List>{
      'lite.zip': buildDfuZip(hwVersion: 1),
    });
    final loaded = await loadFirmwarePackage(source, 'lite.zip');
    expect(loaded.targetModel, DeviceModel.lite);
  });

  test('a missing file fails as a DfuError', () async {
    final source = _MemorySource(const <String, Uint8List>{});
    expect(
      () => loadFirmwarePackage(source, 'nope.zip'),
      throwsA(isA<DfuError>()),
    );
  });

  test('something that is not a zip fails as a DfuError', () async {
    final source = _MemorySource(<String, Uint8List>{
      'x.zip': Uint8List.fromList(<int>[1, 2, 3, 4]),
    });
    expect(
      () => loadFirmwarePackage(source, 'x.zip'),
      throwsA(isA<DfuError>()),
    );
  });

  test('a Windows path still yields a file name', () async {
    final source = _MemorySource(<String, Uint8List>{
      r'C:\Users\me\ultra-dfu-full.zip': buildDfuZip(),
    });
    final loaded = await loadFirmwarePackage(
      source,
      r'C:\Users\me\ultra-dfu-full.zip',
    );
    expect(loaded.fileName, 'ultra-dfu-full.zip');
  });
}

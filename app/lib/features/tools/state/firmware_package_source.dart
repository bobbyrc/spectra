import 'dart:io';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'firmware_package_source.g.dart';

/// Where release packages come from. v1 takes a local zip; the release feed
/// and in-app download are Phase 10 (see the plan's resolved ambiguity).
const String firmwareReleasesUrl =
    'https://github.com/RfidResearchGroup/ChameleonUltra/releases';

/// Reads the bytes of a DFU package. A seam (spec 8.6) so tests never touch
/// the file system.
abstract interface class FirmwarePackageSource {
  Future<Uint8List> read(String path);
}

final class FileFirmwarePackageSource implements FirmwarePackageSource {
  const FileFirmwarePackageSource();

  @override
  Future<Uint8List> read(String path) async {
    final file = File(path.trim());
    // A typed failure, not a raw FileSystemException: the error catalog is
    // keyed by the sealed SDK types (spec 9) and a plain OS error would fall
    // through to "something went wrong".
    if (!file.existsSync()) throw DfuError('no file at ${path.trim()}');
    try {
      return await file.readAsBytes();
    } on FileSystemException catch (e) {
      throw DfuError('could not read ${path.trim()}: ${e.message}');
    }
  }
}

@Riverpod(keepAlive: true)
FirmwarePackageSource firmwarePackageSource(Ref ref) =>
    const FileFirmwarePackageSource();

/// One parsed package, plus what the screen says about it.
final class LoadedFirmwarePackage {
  const LoadedFirmwarePackage({required this.path, required this.package});

  final String path;
  final DfuPackage package;

  /// The last path segment, on either separator: a Windows path is typed by
  /// hand as often as a POSIX one.
  String get fileName => path.split(RegExp(r'[/\\]')).last;

  /// Firmware bytes across every image — what the progress bar counts.
  int get totalBytes =>
      package.images.fold<int>(0, (sum, image) => sum + image.bin.length);

  int get imageCount => package.images.length;

  /// Null when the package declares a hardware version that is neither 0
  /// (Ultra) nor 1 (Lite); `DfuOrchestrator` then leaves the check to the
  /// bootloader.
  DeviceModel? get targetModel => package.targetModel;
}

/// Reads and parses [path]. Every failure is a [DfuError], so the screen has
/// one thing to catch and the catalog one thing to describe.
Future<LoadedFirmwarePackage> loadFirmwarePackage(
  FirmwarePackageSource source,
  String path,
) async {
  final bytes = await source.read(path);
  return LoadedFirmwarePackage(
    path: path.trim(),
    package: DfuPackage.fromZip(bytes),
  );
}

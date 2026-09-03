/// Which part of the transfer is running.
enum DfuStage {
  /// Sending the init packet (the .dat command object).
  init,

  /// Sending the firmware image (the .bin data objects).
  firmware,

  /// The image is written and executed.
  done,
}

/// Progress of one image transfer.
///
/// [bytesSent] and [bytesTotal] count firmware bytes only: the init packet is
/// a few hundred bytes and would otherwise make the fraction jump backwards
/// when the firmware starts. The sequence is monotonic.
final class DfuProgress {
  const DfuProgress(this.stage, this.bytesSent, this.bytesTotal);

  final DfuStage stage;
  final int bytesSent;
  final int bytesTotal;

  double get fraction => bytesTotal == 0 ? 1.0 : bytesSent / bytesTotal;

  @override
  String toString() => 'DfuProgress($stage, $bytesSent/$bytesTotal)';
}

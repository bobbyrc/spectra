/// Longitudinal redundancy check used by the Chameleon frame format:
/// `(0x100 - (sum(bytes) & 0xFF)) & 0xFF`.
int lrc(Iterable<int> bytes) {
  var sum = 0;
  for (final b in bytes) {
    sum = (sum + b) & 0xFF;
  }
  return (0x100 - sum) & 0xFF;
}

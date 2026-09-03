final List<int> _table = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

/// IEEE CRC-32 as used by Nordic Secure DFU. Pass the previous value as
/// [seed] to continue over more data.
int crc32(List<int> bytes, [int seed = 0]) {
  var c = seed ^ 0xFFFFFFFF;
  for (final b in bytes) {
    c = _table[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

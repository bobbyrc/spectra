import 'package:chameleon/chameleon.dart';
import 'package:test/test.dart';

void main() {
  test('exposes an SDK version', () {
    expect(chameleonSdkVersion, '0.1.0');
  });
}

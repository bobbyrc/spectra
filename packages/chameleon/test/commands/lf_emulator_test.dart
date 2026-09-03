import 'dart:typed_data';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/commands/lf_emulator.dart';
import 'package:test/test.dart';

Uint8List b(List<int> l) => Uint8List.fromList(l);
Frame ok(int cmd, List<int> data) =>
    Frame(command: cmd, status: 0x68, data: b(data));

void main() {
  group('EM410x and HID Prox', () {
    test('set and get ids enforce fixed lengths', () {
      expect(Em410xSetEmuId(b([1, 2, 3, 4, 5])).encode(), [1, 2, 3, 4, 5]);
      expect(() => Em410xSetEmuId(b([1])).encode(), throwsArgumentError);
      expect(const Em410xGetEmuId().parseResponse(ok(5001, [1, 2, 3, 4, 5])), [
        1,
        2,
        3,
        4,
        5,
      ]);
      expect(HidProxSetEmuId(Uint8List(13)).id, 5002);
    });
  });

  group('Viking, PAC, Jablotron, Idteck', () {
    test('set and get ids enforce fixed lengths', () {
      expect(const VikingGetEmuId().id, 5005);
      expect(PacSetEmuId(Uint8List(8)).id, 5006);
      expect(const JablotronGetEmuId().id, 5011);
      expect(IdteckSetEmuId(Uint8List(8)).id, 5012);
    });
  }, tags: ['hardware-validate']);
}

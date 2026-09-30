import 'package:flutter_test/flutter_test.dart';
import 'package:mobicontrol/services/pin.dart';

void main() {
  group('Pin', () {
    test("to'g'ri PIN tasdiqlanadi, noto'g'risi yo'q", () {
      final hash = Pin.hash('1234');
      expect(Pin.verify('1234', hash), isTrue);
      expect(Pin.verify('0000', hash), isFalse);
      expect(Pin.verify('12345', hash), isFalse);
    });

    test('har safar tuz (salt) har xil, lekin ikkalasi ham tasdiqlanadi', () {
      final a = Pin.hash('4321');
      final b = Pin.hash('4321');
      expect(a, isNot(b));
      expect(Pin.verify('4321', a), isTrue);
      expect(Pin.verify('4321', b), isTrue);
    });

    test('PIN ochiq matnda saqlanmaydi', () {
      expect(Pin.hash('9999').contains('9999'), isFalse);
    });

    test('null yoki buzuq hash tasdiqlanmaydi', () {
      expect(Pin.verify('1234', null), isFalse);
      expect(Pin.verify('1234', 'buzuq'), isFalse);
    });
  });
}

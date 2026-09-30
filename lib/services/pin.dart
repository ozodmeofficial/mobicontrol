import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// PIN'ni ochiq holda saqlamaslik uchun tuzli (salted) SHA-256 hash.
///
/// Format: `salt:hexdigest`. Bu ilova ichidagi sozlamalarni himoyalash uchun
/// yetarli — telefon egasi PIN'ni unutsa, ilova ma'lumotlarini tozalab yoki
/// ilovani qayta o'rnatib tiklashi mumkin (bu ataylab shunday qoldirilgan).
class Pin {
  Pin._();

  static String hash(String pin) {
    final salt = _randomSalt();
    return '$salt:${_digest(pin, salt)}';
  }

  static bool verify(String pin, String? stored) {
    if (stored == null) return false;
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    return _digest(pin, parts[0]) == parts[1];
  }

  static String _digest(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt|$pin')).toString();

  static String _randomSalt() {
    final rnd = Random.secure();
    return base64Url.encode(List<int>.generate(12, (_) => rnd.nextInt(256)));
  }
}

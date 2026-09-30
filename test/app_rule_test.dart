import 'package:flutter_test/flutter_test.dart';
import 'package:mobicontrol/models/app_rule.dart';

void main() {
  // 2026-09-28 — Dushanba.
  DateTime at(int day, int hour, int minute) =>
      DateTime(2026, 9, 27 + day, hour, minute);

  group('TimeWindow', () {
    test('oddiy oraliq: boshi kiradi, oxiri kirmaydi', () {
      const w = TimeWindow(start: 9 * 60, end: 10 * 60);
      expect(w.contains(9 * 60 - 1), isFalse);
      expect(w.contains(9 * 60), isTrue);
      expect(w.contains(10 * 60 - 1), isTrue);
      expect(w.contains(10 * 60), isFalse);
    });

    test('yarim tundan o\'tuvchi oraliq', () {
      const w = TimeWindow(start: 22 * 60, end: 2 * 60);
      expect(w.contains(23 * 60), isTrue);
      expect(w.contains(0), isTrue);
      expect(w.contains(1 * 60 + 59), isTrue);
      expect(w.contains(2 * 60), isFalse);
      expect(w.contains(12 * 60), isFalse);
    });

    test('start == end butun kunni qamraydi', () {
      const w = TimeWindow(start: 0, end: 0);
      expect(w.contains(0), isTrue);
      expect(w.contains(1439), isTrue);
    });

    test('label formati', () {
      expect(const TimeWindow(start: 545, end: 1230).label, '09:05–20:30');
    });
  });

  group('AppRule', () {
    const rule = AppRule(
      packageName: 'com.instagram.android',
      appName: 'Instagram',
      days: {1, 2, 3, 4, 5}, // Du–Ju
      windows: [
        TimeWindow(start: 12 * 60, end: 13 * 60),
        TimeWindow(start: 20 * 60, end: 21 * 60),
      ],
    );

    test('ish kunida faqat oraliqlarda ruxsat', () {
      expect(rule.isAllowedAt(at(1, 12, 30)), isTrue);
      expect(rule.isAllowedAt(at(1, 20, 0)), isTrue);
      expect(rule.isAllowedAt(at(1, 15, 0)), isFalse);
      expect(rule.isAllowedAt(at(5, 21, 0)), isFalse);
    });

    test('cheklov kuni bo\'lmagan kunda doim ruxsat', () {
      expect(rule.isAllowedAt(at(6, 15, 0)), isTrue); // Shanba
      expect(rule.isAllowedAt(at(7, 3, 0)), isTrue); // Yakshanba
    });

    test('o\'chirilgan qoida hech narsani bloklamaydi', () {
      expect(rule.copyWith(enabled: false).isAllowedAt(at(1, 15, 0)), isTrue);
    });

    test('oraliqsiz qoida butunlay bloklaydi', () {
      final blocked = rule.copyWith(windows: []);
      expect(blocked.isAllowedAt(at(1, 12, 30)), isFalse);
      expect(blocked.scheduleLabel, 'Butunlay bloklangan');
    });

    test('JSON orqali to\'liq qayta tiklanadi', () {
      final decoded = AppRule.decodeList(AppRule.encodeList([rule])).single;
      expect(decoded.packageName, rule.packageName);
      expect(decoded.appName, rule.appName);
      expect(decoded.enabled, rule.enabled);
      expect(decoded.days, rule.days);
      expect(decoded.windows, rule.windows);
    });

    test('bo\'sh yoki null manba bo\'sh ro\'yxat beradi', () {
      expect(AppRule.decodeList(null), isEmpty);
      expect(AppRule.decodeList(''), isEmpty);
    });
  });
}

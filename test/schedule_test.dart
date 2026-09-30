import 'package:flutter_test/flutter_test.dart';
import 'package:mobicontrol/models/schedule.dart';

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

    test("yarim tundan o'tuvchi oraliq", () {
      const w = TimeWindow(start: 22 * 60, end: 2 * 60);
      expect(w.contains(23 * 60), isTrue);
      expect(w.contains(0), isTrue);
      expect(w.contains(2 * 60 - 1), isTrue);
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

  group('Schedule', () {
    const schedule = Schedule(
      days: {1, 2, 3, 4, 5}, // Du–Ju
      windows: [
        TimeWindow(start: 12 * 60, end: 13 * 60),
        TimeWindow(start: 20 * 60, end: 21 * 60),
      ],
    );

    test('cheklov kunida faqat oraliqlarda ruxsat', () {
      expect(schedule.isAllowedAt(at(1, 12, 30)), isTrue);
      expect(schedule.isAllowedAt(at(1, 20, 0)), isTrue);
      expect(schedule.isAllowedAt(at(1, 15, 0)), isFalse);
      expect(schedule.isAllowedAt(at(5, 21, 0)), isFalse);
    });

    test("cheklov kuni bo'lmagan kunda doim ruxsat", () {
      expect(schedule.isAllowedAt(at(6, 15, 0)), isTrue); // Shanba
      expect(schedule.isAllowedAt(at(7, 3, 0)), isTrue); // Yakshanba
    });

    test("o'chirilgan jadval hech narsani bloklamaydi", () {
      expect(
        schedule.copyWith(enabled: false).isAllowedAt(at(1, 15, 0)),
        isTrue,
      );
    });

    test('oraliqsiz jadval butunlay bloklaydi', () {
      final blocked = schedule.copyWith(windows: []);
      expect(blocked.isAllowedAt(at(1, 12, 30)), isFalse);
      expect(blocked.label, 'Butunlay bloklangan');
    });
  });

  group('Config', () {
    test("JSON orqali to'liq qayta tiklanadi", () {
      const config = Config(
        schedule: Schedule(
          enabled: false,
          days: {6, 7},
          windows: [TimeWindow(start: 60, end: 120)],
        ),
        apps: [
          RestrictedApp(
            packageName: 'com.instagram.android',
            appName: 'Instagram',
          ),
          RestrictedApp(
            packageName: 'org.telegram.messenger',
            appName: 'Telegram',
          ),
        ],
      );
      final decoded = Config.decode(config.encode());
      expect(decoded.schedule.enabled, isFalse);
      expect(decoded.schedule.days, {6, 7});
      expect(decoded.schedule.windows, config.schedule.windows);
      expect(decoded.apps.map((a) => a.packageName), [
        'com.instagram.android',
        'org.telegram.messenger',
      ]);
      expect(decoded.apps.first.appName, 'Instagram');
    });

    test("bo'sh manba boshlang'ich holatni beradi", () {
      for (final source in [null, '']) {
        final config = Config.decode(source);
        expect(config.apps, isEmpty);
        expect(config.schedule.windows, Schedule.initial.windows);
        expect(config.hasPin, isFalse);
        expect(config.cooldownMinutes, 0);
      }
    });

    test('PIN va sovish davri JSON orqali saqlanadi', () {
      const base = Config(apps: []);
      final withPin = base
          .withPinHash('salt:abc')
          .copyWith(cooldownMinutes: 30);
      final decoded = Config.decode(withPin.encode());
      expect(decoded.hasPin, isTrue);
      expect(decoded.pinHash, 'salt:abc');
      expect(decoded.cooldownMinutes, 30);
    });

    test('withPinHash(null) PIN ni olib tashlaydi', () {
      final c = const Config().withPinHash('salt:abc');
      expect(c.hasPin, isTrue);
      expect(c.withPinHash(null).hasPin, isFalse);
    });
  });
}

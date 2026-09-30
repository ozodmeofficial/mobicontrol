import 'dart:convert';

/// Kun ichidagi vaqt oralig'i, kun boshidan boshlab daqiqalarda.
///
/// [start] kiradi, [end] kirmaydi. Agar [start] > [end] bo'lsa, oraliq
/// yarim tundan o'tadi (masalan 22:00–02:00). [start] == [end] bo'lsa,
/// oraliq butun kunni qamraydi.
class TimeWindow {
  const TimeWindow({required this.start, required this.end})
    : assert(start >= 0 && start < 1440),
      assert(end >= 0 && end < 1440);

  final int start;
  final int end;

  bool contains(int minuteOfDay) {
    if (start == end) return true;
    if (start < end) return minuteOfDay >= start && minuteOfDay < end;
    return minuteOfDay >= start || minuteOfDay < end;
  }

  TimeWindow copyWith({int? start, int? end}) =>
      TimeWindow(start: start ?? this.start, end: end ?? this.end);

  static String formatMinutes(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get label => '${formatMinutes(start)}–${formatMinutes(end)}';

  Map<String, dynamic> toJson() => {'start': start, 'end': end};

  factory TimeWindow.fromJson(Map<String, dynamic> json) =>
      TimeWindow(start: json['start'] as int, end: json['end'] as int);

  @override
  bool operator ==(Object other) =>
      other is TimeWindow && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Barcha tanlangan ilovalar bo'ysunadigan umumiy jadval.
///
/// [days] ichidagi kunlarda ilovalar faqat [windows] oraliqlarida ishlaydi,
/// qolgan vaqtda bloklanadi. [windows] bo'sh bo'lsa, ilovalar o'sha kunlari
/// butunlay bloklanadi. [days] ga kirmagan kunlarda cheklov yo'q.
class Schedule {
  const Schedule({
    this.enabled = true,
    this.days = allDays,
    this.windows = const [],
  });

  /// Hafta kunlari [DateTime.weekday] bo'yicha: 1 = Dushanba ... 7 = Yakshanba.
  static const Set<int> allDays = {1, 2, 3, 4, 5, 6, 7};

  static const initial = Schedule(
    windows: [TimeWindow(start: 20 * 60, end: 21 * 60)],
  );

  final bool enabled;
  final Set<int> days;
  final List<TimeWindow> windows;

  bool isAllowedAt(DateTime time) {
    if (!enabled) return true;
    if (!days.contains(time.weekday)) return true;
    final minute = time.hour * 60 + time.minute;
    return windows.any((w) => w.contains(minute));
  }

  /// Foydalanuvchiga ko'rsatiladigan qisqa jadval tavsifi.
  String get label {
    if (windows.isEmpty) return 'Butunlay bloklangan';
    return windows.map((w) => w.label).join(', ');
  }

  Schedule copyWith({
    bool? enabled,
    Set<int>? days,
    List<TimeWindow>? windows,
  }) => Schedule(
    enabled: enabled ?? this.enabled,
    days: days ?? this.days,
    windows: windows ?? this.windows,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'days': (days.toList()..sort()),
    'windows': windows.map((w) => w.toJson()).toList(),
  };

  factory Schedule.fromJson(Map<String, dynamic> json) => Schedule(
    enabled: json['enabled'] as bool? ?? true,
    days: (json['days'] as List? ?? allDays.toList()).cast<int>().toSet(),
    windows: (json['windows'] as List? ?? const [])
        .map((w) => TimeWindow.fromJson((w as Map).cast<String, dynamic>()))
        .toList(),
  );
}

/// Jadvalga bo'ysunadigan ilova.
class RestrictedApp {
  const RestrictedApp({required this.packageName, required this.appName});

  final String packageName;
  final String appName;

  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'appName': appName,
  };

  factory RestrictedApp.fromJson(Map<String, dynamic> json) => RestrictedApp(
    packageName: json['packageName'] as String,
    appName: json['appName'] as String? ?? json['packageName'] as String,
  );
}

/// Saqlanadigan to'liq holat: umumiy jadval, unga bo'ysunadigan ilovalar,
/// ixtiyoriy PIN himoyasi va sovish davri.
///
/// [pinHash] — cheklovni o'zgartirish/o'chirish uchun so'raladigan PIN'ning
/// hashi (`null` bo'lsa PIN yo'q). [cooldownMinutes] — cheklovni o'chirish
/// yoki bo'shatishdan oldin kutish (impulsni jilovlash uchun).
///
/// Bu himoyalar faqat ilova ichidagi sozlamalarni «bir zumda» yumshatib
/// yuborishdan ushlab turadi. Telefon egasi ilovani baribir oddiy yo'l bilan
/// (Sozlamalar → Ilovalar → O'chirish) olib tashlay oladi — bu ataylab shunday.
class Config {
  const Config({
    this.schedule = Schedule.initial,
    this.apps = const [],
    this.pinHash,
    this.cooldownMinutes = 0,
  });

  final Schedule schedule;
  final List<RestrictedApp> apps;
  final String? pinHash;
  final int cooldownMinutes;

  bool get hasPin => pinHash != null;

  Config copyWith({
    Schedule? schedule,
    List<RestrictedApp>? apps,
    int? cooldownMinutes,
  }) => Config(
    schedule: schedule ?? this.schedule,
    apps: apps ?? this.apps,
    pinHash: pinHash,
    cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
  );

  /// PIN'ni o'rnatadi yoki (null bilan) olib tashlaydi.
  Config withPinHash(String? hash) => Config(
    schedule: schedule,
    apps: apps,
    pinHash: hash,
    cooldownMinutes: cooldownMinutes,
  );

  String encode() => jsonEncode({
    'schedule': schedule.toJson(),
    'apps': apps.map((a) => a.toJson()).toList(),
    if (pinHash != null) 'pinHash': pinHash,
    'cooldownMinutes': cooldownMinutes,
  });

  static Config decode(String? source) {
    if (source == null || source.isEmpty) return const Config();
    final json = (jsonDecode(source) as Map).cast<String, dynamic>();
    return Config(
      schedule: json['schedule'] == null
          ? Schedule.initial
          : Schedule.fromJson(
              (json['schedule'] as Map).cast<String, dynamic>(),
            ),
      apps: (json['apps'] as List? ?? const [])
          .map(
            (a) => RestrictedApp.fromJson((a as Map).cast<String, dynamic>()),
          )
          .toList(),
      pinHash: json['pinHash'] as String?,
      cooldownMinutes: json['cooldownMinutes'] as int? ?? 0,
    );
  }
}

const weekdayShortNames = {
  1: 'Du',
  2: 'Se',
  3: 'Ch',
  4: 'Pa',
  5: 'Ju',
  6: 'Sh',
  7: 'Ya',
};

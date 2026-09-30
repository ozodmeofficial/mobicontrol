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

/// Bitta ilova uchun cheklov qoidasi.
///
/// [days] ichidagi kunlarda ilova faqat [windows] oraliqlarida ishlaydi,
/// qolgan vaqtda bloklanadi. [windows] bo'sh bo'lsa, ilova o'sha kunlari
/// butunlay bloklanadi. [days] ga kirmagan kunlarda ilova cheklovsiz.
class AppRule {
  const AppRule({
    required this.packageName,
    required this.appName,
    this.enabled = true,
    this.days = allDays,
    this.windows = const [],
  });

  /// Hafta kunlari [DateTime.weekday] bo'yicha: 1 = Dushanba ... 7 = Yakshanba.
  static const Set<int> allDays = {1, 2, 3, 4, 5, 6, 7};

  final String packageName;
  final String appName;
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
  String get scheduleLabel {
    if (windows.isEmpty) return 'Butunlay bloklangan';
    return windows.map((w) => w.label).join(', ');
  }

  AppRule copyWith({
    bool? enabled,
    Set<int>? days,
    List<TimeWindow>? windows,
  }) => AppRule(
    packageName: packageName,
    appName: appName,
    enabled: enabled ?? this.enabled,
    days: days ?? this.days,
    windows: windows ?? this.windows,
  );

  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'appName': appName,
    'enabled': enabled,
    'days': (days.toList()..sort()),
    'windows': windows.map((w) => w.toJson()).toList(),
  };

  factory AppRule.fromJson(Map<String, dynamic> json) => AppRule(
    packageName: json['packageName'] as String,
    appName: json['appName'] as String,
    enabled: json['enabled'] as bool? ?? true,
    days: (json['days'] as List? ?? allDays.toList()).cast<int>().toSet(),
    windows: (json['windows'] as List? ?? const [])
        .map((w) => TimeWindow.fromJson((w as Map).cast<String, dynamic>()))
        .toList(),
  );

  static String encodeList(List<AppRule> rules) =>
      jsonEncode(rules.map((r) => r.toJson()).toList());

  static List<AppRule> decodeList(String? source) {
    if (source == null || source.isEmpty) return [];
    return (jsonDecode(source) as List)
        .map((r) => AppRule.fromJson((r as Map).cast<String, dynamic>()))
        .toList();
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

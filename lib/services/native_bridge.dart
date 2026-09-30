import 'package:flutter/services.dart';

import '../models/schedule.dart';

class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.appName,
    this.icon,
  });

  final String packageName;
  final String appName;
  final Uint8List? icon;
}

/// Android tomondagi kod bilan aloqa (MethodChannel).
///
/// Jadval va ilovalar ro'yxati Android SharedPreferences'da saqlanadi, chunki ularni
/// ilova yopiq bo'lganda ham ishlaydigan Accessibility Service o'qiydi.
class NativeBridge {
  NativeBridge._();

  static const _channel = MethodChannel('uz.mobicontrol/native');

  static Future<List<InstalledApp>> getInstalledApps() async {
    final raw = await _channel.invokeListMethod<Map>('getInstalledApps') ?? [];
    final apps =
        raw
            .map(
              (m) => InstalledApp(
                packageName: m['packageName'] as String,
                appName: m['appName'] as String,
                icon: m['icon'] as Uint8List?,
              ),
            )
            .toList()
          ..sort(
            (a, b) =>
                a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
          );
    return apps;
  }

  static Future<Uint8List?> getAppIcon(String packageName) =>
      _channel.invokeMethod<Uint8List>('getAppIcon', packageName);

  static Future<Config> loadConfig() async =>
      Config.decode(await _channel.invokeMethod<String>('loadConfig'));

  static Future<void> saveConfig(Config config) =>
      _channel.invokeMethod('saveConfig', config.encode());

  static Future<bool> isAccessibilityEnabled() async =>
      await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;

  static Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod('openAccessibilitySettings');
}

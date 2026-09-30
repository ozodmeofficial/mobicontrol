import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/schedule.dart';
import '../services/native_bridge.dart';
import 'app_picker_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Config _config = const Config();
  final Map<String, Uint8List?> _icons = {};
  bool _serviceEnabled = false;
  bool _loading = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // "Hozir: ruxsat / bloklangan" holati vaqt o'tishi bilan yangilanib tursin.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sozlamalardan qaytganda xizmat holatini qayta tekshiramiz.
    if (state == AppLifecycleState.resumed) _checkService();
  }

  Future<void> _load() async {
    final config = await NativeBridge.loadConfig();
    await _checkService();
    if (!mounted) return;
    setState(() {
      _config = config;
      _loading = false;
    });
    for (final app in config.apps) {
      _loadIcon(app.packageName);
    }
  }

  Future<void> _loadIcon(String packageName) async {
    if (_icons.containsKey(packageName)) return;
    _icons[packageName] = null;
    final icon = await NativeBridge.getAppIcon(packageName);
    if (mounted) setState(() => _icons[packageName] = icon);
  }

  Future<void> _checkService() async {
    final enabled = await NativeBridge.isAccessibilityEnabled();
    if (mounted && enabled != _serviceEnabled) {
      setState(() => _serviceEnabled = enabled);
    }
  }

  Future<void> _update(Config config) async {
    setState(() => _config = config);
    await NativeBridge.saveConfig(config);
  }

  void _updateSchedule(Schedule schedule) =>
      _update(_config.copyWith(schedule: schedule));

  Future<void> _pickApps() async {
    final picked = await Navigator.of(context).push<List<InstalledApp>>(
      MaterialPageRoute(
        builder: (_) => AppPickerScreen(
          selectedPackages: _config.apps.map((a) => a.packageName).toSet(),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    for (final app in picked) {
      _icons[app.packageName] ??= app.icon;
    }
    await _update(
      _config.copyWith(
        apps: [
          for (final app in picked)
            RestrictedApp(packageName: app.packageName, appName: app.appName),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('MobiControl')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _ServiceStatusCard(
                  enabled: _serviceEnabled,
                  onEnable: NativeBridge.openAccessibilitySettings,
                ),
                const SizedBox(height: 16),
                ScheduleCard(
                  schedule: _config.schedule,
                  onChanged: _updateSchedule,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cheklangan ilovalar (${_config.apps.length})',
                        style: textTheme.titleMedium,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _pickApps,
                      icon: const Icon(Icons.checklist),
                      label: const Text('Tanlash'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_config.apps.isEmpty)
                  const _EmptyState()
                else
                  Card(
                    child: Column(
                      children: [
                        for (final app in _config.apps)
                          ListTile(
                            leading: AppIcon(bytes: _icons[app.packageName]),
                            title: Text(app.appName),
                            trailing: IconButton(
                              tooltip: "Ro'yxatdan olib tashlash",
                              icon: const Icon(Icons.close),
                              onPressed: () => _update(
                                _config.copyWith(
                                  apps: [
                                    for (final a in _config.apps)
                                      if (a.packageName != app.packageName) a,
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Umumiy jadval: ruxsat berilgan vaqt oraliqlari va cheklov kunlari.
class ScheduleCard extends StatelessWidget {
  const ScheduleCard({
    super.key,
    required this.schedule,
    required this.onChanged,
  });

  final Schedule schedule;
  final ValueChanged<Schedule> onChanged;

  Future<int?> _pickTime(
    BuildContext context,
    int initialMinutes,
    String helpText,
  ) async {
    final picked = await showTimePicker(
      context: context,
      helpText: helpText,
      initialTime: TimeOfDay(
        hour: initialMinutes ~/ 60,
        minute: initialMinutes % 60,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }

  void _setWindow(int index, TimeWindow window) => onChanged(
    schedule.copyWith(windows: [...schedule.windows]..[index] = window),
  );

  Future<void> _addWindow(BuildContext context) async {
    final start = await _pickTime(context, 12 * 60, 'Boshlanish vaqti');
    if (start == null || !context.mounted) return;
    final end = await _pickTime(context, (start + 60) % 1440, 'Tugash vaqti');
    if (end == null) return;
    onChanged(
      schedule.copyWith(
        windows: [...schedule.windows, TimeWindow(start: start, end: end)]
          ..sort((a, b) => a.start.compareTo(b.start)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final allowed = schedule.isAllowedAt(DateTime.now());
    final windows = schedule.windows;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Umumiy jadval', style: textTheme.titleLarge),
                ),
                Switch(
                  value: schedule.enabled,
                  onChanged: (v) => onChanged(schedule.copyWith(enabled: v)),
                ),
              ],
            ),
            Text(
              !schedule.enabled
                  ? "Cheklov o'chirilgan"
                  : allowed
                  ? 'Hozir: ilovalar ochiq'
                  : 'Hozir: ilovalar bloklangan',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: !schedule.enabled
                    ? scheme.outline
                    : allowed
                    ? Colors.green.shade600
                    : scheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Text('Ruxsat berilgan vaqt', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Tanlangan barcha ilovalar faqat shu vaqtda ochiladi, qolgan '
              "vaqtda bloklanadi. Oraliq qo'shilmasa, ilovalar butunlay "
              'bloklanadi.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < windows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _TimeButton(
                        caption: 'Dan',
                        minutes: windows[i].start,
                        onTap: () async {
                          final start = await _pickTime(
                            context,
                            windows[i].start,
                            'Boshlanish vaqti',
                          );
                          if (start != null) {
                            _setWindow(i, windows[i].copyWith(start: start));
                          }
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward),
                    ),
                    Expanded(
                      child: _TimeButton(
                        caption: windows[i].start > windows[i].end
                            ? 'Gacha (ertasi kun)'
                            : 'Gacha',
                        minutes: windows[i].end,
                        onTap: () async {
                          final end = await _pickTime(
                            context,
                            windows[i].end,
                            'Tugash vaqti',
                          );
                          if (end != null) {
                            _setWindow(i, windows[i].copyWith(end: end));
                          }
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: "Oraliqni o'chirish",
                      icon: const Icon(Icons.close),
                      onPressed: () => onChanged(
                        schedule.copyWith(windows: [...windows]..removeAt(i)),
                      ),
                    ),
                  ],
                ),
              ),
            if (windows.any((w) => w.start == w.end))
              Text(
                "Boshlanish va tugash vaqti bir xil bo'lsa, ilovalar butun kun "
                "ochiq bo'ladi.",
                style: textTheme.bodySmall,
              ),
            TextButton.icon(
              onPressed: () => _addWindow(context),
              icon: const Icon(Icons.add),
              label: const Text("Vaqt oralig'i qo'shish"),
            ),
            const Divider(height: 24),
            Text('Cheklov kunlari', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Tanlanmagan kunlarda ilovalar cheklovsiz ishlaydi.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in weekdayShortNames.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: schedule.days.contains(entry.key),
                    onSelected: (selected) => onChanged(
                      schedule.copyWith(
                        days: selected
                            ? {...schedule.days, entry.key}
                            : ({...schedule.days}..remove(entry.key)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.caption,
    required this.minutes,
    required this.onTap,
  });

  final String caption;
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Column(
        children: [
          Text(caption, style: textTheme.labelSmall),
          Text(
            TimeWindow.formatMinutes(minutes),
            style: textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}

class _ServiceStatusCard extends StatelessWidget {
  const _ServiceStatusCard({required this.enabled, required this.onEnable});

  final bool enabled;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: enabled ? scheme.primaryContainer : scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(enabled ? Icons.shield : Icons.shield_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    enabled ? 'Himoya yoqilgan' : "Himoya o'chirilgan",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (!enabled) ...[
              const SizedBox(height: 8),
              const Text(
                'Ilovalarni bloklash uchun Maxsus imkoniyatlar (Accessibility) '
                'sozlamalarida MobiControl xizmatini yoqing.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onEnable,
                icon: const Icon(Icons.settings),
                label: const Text('Sozlamalarni ochish'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Text(
        "Hali ilova tanlanmagan.\n\"Tanlash\" tugmasini bosib, jadvalga "
        "bo'ysunadigan ilovalarni belgilang.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}

class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.bytes, this.size = 40});

  final Uint8List? bytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (bytes == null) return Icon(Icons.android, size: size);
    return Image.memory(
      bytes!,
      width: size,
      height: size,
      gaplessPlayback: true,
    );
  }
}

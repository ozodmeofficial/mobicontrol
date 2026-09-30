import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/schedule.dart';
import '../services/native_bridge.dart';
import 'app_picker_screen.dart';
import 'pin_flow.dart';

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
  // PIN o'rnatilgan bo'lsa, sozlamalar shu sessiyada bir marta ochilgach
  // tahrirlanadi. Ilovadan chiqib qayta kirilsa yana qulflanadi.
  bool _unlocked = false;
  Timer? _ticker;

  bool get _editable => !_config.hasPin || _unlocked;

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
      _unlocked = !config.hasPin;
      _loading = false;
    });
    for (final app in config.apps) {
      _loadIcon(app.packageName);
    }
  }

  /// Tahrirlashdan oldin PIN qulfini ochadi. Ochilsa (yoki PIN yo'q bo'lsa)
  /// `true`.
  Future<bool> _ensureUnlocked() async {
    if (_editable) return true;
    final ok = await PinFlow.unlock(context, _config);
    if (ok && mounted) setState(() => _unlocked = true);
    return ok;
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

  /// Jadval o'zgarganda. Cheklovni o'chirish (enabled: true → false) sovish
  /// davri bilan himoyalangan.
  Future<void> _updateSchedule(Schedule schedule) async {
    final turningOff = _config.schedule.enabled && !schedule.enabled;
    if (turningOff && _config.cooldownMinutes > 0) {
      final confirmed = await PinFlow.waitCooldown(
        context,
        minutes: _config.cooldownMinutes,
        title: "Cheklovni o'chirish",
        message:
            "Cheklovni o'chirish uchun ${_config.cooldownMinutes} daqiqa "
            'kutish kerak. Shu vaqt tugagach tasdiqlaysiz.',
      );
      if (!confirmed) return;
    }
    await _update(_config.copyWith(schedule: schedule));
  }

  Future<void> _pickApps() async {
    if (!await _ensureUnlocked()) return;
    if (!mounted) return;
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

  Future<void> _setOrChangePin() async {
    if (!await _ensureUnlocked()) return;
    if (!mounted) return;
    final hash = await PinFlow.setNewPin(context);
    if (hash == null) return;
    await _update(_config.withPinHash(hash));
    if (mounted) {
      setState(() => _unlocked = true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("PIN o'rnatildi")));
    }
  }

  Future<void> _removePin() async {
    if (!await _ensureUnlocked()) return;
    if (!mounted) return;
    await _update(_config.withPinHash(null));
    if (mounted) setState(() => _unlocked = true);
  }

  Future<void> _setCooldown() async {
    if (!await _ensureUnlocked()) return;
    if (!mounted) return;
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Sovish davri'),
        children: [
          for (final m in const [0, 5, 15, 30, 60, 180])
            ListTile(
              leading: Icon(
                m == _config.cooldownMinutes
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(m == 0 ? "O'chirilgan" : '$m daqiqa'),
              onTap: () => Navigator.pop(context, m),
            ),
        ],
      ),
    );
    if (minutes != null) {
      await _update(_config.copyWith(cooldownMinutes: minutes));
    }
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
                if (_config.hasPin && !_unlocked) ...[
                  _LockBanner(onUnlock: _ensureUnlocked),
                  const SizedBox(height: 16),
                ],
                ScheduleCard(
                  schedule: _config.schedule,
                  onChanged: _updateSchedule,
                  enabled: _editable,
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
                              onPressed: () async {
                                if (!await _ensureUnlocked()) return;
                                await _update(
                                  _config.copyWith(
                                    apps: [
                                      for (final a in _config.apps)
                                        if (a.packageName != app.packageName) a,
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                _ProtectionCard(
                  config: _config,
                  onSetPin: _setOrChangePin,
                  onRemovePin: _removePin,
                  onSetCooldown: _setCooldown,
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
    this.enabled = true,
  });

  final Schedule schedule;
  final ValueChanged<Schedule> onChanged;

  /// `false` bo'lsa (PIN qulfi ochilmagan) barcha boshqaruvlar o'chiriladi.
  final bool enabled;

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
                  onChanged: enabled
                      ? (v) => onChanged(schedule.copyWith(enabled: v))
                      : null,
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
                        onTap: !enabled
                            ? null
                            : () async {
                                final start = await _pickTime(
                                  context,
                                  windows[i].start,
                                  'Boshlanish vaqti',
                                );
                                if (start != null) {
                                  _setWindow(
                                    i,
                                    windows[i].copyWith(start: start),
                                  );
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
                        onTap: !enabled
                            ? null
                            : () async {
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
                      onPressed: !enabled
                          ? null
                          : () => onChanged(
                              schedule.copyWith(
                                windows: [...windows]..removeAt(i),
                              ),
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
              onPressed: enabled ? () => _addWindow(context) : null,
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
                    onSelected: !enabled
                        ? null
                        : (selected) => onChanged(
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
  final VoidCallback? onTap;

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

class _LockBanner extends StatelessWidget {
  const _LockBanner({required this.onUnlock});

  final Future<bool> Function() onUnlock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.lock_outline),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Sozlamalar PIN bilan himoyalangan. O‘zgartirish uchun '
                'qulfni oching.',
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => onUnlock(),
              child: const Text('Qulfni ochish'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Himoya sozlamalari: PIN va sovish davri.
class _ProtectionCard extends StatelessWidget {
  const _ProtectionCard({
    required this.config,
    required this.onSetPin,
    required this.onRemovePin,
    required this.onSetCooldown,
  });

  final Config config;
  final VoidCallback onSetPin;
  final VoidCallback onRemovePin;
  final VoidCallback onSetCooldown;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Himoya', style: textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Bu sozlamalar cheklovni bir zumda yumshatib yuborishdan '
              'ushlab turadi. Telefon egasi ilovani baribir oddiy yo‘l bilan '
              'o‘chira oladi.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.password),
              title: Text(config.hasPin ? 'PIN o‘rnatilgan' : 'PIN yo‘q'),
              subtitle: const Text(
                'Sozlamalarni o‘zgartirish uchun PIN so‘raladi',
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: onSetPin,
                    child: Text(config.hasPin ? 'O‘zgartirish' : 'O‘rnatish'),
                  ),
                  if (config.hasPin)
                    TextButton(
                      onPressed: onRemovePin,
                      child: const Text('O‘chirish'),
                    ),
                ],
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.hourglass_bottom),
              title: const Text('Sovish davri'),
              subtitle: Text(
                config.cooldownMinutes == 0
                    ? 'O‘chirilgan'
                    : 'Cheklovni o‘chirishdan oldin '
                          '${config.cooldownMinutes} daqiqa kutiladi',
              ),
              trailing: TextButton(
                onPressed: onSetCooldown,
                child: const Text('O‘zgartirish'),
              ),
            ),
          ],
        ),
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

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/app_rule.dart';
import '../services/native_bridge.dart';
import 'app_picker_screen.dart';
import 'rule_editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<AppRule> _rules = [];
  final Map<String, Uint8List?> _icons = {};
  bool _serviceEnabled = false;
  bool _loading = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // Holatlar ("Ruxsat" / "Bloklangan") vaqt o'tishi bilan yangilanib tursin.
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
    final rules = await NativeBridge.loadRules();
    await _checkService();
    if (!mounted) return;
    setState(() {
      _rules = rules;
      _loading = false;
    });
    for (final r in rules) {
      _loadIcon(r.packageName);
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

  Future<void> _saveRules(List<AppRule> rules) async {
    setState(() => _rules = rules);
    await NativeBridge.saveRules(rules);
  }

  Future<void> _addApp() async {
    final app = await Navigator.of(context).push<InstalledApp>(
      MaterialPageRoute(
        builder: (_) => AppPickerScreen(
          excludedPackages: _rules.map((r) => r.packageName).toSet(),
        ),
      ),
    );
    if (app == null || !mounted) return;
    _icons[app.packageName] = app.icon;
    final initial = AppRule(
      packageName: app.packageName,
      appName: app.appName,
      windows: const [TimeWindow(start: 18 * 60, end: 19 * 60)],
    );
    await _editRule(initial, isNew: true);
  }

  Future<void> _editRule(AppRule rule, {bool isNew = false}) async {
    final result = await Navigator.of(context).push<RuleEditorResult>(
      MaterialPageRoute(
        builder: (_) => RuleEditorScreen(
          rule: rule,
          icon: _icons[rule.packageName],
          isNew: isNew,
        ),
      ),
    );
    if (result == null) return;
    final rules = [..._rules];
    final index = rules.indexWhere((r) => r.packageName == rule.packageName);
    if (result.deleted) {
      if (index >= 0) rules.removeAt(index);
    } else if (index >= 0) {
      rules[index] = result.rule!;
    } else {
      rules.add(result.rule!);
    }
    await _saveRules(rules);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MobiControl')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addApp,
        icon: const Icon(Icons.add),
        label: const Text("Ilova qo'shish"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                _ServiceStatusCard(
                  enabled: _serviceEnabled,
                  onEnable: NativeBridge.openAccessibilitySettings,
                ),
                const SizedBox(height: 16),
                if (_rules.isEmpty)
                  const _EmptyState()
                else
                  for (final rule in _rules)
                    _RuleTile(
                      rule: rule,
                      icon: _icons[rule.packageName],
                      onTap: () => _editRule(rule),
                      onToggle: (value) => _saveRules([
                        for (final r in _rules)
                          r.packageName == rule.packageName
                              ? r.copyWith(enabled: value)
                              : r,
                      ]),
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
            const SizedBox(height: 8),
            Text(
              enabled
                  ? "Cheklangan ilovalar belgilangan vaqtdan tashqari ochilmaydi."
                  : "Ilovalarni bloklash uchun Maxsus imkoniyatlar (Accessibility) "
                        "sozlamalarida MobiControl xizmatini yoqing.",
            ),
            if (!enabled) ...[
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

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.icon,
    required this.onTap,
    required this.onToggle,
  });

  final AppRule rule;
  final Uint8List? icon;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final allowed = rule.isAllowedAt(DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    final days = rule.days.length == 7
        ? 'Har kuni'
        : (rule.days.toList()..sort())
              .map((d) => weekdayShortNames[d])
              .join(', ');
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: AppIcon(bytes: icon),
        title: Text(rule.appName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${rule.scheduleLabel} · $days'),
            const SizedBox(height: 4),
            Text(
              !rule.enabled
                  ? "Cheklov o'chirilgan"
                  : allowed
                  ? 'Hozir: ruxsat berilgan'
                  : 'Hozir: bloklangan',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: !rule.enabled
                    ? scheme.outline
                    : allowed
                    ? Colors.green.shade600
                    : scheme.error,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Switch(value: rule.enabled, onChanged: onToggle),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.timer_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          const Text(
            "Hali cheklangan ilova yo'q.\n"
            "\"Ilova qo'shish\" tugmasini bosib, ilovani va unga ruxsat "
            "berilgan vaqtni tanlang.",
            textAlign: TextAlign.center,
          ),
        ],
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

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/app_rule.dart';
import 'home_screen.dart';

class RuleEditorResult {
  const RuleEditorResult.saved(AppRule this.rule) : deleted = false;
  const RuleEditorResult.deleted() : rule = null, deleted = true;

  final AppRule? rule;
  final bool deleted;
}

class RuleEditorScreen extends StatefulWidget {
  const RuleEditorScreen({
    super.key,
    required this.rule,
    required this.icon,
    this.isNew = false,
  });

  final AppRule rule;
  final Uint8List? icon;
  final bool isNew;

  @override
  State<RuleEditorScreen> createState() => _RuleEditorScreenState();
}

class _RuleEditorScreenState extends State<RuleEditorScreen> {
  late bool _enabled = widget.rule.enabled;
  late Set<int> _days = {...widget.rule.days};
  late List<TimeWindow> _windows = [...widget.rule.windows];

  Future<int?> _pickTime(int initialMinutes, String helpText) async {
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

  Future<void> _editStart(int index) async {
    final w = _windows[index];
    final start = await _pickTime(w.start, 'Boshlanish vaqti');
    if (start == null) return;
    setState(() => _windows[index] = w.copyWith(start: start));
  }

  Future<void> _editEnd(int index) async {
    final w = _windows[index];
    final end = await _pickTime(w.end, 'Tugash vaqti');
    if (end == null) return;
    setState(() => _windows[index] = w.copyWith(end: end));
  }

  Future<void> _addWindow() async {
    final start = await _pickTime(12 * 60, 'Boshlanish vaqti');
    if (start == null || !mounted) return;
    final end = await _pickTime((start + 60) % 1440, 'Tugash vaqti');
    if (end == null) return;
    setState(
      () =>
          _windows = [..._windows, TimeWindow(start: start, end: end)]
            ..sort((a, b) => a.start.compareTo(b.start)),
    );
  }

  void _save() {
    if (_days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kamida bitta kunni tanlang')),
      );
      return;
    }
    Navigator.of(context).pop(
      RuleEditorResult.saved(
        widget.rule.copyWith(enabled: _enabled, days: _days, windows: _windows),
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cheklovni o'chirish"),
        content: Text("${widget.rule.appName} uchun cheklov o'chirilsinmi?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("O'chirish"),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(const RuleEditorResult.deleted());
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Yangi cheklov' : 'Cheklovni tahrirlash'),
        actions: [
          if (!widget.isNew)
            IconButton(
              tooltip: "O'chirish",
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Saqlash'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              AppIcon(bytes: widget.icon, size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.rule.appName, style: textTheme.titleLarge),
                    Text(widget.rule.packageName, style: textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cheklov yoqilgan'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const Divider(),
          Text('Ruxsat berilgan vaqtlar', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            "Ilova faqat shu oraliqlarda ochiladi. Qolgan vaqtda u bloklanadi. "
            "Oraliq qo'shilmasa, ilova tanlangan kunlarda butunlay bloklanadi.",
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _windows.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _TimeButton(
                        caption: 'Dan',
                        minutes: _windows[i].start,
                        onTap: () => _editStart(i),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward),
                    ),
                    Expanded(
                      child: _TimeButton(
                        caption: _windows[i].start > _windows[i].end
                            ? 'Gacha (ertasi kun)'
                            : 'Gacha',
                        minutes: _windows[i].end,
                        onTap: () => _editEnd(i),
                      ),
                    ),
                    IconButton(
                      tooltip: "Oraliqni o'chirish",
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          setState(() => _windows = [..._windows]..removeAt(i)),
                    ),
                  ],
                ),
              ),
            ),
          if (_windows.any((w) => w.start == w.end))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "Boshlanish va tugash vaqti bir xil bo'lsa, ilova butun kun ochiq bo'ladi.",
                style: textTheme.bodySmall,
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addWindow,
              icon: const Icon(Icons.add),
              label: const Text("Vaqt oralig'i qo'shish"),
            ),
          ),
          const Divider(),
          Text('Cheklov kunlari', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Tanlanmagan kunlarda ilova cheklovsiz ishlaydi.',
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
                  selected: _days.contains(entry.key),
                  onSelected: (selected) => setState(() {
                    _days = {..._days};
                    selected ? _days.add(entry.key) : _days.remove(entry.key);
                  }),
                ),
            ],
          ),
        ],
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

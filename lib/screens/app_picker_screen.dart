import 'package:flutter/material.dart';

import '../services/native_bridge.dart';
import 'home_screen.dart';

/// Umumiy jadvalga bo'ysunadigan ilovalarni belgilash ekrani.
class AppPickerScreen extends StatefulWidget {
  const AppPickerScreen({super.key, required this.selectedPackages});

  final Set<String> selectedPackages;

  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> {
  late final Future<List<InstalledApp>> _apps = NativeBridge.getInstalledApps();
  late final Set<String> _selected = {...widget.selectedPackages};
  String _query = '';

  List<InstalledApp> _filter(List<InstalledApp> apps) => apps
      .where(
        (a) =>
            _query.isEmpty ||
            a.appName.toLowerCase().contains(_query) ||
            a.packageName.toLowerCase().contains(_query),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<InstalledApp>>(
      future: _apps,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <InstalledApp>[];
        final visible = _filter(all);
        final allVisibleSelected =
            visible.isNotEmpty &&
            visible.every((a) => _selected.contains(a.packageName));
        return Scaffold(
          appBar: AppBar(
            title: Text('Tanlangan: ${_selected.length}'),
            actions: [
              TextButton(
                onPressed: visible.isEmpty
                    ? null
                    : () => setState(() {
                        final packages = visible.map((a) => a.packageName);
                        allVisibleSelected
                            ? _selected.removeAll(packages)
                            : _selected.addAll(packages);
                      }),
                child: Text(
                  allVisibleSelected ? 'Hech birini' : 'Hammasini tanlash',
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Qidirish...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: snapshot.hasData
                    ? () => Navigator.of(context).pop(
                        all
                            .where((a) => _selected.contains(a.packageName))
                            .toList(),
                      )
                    : null,
                icon: const Icon(Icons.check),
                label: const Text('Saqlash'),
              ),
            ),
          ),
          body: switch (snapshot) {
            AsyncSnapshot(hasError: true) => Center(
              child: Text('Xatolik: ${snapshot.error}'),
            ),
            AsyncSnapshot(hasData: false) => const Center(
              child: CircularProgressIndicator(),
            ),
            _ when visible.isEmpty => const Center(
              child: Text('Ilova topilmadi'),
            ),
            _ => ListView.builder(
              itemCount: visible.length,
              itemBuilder: (context, i) {
                final app = visible[i];
                return CheckboxListTile(
                  secondary: AppIcon(bytes: app.icon),
                  title: Text(app.appName),
                  subtitle: Text(
                    app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  value: _selected.contains(app.packageName),
                  onChanged: (v) => setState(
                    () => v == true
                        ? _selected.add(app.packageName)
                        : _selected.remove(app.packageName),
                  ),
                );
              },
            ),
          },
        );
      },
    );
  }
}

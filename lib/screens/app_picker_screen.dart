import 'package:flutter/material.dart';

import '../services/native_bridge.dart';
import 'home_screen.dart';

class AppPickerScreen extends StatefulWidget {
  const AppPickerScreen({super.key, required this.excludedPackages});

  final Set<String> excludedPackages;

  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> {
  late final Future<List<InstalledApp>> _apps = NativeBridge.getInstalledApps();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ilovani tanlang'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: false,
              decoration: const InputDecoration(
                hintText: 'Qidirish...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<InstalledApp>>(
        future: _apps,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Xatolik: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final apps = snapshot.data!
              .where((a) => !widget.excludedPackages.contains(a.packageName))
              .where(
                (a) =>
                    _query.isEmpty ||
                    a.appName.toLowerCase().contains(_query) ||
                    a.packageName.toLowerCase().contains(_query),
              )
              .toList();
          if (apps.isEmpty) {
            return const Center(child: Text('Ilova topilmadi'));
          }
          return ListView.builder(
            itemCount: apps.length,
            itemBuilder: (context, i) {
              final app = apps[i];
              return ListTile(
                leading: AppIcon(bytes: app.icon),
                title: Text(app.appName),
                subtitle: Text(
                  app.packageName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(context).pop(app),
              );
            },
          );
        },
      ),
    );
  }
}

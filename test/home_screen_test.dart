import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobicontrol/main.dart';
import 'package:mobicontrol/models/schedule.dart';

void main() {
  const channel = MethodChannel('uz.mobicontrol/native');
  String? saved;

  setUp(() {
    saved = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'loadConfig':
              return const Config(
                apps: [
                  RestrictedApp(
                    packageName: 'com.instagram.android',
                    appName: 'Instagram',
                  ),
                ],
              ).encode();
            case 'saveConfig':
              saved = call.arguments as String;
              return null;
            case 'isAccessibilityEnabled':
              return true;
            default:
              return null;
          }
        });
  });

  testWidgets('umumiy jadval va ilovalar ko\'rsatiladi', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MobiControlApp());
    await tester.pumpAndSettle();

    expect(find.text('Umumiy jadval'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('21:00'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('Cheklangan ilovalar (1)'), findsOneWidget);
  });

  testWidgets("ilovani ro'yxatdan olib tashlash saqlanadi", (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MobiControlApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip("Ro'yxatdan olib tashlash"));
    await tester.pumpAndSettle();

    expect(find.text('Instagram'), findsNothing);
    expect(Config.decode(saved).apps, isEmpty);
    expect(Config.decode(saved).schedule.windows, Schedule.initial.windows);
  });
}

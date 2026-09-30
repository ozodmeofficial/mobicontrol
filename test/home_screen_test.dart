import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobicontrol/main.dart';
import 'package:mobicontrol/models/schedule.dart';
import 'package:mobicontrol/services/pin.dart';

void main() {
  const channel = MethodChannel('uz.mobicontrol/native');
  String? saved;
  late Config initial;

  void mock() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'loadConfig':
              return initial.encode();
            case 'saveConfig':
              saved = call.arguments as String;
              return null;
            case 'isAccessibilityEnabled':
              return true;
            default:
              return null;
          }
        });
  }

  setUp(() {
    saved = null;
    initial = const Config(
      apps: [
        RestrictedApp(
          packageName: 'com.instagram.android',
          appName: 'Instagram',
        ),
      ],
    );
    mock();
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

  testWidgets('PIN o‘rnatilgan bo‘lsa sozlamalar qulflanadi', (tester) async {
    initial = initial.withPinHash(Pin.hash('1234'));
    mock();
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MobiControlApp());
    await tester.pumpAndSettle();

    // Qulf banneri ko'rinadi, jadval kaliti o'chirilgan (onChanged == null).
    expect(find.text('Qulfni ochish'), findsOneWidget);
    final sw = tester.widget<Switch>(find.byType(Switch).first);
    expect(sw.onChanged, isNull);

    // Qulfni ochish → PIN so'raladi → to'g'ri PIN → kalit faollashadi.
    await tester.tap(find.text('Qulfni ochish'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Qulfni ochish'), findsNothing);
    final sw2 = tester.widget<Switch>(find.byType(Switch).first);
    expect(sw2.onChanged, isNotNull);
  });
}

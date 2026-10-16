import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xeta_notifications_organizer/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('xeta_notifications');
  var readManyCalls = 0;
  String? deleteType;
  List<String> deleteValues = [];
  String? openedNotificationId;
  var hasPrivacyConsent = true;
  var onboardingComplete = true;
  var darkThemeEnabled = true;
  List<Map<String, Object?>> storedNotifications = [];
  setUp(() {
    readManyCalls = 0;
    deleteType = null;
    deleteValues = [];
    openedNotificationId = null;
    hasPrivacyConsent = true;
    onboardingComplete = true;
    darkThemeEnabled = true;
    storedNotifications = [
      {
        'id': 'n-1',
        'appName': 'Sample app',
        'packageName': 'example.sample',
        'title': 'Sample title',
        'body': 'Sample body',
        'date': '2026-10-03',
        'time': 1791028800000,
        'read': false,
      },
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'notifications') {
            return storedNotifications;
          }
          if (call.method == 'listenerEnabled') return false;
          if (call.method == 'onboarded') return onboardingComplete;
          if (call.method == 'setOnboarded') {
            onboardingComplete = call.arguments['value'] as bool;
            return true;
          }
          if (call.method == 'darkMode') return darkThemeEnabled;
          if (call.method == 'setDarkMode') {
            darkThemeEnabled = call.arguments['value'] as bool;
            return true;
          }
          if (call.method == 'openNotification') {
            openedNotificationId = call.arguments['id'] as String;
            return true;
          }
          if (call.method == 'privacyConsent') return hasPrivacyConsent;
          if (call.method == 'setPrivacyConsent') {
            hasPrivacyConsent = call.arguments['value'] as bool;
            return true;
          }
          if (call.method == 'installedApps') {
            return [
              {
                'packageName': 'example.alpha',
                'appName': 'Alpha app',
                'iconPath': '',
              },
              {
                'packageName': 'example.beta',
                'appName': 'Beta app',
                'iconPath': '',
              },
              {
                'packageName': 'example.gamma',
                'appName': 'Gamma app',
                'iconPath': '',
              },
            ];
          }
          if (call.method == 'importantApps') return ['example.beta'];
          if (call.method == 'repetitiveApps') return ['example.gamma'];
          if (call.method == 'silenceNonImportant') return true;
          if (call.method == 'appNotificationsEnabled') return false;
          if (call.method == 'restrictedDone') return false;
          if (call.method == 'setImportantApps' ||
              call.method == 'setRepetitiveApps' ||
              call.method == 'setSilenceNonImportant' ||
              call.method == 'setViewMode') {
            return true;
          }
          if (call.method == 'viewMode') return 'all';
          if (call.method == 'setReadMany') {
            readManyCalls++;
            final arguments = Map<String, Object?>.from(call.arguments as Map);
            final ids = List<String>.from(arguments['ids'] as List);
            for (final item in storedNotifications) {
              if (ids.contains(item['id'])) item['read'] = arguments['value'];
            }
            return true;
          }
          if (call.method == 'deleteGroups') {
            final arguments = Map<String, Object?>.from(call.arguments as Map);
            deleteType = arguments['type'] as String;
            deleteValues = List<String>.from(arguments['values'] as List);
            return 1;
          }
          return null;
        });
  });

  testWidgets('shows organizer shell', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month), findsOneWidget);
  });

  testWidgets('starts in dark theme by default', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  testWidgets('can change theme during onboarding', (tester) async {
    onboardingComplete = false;
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.text('Fast triage'), findsOneWidget);
    await tester.tap(find.byTooltip('Switch to light theme'));
    await tester.pumpAndSettle();
    expect(darkThemeEnabled, isFalse);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );

    await tester.tap(find.byTooltip('Switch to dark theme'));
    await tester.pumpAndSettle();
    expect(darkThemeEnabled, isTrue);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  testWidgets('details show notification text and open its action', (
    tester,
  ) async {
    storedNotifications.single['actionKind'] = 'pendingIntent';
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('Sample app  ·  Sample body'), findsOneWidget);
    expect(find.text('pendingIntent'), findsNothing);

    await tester.tap(find.text('Sample title'));
    await tester.pumpAndSettle();
    expect(find.text('Open Action'), findsOneWidget);
    await tester.tap(find.text('Open action'));
    await tester.pumpAndSettle();
    expect(openedNotificationId, 'n-1');
    expect(find.text('Close'), findsNothing);
  });

  testWidgets('selects notifications by app before deleting', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.checklist));
    await tester.pumpAndSettle();
    expect(find.text('2026-10-03'), findsOneWidget);

    await tester.tap(find.text('App'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sample app'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete selected (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(deleteType, 'app');
    expect(deleteValues, ['example.sample']);
  });

  testWidgets('swiping a day to read requires checkbox confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.text('Mark this day as read'), findsNothing);
    await tester.drag(find.text('2026-10-03'), const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(
      find.text('I reviewed the day and want to mark all as read'),
      findsOneWidget,
    );
    expect(readManyCalls, 0);

    await tester.tap(
      find.text('I reviewed the day and want to mark all as read'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, mark read'));
    await tester.pumpAndSettle();
    expect(readManyCalls, 1);
  });

  testWidgets('reading one notification keeps its date expanded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    storedNotifications = [
      {
        'id': 'latest',
        'appName': 'Latest app',
        'packageName': 'example.latest',
        'title': 'Latest date notification',
        'body': 'Newest',
        'date': '2026-10-03',
        'time': 1791028800000,
        'read': false,
      },
      {
        'id': 'older-1',
        'appName': 'Older app',
        'packageName': 'example.older',
        'title': 'Older first notification',
        'body': 'First',
        'date': '2026-10-02',
        'time': 1790942400000,
        'read': false,
      },
      {
        'id': 'older-2',
        'appName': 'Older app',
        'packageName': 'example.older',
        'title': 'Older remaining notification',
        'body': 'Second',
        'date': '2026-10-02',
        'time': 1790942300000,
        'read': false,
      },
    ];
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.text('Latest date notification'), findsOneWidget);
    expect(find.text('Older first notification'), findsNothing);
    await tester.ensureVisible(find.text('2026-10-02'));
    await tester.tap(find.text('2026-10-02'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Older first notification'));
    expect(find.text('Older first notification'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('older-1')),
      const Offset(700, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Older remaining notification'), findsOneWidget);
  });

  testWidgets('notification access disclosure requires explicit agreement', (
    tester,
  ) async {
    hasPrivacyConsent = false;
    await tester.pumpWidget(const App());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('How notification access is used'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Agree and continue'), findsOneWidget);
    expect(find.text('Notifications'), findsNothing);

    await tester.tap(find.text('Agree and continue'));
    await tester.pump();

    await tester.ensureVisible(find.text('I understand and agree'));
    await tester.tap(find.text('I understand and agree'));
    await tester.pump();
    await tester.ensureVisible(find.text('Agree and continue'));
    await tester.tap(find.text('Agree and continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('app settings separate selected and available apps', (
    tester,
  ) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Important apps'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Notifications from important apps stay in your notification shade when silence is on.',
      ),
      findsOneWidget,
    );
    expect(find.text('Selected apps'), findsOneWidget);
    expect(find.text('Not selected'), findsOneWidget);
    expect(find.text('Beta app'), findsOneWidget);
    expect(find.text('Alpha app'), findsOneWidget);

    await tester.tap(find.text('Repetitive apps'));
    await tester.pumpAndSettle();
    expect(find.text('Selected apps'), findsOneWidget);
    expect(find.text('Not selected'), findsOneWidget);
    expect(find.text('Gamma app'), findsOneWidget);
  });
}

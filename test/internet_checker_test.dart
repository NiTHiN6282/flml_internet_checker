import 'package:flml_internet_checker/flml_internet_checker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final checker = FLMLInternetChecker.instance;
  final observer = InternetCheckerObserver.instance;
  var online = true;

  /// Switches the simulated connection and lets the UI settle.
  Future<void> setOnline(WidgetTester tester, bool value) async {
    online = value;
    await checker.checkNow();
    await tester.pumpAndSettle();
  }

  /// Stops polling so no timers are left pending when the test ends.
  void stopPolling() => checker.stopPolling();

  setUp(() async {
    online = true;
    checker.customCheck = () async => online;
    await checker.checkNow();
    observer.currentRoute.value = null;
    observer.currentRouteName.value = null;
    observer.currentRouteSettings.value = null;
  });

  tearDown(() {
    checker.stopPolling();
    checker.customCheck = null;
  });

  group('InternetCheckerObserver', () {
    test('is a singleton', () {
      expect(InternetCheckerObserver(), same(observer));
    });

    testWidgets('ignores popup routes such as dialogs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(content: Text('Dialog')),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      expect(observer.currentRouteName.value, '/');

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Dialog'), findsOneWidget);
      expect(observer.currentRouteName.value, '/');

      Navigator.of(tester.element(find.text('Dialog'))).pop();
      await tester.pumpAndSettle();
      expect(observer.currentRouteName.value, '/');
    });
  });

  group('InternetChecker', () {
    testWidgets('properties are initialized with defaults', (tester) async {
      const widget = InternetChecker(child: SizedBox());
      expect(widget.showOnlineRestoredBanner, isTrue);
      expect(widget.onlineRestoredText, 'Internet Connection Restored');
      expect(widget.onlineRestoredDuration, const Duration(seconds: 3));
      expect(widget.dismissibleBanner, isFalse);
      expect(widget.bannerAnimationDuration, const Duration(milliseconds: 300));
      expect(widget.bannerAnimationCurve, Curves.fastOutSlowIn);
      expect(widget.backgroundColor, isNull);
    });

    testWidgets('handles route changes without setState() during build',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          builder: (context, child) => InternetChecker(
            shouldCheckRoute: (_) => false,
            child: child!,
          ),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Second Page')),
                ),
              ),
              child: const Text('Go to Second Page'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go to Second Page'));
      await tester.pumpAndSettle();
      expect(find.text('Second Page'), findsOneWidget);
      stopPolling();
    });

    testWidgets('blocks the screen when offline and recovers on retry',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: InternetChecker(
            showOnlineRestoredBanner: false,
            child: Scaffold(body: Text('Main Content')),
          ),
        ),
      );
      await setOnline(tester, false);
      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(
        find.text('Please check your internet settings and try again.'),
        findsOneWidget,
      );

      online = true;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No Internet Connection'), findsNothing);
      expect(find.text('Main Content'), findsOneWidget);
      stopPolling();
    });

    testWidgets('keeps navigation state across a connection drop',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          builder: (context, child) => InternetChecker(child: child!),
          routes: {
            '/': (context) => TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/details'),
                  child: const Text('Home'),
                ),
            '/details': (context) => const Material(child: TextField()),
          },
        ),
      );
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'draft message');

      await setOnline(tester, false);
      expect(find.text('No Internet Connection'), findsOneWidget);

      await setOnline(tester, true);
      expect(find.text('No Internet Connection'), findsNothing);
      // Still on the details page, with the typed text intact.
      expect(find.text('Home'), findsNothing);
      expect(find.text('draft message'), findsOneWidget);
      stopPolling();
    });

    testWidgets('shows the restored banner after reconnecting, then hides it',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: InternetChecker(child: Scaffold(body: Text('Main Content'))),
        ),
      );
      await setOnline(tester, false);
      await setOnline(tester, true);
      expect(find.text('Internet Connection Restored'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Internet Connection Restored'), findsNothing);
      stopPolling();
    });

    testWidgets('onOfflineModeChanged fires once per actual change',
        (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: InternetChecker(
            onOfflineModeChanged: changes.add,
            child: const SizedBox(),
          ),
        ),
      );
      await setOnline(tester, false);
      await setOnline(tester, false);
      await setOnline(tester, true);
      await tester.pump(const Duration(seconds: 3));
      expect(changes, [true, false]);
      stopPolling();
    });

    testWidgets('excluded routes stay usable when a dialog is opened',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          builder: (context, child) => InternetChecker(
            excludeRoutes: const ['/'],
            child: child!,
          ),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(content: Text('Dialog')),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await setOnline(tester, false);
      expect(find.text('No Internet Connection'), findsNothing);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Dialog'), findsOneWidget);
      expect(find.text('No Internet Connection'), findsNothing);
      stopPolling();
    });

    testWidgets('uses a dark background in dark themes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const InternetChecker(child: SizedBox()),
        ),
      );
      await setOnline(tester, false);
      final material = tester.widget<Material>(
        find
            .ancestor(
              of: find.text('No Internet Connection'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, const Color(0xFF121212));
      stopPolling();
    });

    testWidgets('banner slides out with an exit animation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: InternetChecker(
            useBanner: true,
            showOnlineRestoredBanner: false,
            child: Scaffold(body: Text('Main Content')),
          ),
        ),
      );
      await setOnline(tester, false);
      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(find.text('Main Content'), findsOneWidget);

      online = true;
      await checker.checkNow();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Mid-animation: still visible while sliding out.
      expect(find.text('No Internet Connection'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('No Internet Connection'), findsNothing);
      stopPolling();
    });

    testWidgets('offline banner can be dismissed with the close button',
        (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: InternetChecker(
            useBanner: true,
            dismissibleBanner: true,
            onBannerDismissed: () => dismissed = true,
            child: const Scaffold(body: Text('Main Content')),
          ),
        ),
      );
      await setOnline(tester, false);
      expect(find.text('No Internet Connection'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('No Internet Connection'), findsNothing);
      expect(dismissed, isTrue);
      stopPolling();
    });

    testWidgets('offline banner supports swipe-to-dismiss', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: InternetChecker(
            useBanner: true,
            dismissibleBanner: true,
            onBannerDismissed: () => dismissed = true,
            child: const Scaffold(body: Text('Main Content')),
          ),
        ),
      );
      await setOnline(tester, false);

      await tester.drag(
          find.text('No Internet Connection'), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(find.text('No Internet Connection'), findsNothing);
      expect(dismissed, isTrue);

      // It reappears the next time the connection drops.
      await setOnline(tester, true);
      await tester.pump(const Duration(seconds: 3));
      await setOnline(tester, false);
      expect(find.text('No Internet Connection'), findsOneWidget);
      stopPolling();
    });
  });

  group('InternetConnectionBuilder', () {
    testWidgets('rebuilds when the connection changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InternetConnectionBuilder(
            builder: (context, isConnected) =>
                Text(isConnected ? 'Online' : 'Offline'),
          ),
        ),
      );
      expect(find.text('Online'), findsOneWidget);

      await setOnline(tester, false);
      expect(find.text('Offline'), findsOneWidget);

      await setOnline(tester, true);
      expect(find.text('Online'), findsOneWidget);
      stopPolling();
    });
  });
}

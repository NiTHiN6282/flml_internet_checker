import 'package:flml_internet_checker/flml_internet_checker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FLMLInternetChecker Tests', () {
    test('FLMLInternetChecker is a singleton', () {
      final instance1 = FLMLInternetChecker.instance;
      final instance2 = FLMLInternetChecker.instance;
      expect(instance1, same(instance2));
    });

    test('Default configurations are initialized', () {
      final checker = FLMLInternetChecker.instance;
      expect(checker.lookupHosts, isNotEmpty);
      expect(checker.ipAddresses, isNotEmpty);
      expect(checker.port, equals(53));
    });

    test('Custom configurations are applied correctly', () {
      final checker = FLMLInternetChecker.instance;

      checker.configure(
        lookupHosts: ['test.host'],
        ipAddresses: ['1.2.3.4'],
        port: 80,
      );

      expect(checker.lookupHosts, contains('test.host'));
      expect(checker.ipAddresses, contains('1.2.3.4'));
      expect(checker.port, equals(80));

      // Reset to original values for safety
      checker.configure(
        lookupHosts: [
          'dns.google',
          'one.one.one.one',
          'github.com',
          'cloudflare.com'
        ],
        ipAddresses: ['8.8.8.8', '1.1.1.1', '208.67.222.222'],
        port: 53,
      );
    });
  });

  group('InternetCheckerObserver Tests', () {
    test('InternetCheckerObserver is a singleton', () {
      final instance1 = InternetCheckerObserver.instance;
      final instance2 = InternetCheckerObserver();
      expect(instance1, same(instance2));
    });
  });

  group('InternetChecker Widget Tests', () {
    testWidgets(
        'InternetChecker handles route changes without throwing setState() during build exception',
        (WidgetTester tester) async {
      // Configure checker with empty lists to avoid network timeouts/timers in test environment
      final checker = FLMLInternetChecker.instance;
      final originalHosts = checker.lookupHosts;
      final originalIps = checker.ipAddresses;

      checker.configure(
        lookupHosts: [],
        ipAddresses: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [InternetCheckerObserver.instance],
          builder: (context, child) => InternetChecker(
            shouldCheckRoute: (_) => false,
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const Scaffold(body: Text('Second Page'))),
                  );
                },
                child: const Text('Go to Second Page'),
              ),
            ),
          ),
        ),
      );

      // Verify initial setup doesn't throw
      expect(find.text('Go to Second Page'), findsOneWidget);

      // Push second page to trigger route changed listener
      await tester.tap(find.text('Go to Second Page'));
      await tester.pumpAndSettle();

      expect(find.text('Second Page'), findsOneWidget);

      // Stop polling to clean up pending timers
      checker.stopPolling();

      // Restore original configuration
      checker.configure(
        lookupHosts: originalHosts,
        ipAddresses: originalIps,
      );
    });

    testWidgets('InternetChecker properties initialized with defaults',
        (WidgetTester tester) async {
      const checker = InternetChecker(
        child: SizedBox(),
      );
      expect(checker.showOnlineRestoredBanner, isTrue);
      expect(
          checker.onlineRestoredText, equals('Internet Connection Restored'));
      expect(
          checker.onlineRestoredDuration, equals(const Duration(seconds: 3)));
      expect(checker.dismissibleBanner, isFalse);
      expect(checker.bannerAnimationDuration,
          equals(const Duration(milliseconds: 300)));
      expect(checker.bannerAnimationCurve, equals(Curves.fastOutSlowIn));
    });

    testWidgets(
        'InternetChecker shows offline banner and handles close button dismissal',
        (WidgetTester tester) async {
      final checker = FLMLInternetChecker.instance;
      final originalHosts = checker.lookupHosts;
      final originalIps = checker.ipAddresses;

      // Force offline state
      checker.configure(
        lookupHosts: [],
        ipAddresses: [],
      );

      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: InternetChecker(
            useBanner: true,
            dismissibleBanner: true,
            onBannerDismissed: () {
              dismissed = true;
            },
            child: const Scaffold(
              body: Text('Main Content'),
            ),
          ),
        ),
      );

      // Trigger the connection check
      await checker.checkNow();
      await tester.pumpAndSettle();

      // Verify offline banner is displayed
      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap the close button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Verify banner is dismissed and callback is triggered
      expect(find.text('No Internet Connection'), findsNothing);
      expect(dismissed, isTrue);

      // Clean up
      checker.stopPolling();
      checker.configure(
        lookupHosts: originalHosts,
        ipAddresses: originalIps,
      );
    });

    testWidgets('InternetChecker offline banner supports swipe-to-dismiss',
        (WidgetTester tester) async {
      final checker = FLMLInternetChecker.instance;
      final originalHosts = checker.lookupHosts;
      final originalIps = checker.ipAddresses;

      // Force offline state
      checker.configure(
        lookupHosts: [],
        ipAddresses: [],
      );

      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: InternetChecker(
            useBanner: true,
            dismissibleBanner: true,
            onBannerDismissed: () {
              dismissed = true;
            },
            child: const Scaffold(
              body: Text('Main Content'),
            ),
          ),
        ),
      );

      // Trigger the connection check
      await checker.checkNow();
      await tester.pumpAndSettle();

      // Verify offline banner is displayed
      expect(find.text('No Internet Connection'), findsOneWidget);

      // Swipe the banner to the right to dismiss
      await tester.drag(
          find.text('No Internet Connection'), const Offset(500.0, 0.0));
      await tester.pumpAndSettle();

      // Verify banner is dismissed and callback is triggered
      expect(find.text('No Internet Connection'), findsNothing);
      expect(dismissed, isTrue);

      // Clean up
      checker.stopPolling();
      checker.configure(
        lookupHosts: originalHosts,
        ipAddresses: originalIps,
      );
    });
  });
}

import 'dart:async';

import 'package:flml_internet_checker/flml_internet_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final checker = FLMLInternetChecker.instance;
  var online = true;

  setUp(() async {
    online = true;
    checker.customCheck = () async => online;
    await checker.checkNow();
  });

  tearDown(() {
    checker.stopPolling();
    checker.customCheck = null;
    checker.timeout = const Duration(seconds: 3);
  });

  test('is a singleton', () {
    expect(FLMLInternetChecker.instance, same(checker));
  });

  test('exposes defaults including IPv6 DNS servers', () {
    expect(FLMLInternetChecker.defaultLookupHosts, isNotEmpty);
    expect(FLMLInternetChecker.defaultIpAddresses, contains('8.8.8.8'));
    expect(
      FLMLInternetChecker.defaultIpAddresses,
      contains('2606:4700:4700::1111'),
    );
    expect(checker.port, equals(53));
  });

  test('configure applies custom values', () {
    checker.configure(
      lookupHosts: ['test.host'],
      ipAddresses: ['1.2.3.4'],
      port: 80,
    );

    expect(checker.lookupHosts, equals(['test.host']));
    expect(checker.ipAddresses, equals(['1.2.3.4']));
    expect(checker.port, equals(80));

    checker.configure(
      lookupHosts: FLMLInternetChecker.defaultLookupHosts,
      ipAddresses: FLMLInternetChecker.defaultIpAddresses,
      port: 53,
    );
  });

  test('status mirrors isConnected', () async {
    expect(checker.status, InternetConnectionStatus.connected);
    online = false;
    await checker.checkNow();
    expect(checker.isConnected, isFalse);
    expect(checker.status, InternetConnectionStatus.disconnected);
  });

  test('onStatusChange only emits actual changes', () async {
    final events = <bool>[];
    final sub = checker.onStatusChange.listen(events.add);
    addTearDown(sub.cancel);

    await checker.checkNow(); // still online
    online = false;
    await checker.checkNow();
    await checker.checkNow(); // still offline
    online = true;
    await checker.checkNow();
    await Future<void>.delayed(Duration.zero);

    expect(events, equals([false, true]));
  });

  test('listening to onStatusChange starts polling automatically', () async {
    expect(checker.isPolling, isFalse);
    final sub = checker.onStatusChange.listen((_) {});
    addTearDown(sub.cancel);
    expect(checker.isPolling, isTrue);
  });

  test('concurrent checks share a single in-flight probe', () async {
    var calls = 0;
    final gate = Completer<bool>();
    checker.customCheck = () {
      calls++;
      return gate.future;
    };

    final first = checker.checkConnection();
    final second = checker.checkNow();
    final third = checker.checkConnection();
    gate.complete(false);

    expect(await Future.wait([first, second, third]), [false, false, false]);
    expect(calls, 1);

    // A new check starts once the previous one has completed.
    checker.customCheck = () async {
      calls++;
      return true;
    };
    expect(await checker.checkConnection(), isTrue);
    expect(calls, 2);
  });

  test('a throwing customCheck counts as offline', () async {
    checker.customCheck = () async => throw Exception('boom');
    expect(await checker.checkNow(), isFalse);
    expect(checker.isConnected, isFalse);
  });

  test('a customCheck slower than the timeout counts as offline', () async {
    checker.timeout = const Duration(milliseconds: 50);
    checker.customCheck =
        () => Future.delayed(const Duration(seconds: 1), () => true);
    expect(await checker.checkNow(), isFalse);
  });
}

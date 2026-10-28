@TestOn('vm')
library;

import 'dart:io';

import 'package:flml_internet_checker/src/platform/platform_checker_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('platformCheckConnection (io)', () {
    test('returns false when there is nothing to probe', () async {
      final result = await platformCheckConnection(
        lookupHosts: [],
        ipAddresses: [],
        port: 53,
        timeout: const Duration(seconds: 1),
      );
      expect(result, isFalse);
    });

    test('returns true when any TCP target accepts the connection', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((socket) => socket.destroy());

      final result = await platformCheckConnection(
        lookupHosts: [],
        // The first target refuses the connection, the second accepts it.
        ipAddresses: ['127.0.0.1', '127.0.0.1'],
        port: server.port,
        timeout: const Duration(seconds: 2),
      );
      expect(result, isTrue);
    });

    test('returns false quickly when every target refuses', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final closedPort = server.port;
      await server.close();

      final stopwatch = Stopwatch()..start();
      final result = await platformCheckConnection(
        lookupHosts: ['host.invalid'],
        ipAddresses: ['127.0.0.1'],
        port: closedPort,
        timeout: const Duration(seconds: 10),
      );
      expect(result, isFalse);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 10)));
    });

    test('never takes longer than the timeout', () async {
      final stopwatch = Stopwatch()..start();
      final result = await platformCheckConnection(
        lookupHosts: [],
        // Non-routable address: the connection attempt hangs.
        ipAddresses: ['10.255.255.1'],
        port: 53,
        timeout: const Duration(milliseconds: 300),
      );
      expect(result, isFalse);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });
}

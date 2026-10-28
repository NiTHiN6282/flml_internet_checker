@TestOn('browser')
library;

import 'package:flml_internet_checker/src/platform/platform_checker_web.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('platformCheckConnection (web)', () {
    test('returns false when there is nothing to probe', () async {
      final result = await platformCheckConnection(
        lookupHosts: [],
        ipAddresses: [],
        port: 53,
        timeout: const Duration(seconds: 2),
      );
      // The test server runs on localhost, which is never used as a probe.
      expect(result, isFalse);
    });

    test('returns false within the timeout for unreachable hosts', () async {
      final stopwatch = Stopwatch()..start();
      final result = await platformCheckConnection(
        lookupHosts: ['host.invalid'],
        ipAddresses: [],
        port: 53,
        timeout: const Duration(seconds: 2),
      );
      expect(result, isFalse);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 4)));
    });

    test('listening for browser changes does not throw', () {
      platformListenForChanges(() {});
    });
  });
}

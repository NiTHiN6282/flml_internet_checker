import 'package:flutter_test/flutter_test.dart';
import 'package:flml_internet_checker/flml_internet_checker.dart';

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
        lookupHosts: ['dns.google', 'one.one.one.one', 'github.com', 'cloudflare.com'],
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
}

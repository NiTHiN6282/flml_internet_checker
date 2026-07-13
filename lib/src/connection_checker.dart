import 'dart:async';

import 'platform/platform_checker.dart';

/// States for the internet connection status.
enum InternetConnectionStatus {
  connected,
  disconnected,
}

/// A zero-dependency connection checker implemented in pure Dart.
///
/// It periodically verifies internet reachability by resolving hostnames via
/// DNS lookup ([InternetAddress.lookup]) and opening TCP socket connections to
/// public DNS servers on port 53 ([Socket.connect]).
class FLMLInternetChecker {
  // Private constructor
  FLMLInternetChecker._internal();

  /// The singleton instance of [FLMLInternetChecker].
  static final FLMLInternetChecker instance = FLMLInternetChecker._internal();

  /// Standard hosts to verify via DNS lookup.
  List<String> lookupHosts = [
    'dns.google',
    'one.one.one.one',
    'github.com',
    'cloudflare.com',
  ];

  /// Standard IP addresses (DNS servers) to verify via TCP socket connection on port 53.
  List<String> ipAddresses = [
    '8.8.8.8', // Google DNS
    '1.1.1.1', // Cloudflare DNS
    '208.67.222.222' // OpenDNS
  ];

  /// The port used for testing TCP socket connectivity (Default: 53 - DNS).
  int port = 53;

  /// Timeout duration for each check (Default: 3 seconds).
  Duration timeout = const Duration(seconds: 3);

  /// Polling interval when the device is online (Default: 15 seconds).
  Duration checkIntervalOnline = const Duration(seconds: 15);

  /// Polling interval when the device is offline (Default: 5 seconds).
  Duration checkIntervalOffline = const Duration(seconds: 5);

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();

  /// A stream that emits connection status changes (true: connected, false: disconnected).
  Stream<bool> get onStatusChange => _statusController.stream;

  Timer? _timer;
  bool _isPolling = false;

  /// Configures custom options for the connection checker.
  void configure({
    List<String>? lookupHosts,
    List<String>? ipAddresses,
    int? port,
    Duration? timeout,
    Duration? checkIntervalOnline,
    Duration? checkIntervalOffline,
  }) {
    if (lookupHosts != null) this.lookupHosts = lookupHosts;
    if (ipAddresses != null) this.ipAddresses = ipAddresses;
    if (port != null) this.port = port;
    if (timeout != null) this.timeout = timeout;
    if (checkIntervalOnline != null)
      this.checkIntervalOnline = checkIntervalOnline;
    if (checkIntervalOffline != null)
      this.checkIntervalOffline = checkIntervalOffline;

    // Reschedule next check with new intervals if currently polling
    if (_isPolling) {
      _scheduleNextCheck();
    }
  }

  /// Verifies connectivity by checking lookup hosts and IP addresses.
  /// Updates the connection state and notifies listeners.
  Future<bool> checkConnection() async {
    final connected = await platformCheckConnection(
      lookupHosts: lookupHosts,
      ipAddresses: ipAddresses,
      port: port,
      timeout: timeout,
    );
    _updateStatus(connected);
    return connected;
  }

  void _updateStatus(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      _statusController.add(connected);
    }
  }

  /// Starts periodic connection checking.
  void startPolling() {
    if (_isPolling) return;
    _isPolling = true;

    // Run immediate check
    checkConnection().then((_) {
      _scheduleNextCheck();
    });
  }

  /// Stops periodic connection checking.
  void stopPolling() {
    _timer?.cancel();
    _timer = null;
    _isPolling = false;
  }

  void _scheduleNextCheck() {
    if (!_isPolling) return;
    _timer?.cancel();

    final interval = _isConnected ? checkIntervalOnline : checkIntervalOffline;
    _timer = Timer(interval, () async {
      await checkConnection();
      _scheduleNextCheck();
    });
  }

  /// Performs an immediate, manual check and returns the connection status.
  Future<bool> checkNow() async {
    final result = await checkConnection();
    if (_isPolling) {
      _scheduleNextCheck();
    }
    return result;
  }
}

import 'dart:async';

import 'platform/platform_checker.dart';

/// States for the internet connection status.
enum InternetConnectionStatus {
  connected,
  disconnected,
}

/// A zero-dependency connection checker implemented in pure Dart.
///
/// It periodically verifies internet reachability by racing TCP connections
/// to well-known hosts (port 443) and public DNS servers (port 53). On the Web
/// it uses `navigator.onLine`, browser `online`/`offline` events and
/// lightweight HTTP pings instead.
///
/// Polling starts automatically as soon as anything listens to
/// [onStatusChange] (including the `InternetChecker` and
/// `InternetConnectionBuilder` widgets), so most apps never need to call
/// [startPolling] themselves.
class FLMLInternetChecker {
  // Private constructor
  FLMLInternetChecker._internal();

  /// The singleton instance of [FLMLInternetChecker].
  static final FLMLInternetChecker instance = FLMLInternetChecker._internal();

  /// The default [lookupHosts].
  static const List<String> defaultLookupHosts = [
    'dns.google',
    'one.one.one.one',
    'github.com',
    'cloudflare.com',
  ];

  /// The default [ipAddresses]: IPv4 and IPv6 public DNS servers.
  static const List<String> defaultIpAddresses = [
    '8.8.8.8', // Google DNS
    '1.1.1.1', // Cloudflare DNS
    '208.67.222.222', // OpenDNS
    '2001:4860:4860::8888', // Google DNS (IPv6)
    '2606:4700:4700::1111', // Cloudflare DNS (IPv6)
  ];

  /// Hosts to verify by opening a TCP connection on port 443.
  ///
  /// On the Web, these hosts are pinged over HTTPS instead.
  List<String> lookupHosts = List.of(defaultLookupHosts);

  /// IP addresses to verify by opening a TCP connection on [port].
  ///
  /// Ignored on the Web.
  List<String> ipAddresses = List.of(defaultIpAddresses);

  /// The port used for testing TCP connectivity to [ipAddresses]
  /// (Default: 53 - DNS).
  int port = 53;

  /// Timeout duration for each check (Default: 3 seconds).
  Duration timeout = const Duration(seconds: 3);

  /// Polling interval when the device is online (Default: 15 seconds).
  Duration checkIntervalOnline = const Duration(seconds: 15);

  /// Polling interval when the device is offline (Default: 5 seconds).
  Duration checkIntervalOffline = const Duration(seconds: 5);

  /// Optional custom check that replaces the built-in probes, e.g. a health
  /// check against your own backend.
  ///
  /// Return `true` when online. Throwing, or not completing within [timeout],
  /// counts as offline. Set it back to `null` to restore the built-in probes.
  Future<bool> Function()? customCheck;

  bool _isConnected = true;

  /// The last known connection state.
  ///
  /// Defaults to `true` until the first check completes.
  bool get isConnected => _isConnected;

  /// The last known connection state as an [InternetConnectionStatus].
  InternetConnectionStatus get status => _isConnected
      ? InternetConnectionStatus.connected
      : InternetConnectionStatus.disconnected;

  late final StreamController<bool> _statusController =
      StreamController<bool>.broadcast(onListen: startPolling);

  /// A stream that emits connection status changes (true: connected,
  /// false: disconnected).
  ///
  /// Only changes are emitted; read [isConnected] for the current value.
  /// Listening starts polling automatically.
  Stream<bool> get onStatusChange => _statusController.stream;

  Timer? _timer;
  bool _isPolling = false;
  bool _listeningForPlatformChanges = false;
  Future<bool>? _inFlightCheck;

  /// Whether periodic checking is currently active.
  bool get isPolling => _isPolling;

  /// Configures custom options for the connection checker.
  void configure({
    List<String>? lookupHosts,
    List<String>? ipAddresses,
    int? port,
    Duration? timeout,
    Duration? checkIntervalOnline,
    Duration? checkIntervalOffline,
    Future<bool> Function()? customCheck,
  }) {
    if (lookupHosts != null) {
      this.lookupHosts = lookupHosts;
    }
    if (ipAddresses != null) {
      this.ipAddresses = ipAddresses;
    }
    if (port != null) {
      this.port = port;
    }
    if (timeout != null) {
      this.timeout = timeout;
    }
    if (checkIntervalOnline != null) {
      this.checkIntervalOnline = checkIntervalOnline;
    }
    if (checkIntervalOffline != null) {
      this.checkIntervalOffline = checkIntervalOffline;
    }
    if (customCheck != null) {
      this.customCheck = customCheck;
    }

    // Reschedule next check with new intervals if currently polling
    if (_isPolling) {
      _scheduleNextCheck();
    }
  }

  /// Verifies connectivity and updates the connection state, notifying
  /// listeners on change.
  ///
  /// Concurrent calls share a single in-flight check, so results can never be
  /// applied out of order.
  Future<bool> checkConnection() {
    return _inFlightCheck ??=
        _runCheck().whenComplete(() => _inFlightCheck = null);
  }

  Future<bool> _runCheck() async {
    bool connected;
    try {
      final custom = customCheck;
      connected = custom != null
          ? await custom().timeout(timeout)
          : await platformCheckConnection(
              lookupHosts: lookupHosts,
              ipAddresses: ipAddresses,
              port: port,
              timeout: timeout,
            );
    } catch (_) {
      connected = false;
    }
    _updateStatus(connected);
    return connected;
  }

  void _updateStatus(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      _statusController.add(connected);
    }
  }

  /// Starts periodic connection checking. Does nothing if already polling.
  void startPolling() {
    if (_isPolling) return;
    _isPolling = true;

    if (!_listeningForPlatformChanges) {
      _listeningForPlatformChanges = true;
      platformListenForChanges(() {
        if (_isPolling) checkNow();
      });
    }

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

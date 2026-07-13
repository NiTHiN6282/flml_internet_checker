import 'dart:async';

import 'package:flutter/material.dart';

import 'connection_checker.dart';
import 'internet_checker_observer.dart';

/// Defines where the non-blocking internet checker banner is located.
enum InternetCheckerBannerLocation {
  top,
  bottom,
}

/// A widget that checks for internet connectivity.
///
/// It can be used globally by wrapping the app in a builder:
/// ```dart
/// MaterialApp(
///   builder: (context, child) => InternetChecker(child: child!),
///   navigatorObservers: [InternetCheckerObserver()],
/// )
/// ```
///
/// Or it can wrap individual screens:
/// ```dart
/// InternetChecker(
///   child: MyScreen(),
/// )
/// ```
class InternetChecker extends StatefulWidget {
  /// The child widget to be displayed when online or when routing rules bypass the check.
  final Widget child;

  /// Custom widget to display when offline in blocking mode. If not provided,
  /// a beautiful default offline layout is used.
  final Widget? placeHolder;

  /// The text to display when offline in blocking mode (Default: "No Internet Connection").
  final String internetConnectionText;

  /// The style for the offline message in blocking mode.
  final TextStyle? textStyle;

  /// The background color for the blocking offline screen (Default: [Colors.white]).
  final Color backgroundColor;

  /// If true, displays a non-blocking floating banner at the top or bottom
  /// of the screen when offline instead of blocking the whole view.
  final bool useBanner;

  /// Text to display in the offline banner (Default: "No Internet Connection").
  final String bannerText;

  /// TextStyle for the banner message.
  final TextStyle? bannerTextStyle;

  /// Background color for the offline banner (Default: Crimson Red).
  final Color? bannerBackgroundColor;

  /// Position of the offline banner: top or bottom (Default: [InternetCheckerBannerLocation.bottom]).
  final InternetCheckerBannerLocation bannerLocation;

  /// Optional builder to customize the offline banner layout.
  /// Receives [isConnected] state to allow animating exit transitions.
  final Widget Function(BuildContext context, bool isConnected)? bannerBuilder;

  /// List of route names where the offline checks should be bypassed/ignored (blacklist).
  final List<String>? excludeRoutes;

  /// List of route names where the offline checks should ONLY occur (whitelist).
  final List<String>? includeRoutes;

  /// Custom filter predicate to dynamically decide if a route needs checking.
  final bool Function(Route<dynamic> route)? shouldCheckRoute;

  /// If true, shows a retry button on the blocking offline screen (Default: true).
  final bool showRetryButton;

  /// The text displayed on the retry button (Default: "Retry").
  final String retryButtonText;

  /// The custom style for the retry button.
  final ButtonStyle? retryButtonStyle;

  /// Callback triggered whenever the connection state changes.
  final ValueChanged<bool>? onOfflineModeChanged;

  /// If true, shows a transient banner/toast when connection is restored (Default: true).
  final bool showOnlineRestoredBanner;

  /// Text to display when online connection is restored (Default: "Internet Connection Restored").
  final String onlineRestoredText;

  /// TextStyle for the connection restored banner.
  final TextStyle? onlineRestoredTextStyle;

  /// Background color for the connection restored banner (Default: Forest Green).
  final Color? onlineRestoredBackgroundColor;

  /// Duration to show the connection restored banner before it auto-dismisses (Default: 3 seconds).
  final Duration onlineRestoredDuration;

  /// If true, the offline banner is dismissible via horizontal swipe or a close icon (Default: false).
  final bool dismissibleBanner;

  /// Callback triggered when the offline banner is dismissed.
  final VoidCallback? onBannerDismissed;

  /// Duration for the banner entrance and exit animations (Default: 300 milliseconds).
  final Duration bannerAnimationDuration;

  /// Curve for the banner slide animation (Default: [Curves.fastOutSlowIn]).
  final Curve bannerAnimationCurve;

  const InternetChecker({
    Key? key,
    required this.child,
    this.placeHolder,
    this.internetConnectionText = "No Internet Connection",
    this.textStyle,
    this.backgroundColor = Colors.white,
    this.useBanner = false,
    this.bannerText = "No Internet Connection",
    this.bannerTextStyle,
    this.bannerBackgroundColor,
    this.bannerLocation = InternetCheckerBannerLocation.bottom,
    this.bannerBuilder,
    this.excludeRoutes,
    this.includeRoutes,
    this.shouldCheckRoute,
    this.showRetryButton = true,
    this.retryButtonText = "Retry",
    this.retryButtonStyle,
    this.onOfflineModeChanged,
    this.showOnlineRestoredBanner = true,
    this.onlineRestoredText = "Internet Connection Restored",
    this.onlineRestoredTextStyle,
    this.onlineRestoredBackgroundColor,
    this.onlineRestoredDuration = const Duration(seconds: 3),
    this.dismissibleBanner = false,
    this.onBannerDismissed,
    this.bannerAnimationDuration = const Duration(milliseconds: 300),
    this.bannerAnimationCurve = Curves.fastOutSlowIn,
  }) : super(key: key);

  @override
  State<InternetChecker> createState() => _InternetCheckerState();
}

class _InternetCheckerState extends State<InternetChecker>
    with WidgetsBindingObserver {
  late final FLMLInternetChecker _checker;
  late StreamSubscription<bool> _subscription;
  bool _isConnected = true;
  bool _isChecking = false;
  String? _currentRouteName;
  Route<dynamic>? _currentRoute;

  Timer? _onlineRestoredTimer;
  bool _showOnlineRestored = false;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _checker = FLMLInternetChecker.instance;
    _isConnected = _checker.isConnected;

    // Register app lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Listen to routing changes if the observer is configured
    InternetCheckerObserver.instance.currentRoute.addListener(_onRouteChanged);
    _currentRoute = InternetCheckerObserver.instance.currentRoute.value;
    _currentRouteName = _currentRoute?.settings.name;

    // Start checking connection
    _checker.startPolling();
    _subscription = _checker.onStatusChange.listen((connected) {
      if (mounted) {
        final wasOffline = !_isConnected;
        setState(() {
          _isConnected = connected;
          if (connected) {
            if (wasOffline) {
              _bannerDismissed = false;
              if (widget.showOnlineRestoredBanner) {
                _showOnlineRestored = true;
                _startOnlineRestoredTimer();
              }
            }
          } else {
            _showOnlineRestored = false;
            _bannerDismissed = false;
            _onlineRestoredTimer?.cancel();
          }
        });
        widget.onOfflineModeChanged?.call(!connected);
      }
    });

    // Run initial connection check
    _checkInitialConnection();
  }

  void _startOnlineRestoredTimer() {
    _onlineRestoredTimer?.cancel();
    _onlineRestoredTimer = Timer(widget.onlineRestoredDuration, () {
      if (mounted) {
        setState(() {
          _showOnlineRestored = false;
        });
      }
    });
  }

  Future<void> _checkInitialConnection() async {
    final connected = await _checker.checkNow();
    if (mounted) {
      setState(() {
        _isConnected = connected;
      });
    }
  }

  void _onRouteChanged() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentRoute = InternetCheckerObserver.instance.currentRoute.value;
            _currentRouteName = _currentRoute?.settings.name;
          });
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App returns to foreground: resume active polling and run immediate check
      _checker.startPolling();
      _checker.checkNow();
    } else if (state == AppLifecycleState.paused) {
      // App is in background: stop polling to conserve device battery
      _checker.stopPolling();
    }
  }

  @override
  void dispose() {
    _onlineRestoredTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    InternetCheckerObserver.instance.currentRoute
        .removeListener(_onRouteChanged);
    _subscription.cancel();
    super.dispose();
  }

  bool _shouldCheckCurrentRoute() {
    final route = _currentRoute;
    final name = _currentRouteName;

    // Custom filtering function takes precedence
    if (widget.shouldCheckRoute != null) {
      if (route != null) {
        return widget.shouldCheckRoute!(route);
      }
      return true;
    }

    // Default to checking if the observer hasn't captured any route yet
    // or if the widget is used directly without the global observer.
    if (name == null) {
      return true;
    }

    // Blacklist/Exclusions check
    if (widget.excludeRoutes != null && widget.excludeRoutes!.contains(name)) {
      return false;
    }

    // Whitelist/Inclusions check
    if (widget.includeRoutes != null) {
      return widget.includeRoutes!.contains(name);
    }

    return true;
  }

  Future<void> _handleRetry() async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
    });

    final connected = await _checker.checkNow();

    if (mounted) {
      setState(() {
        _isConnected = connected;
        _isChecking = false;
      });
    }
  }

  Widget _buildDefaultBlockingOfflineView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.wifi_off_rounded,
            size: 72,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          widget.internetConnectionText,
          style: widget.textStyle ??
              const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C2C2C),
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "Please check your internet settings and try again.",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.showRetryButton) ...[
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isChecking ? null : _handleRetry,
            style: widget.retryButtonStyle ??
                ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E24),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
            child: _isChecking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    widget.retryButtonText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ]
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = !_isConnected;
    final isCheckingRoute = _shouldCheckCurrentRoute();

    // If we should not check this route, render normal UI
    if (!isCheckingRoute) {
      return widget.child;
    }

    // If online and not showing the restored banner, render normal UI
    if (!isOffline && !_showOnlineRestored) {
      return widget.child;
    }

    // Blocking Full Screen Mode
    if (isOffline && !widget.useBanner) {
      return Scaffold(
        backgroundColor: widget.backgroundColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: widget.placeHolder ?? _buildDefaultBlockingOfflineView(),
            ),
          ),
        ),
      );
    }

    // Non-blocking Banner Mode or Online Restored Banner Mode
    final showBanner = (isOffline && widget.useBanner && !_bannerDismissed) ||
        (!isOffline && _showOnlineRestored);

    if (!showBanner) {
      return widget.child;
    }

    final Widget bannerWidget;
    if (isOffline) {
      final defaultBanner = Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: widget.bannerBackgroundColor ?? const Color(0xFFD32F2F),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4D000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.bannerText,
                style: widget.bannerTextStyle ??
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            if (widget.dismissibleBanner) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _bannerDismissed = true;
                  });
                  widget.onBannerDismissed?.call();
                },
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ],
        ),
      );

      final builtBanner = widget.bannerBuilder != null
          ? widget.bannerBuilder!(context, _isConnected)
          : defaultBanner;

      bannerWidget = widget.dismissibleBanner
          ? Dismissible(
              key: const Key('flml_internet_checker_offline_banner'),
              direction: DismissDirection.horizontal,
              onDismissed: (_) {
                setState(() {
                  _bannerDismissed = true;
                });
                widget.onBannerDismissed?.call();
              },
              child: builtBanner,
            )
          : builtBanner;
    } else {
      final defaultOnlineBanner = Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              widget.onlineRestoredBackgroundColor ?? const Color(0xFF2E7D32),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4D000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.onlineRestoredText,
                style: widget.onlineRestoredTextStyle ??
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
      );

      bannerWidget = defaultOnlineBanner;
    }

    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          AnimatedPositioned(
            duration: widget.bannerAnimationDuration,
            curve: widget.bannerAnimationCurve,
            left: 0,
            right: 0,
            top: widget.bannerLocation == InternetCheckerBannerLocation.top
                ? 0
                : null,
            bottom:
                widget.bannerLocation == InternetCheckerBannerLocation.bottom
                    ? 0
                    : null,
            child: SafeArea(
              child: Center(child: bannerWidget),
            ),
          ),
        ],
      ),
    );
  }
}

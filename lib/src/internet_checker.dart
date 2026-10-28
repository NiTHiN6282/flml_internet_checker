import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'connection_checker.dart';
import 'internet_checker_observer.dart';

/// Defines where the non-blocking internet checker banner is located.
enum InternetCheckerBannerLocation {
  top,
  bottom,
}

enum _BannerKind { offline, restored }

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
///
/// The [child] is never removed from the tree while offline: the offline
/// screen is drawn on top of it, so navigation stacks, scroll positions and
/// form input survive connection drops.
class InternetChecker extends StatefulWidget {
  /// The child widget to be displayed when online or when routing rules bypass the check.
  final Widget child;

  /// Custom widget to display when offline in blocking mode. If not provided,
  /// a beautiful default offline layout is used.
  ///
  /// Call `FLMLInternetChecker.instance.checkNow()` to add your own retry
  /// action.
  final Widget? placeHolder;

  /// The text to display when offline in blocking mode (Default: "No Internet Connection").
  final String internetConnectionText;

  /// The secondary text displayed below [internetConnectionText] on the
  /// default blocking offline screen. Set to `null` to hide it.
  final String? internetConnectionDescription;

  /// The style for the offline message in blocking mode.
  final TextStyle? textStyle;

  /// The background color for the blocking offline screen.
  ///
  /// Defaults to white in light themes and a dark surface in dark themes.
  final Color? backgroundColor;

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
  ///
  /// The returned widget is animated in and out automatically using
  /// [bannerAnimationDuration] and [bannerAnimationCurve].
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
  ///
  /// Receives `true` when the device goes offline and `false` when it comes
  /// back online.
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
    super.key,
    required this.child,
    this.placeHolder,
    this.internetConnectionText = "No Internet Connection",
    this.internetConnectionDescription =
        "Please check your internet settings and try again.",
    this.textStyle,
    this.backgroundColor,
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
  });

  @override
  State<InternetChecker> createState() => _InternetCheckerState();
}

class _InternetCheckerState extends State<InternetChecker>
    with WidgetsBindingObserver {
  late final FLMLInternetChecker _checker;
  late final StreamSubscription<bool> _subscription;
  bool _isConnected = true;
  bool _isChecking = false;
  String? _currentRouteName;
  Route<dynamic>? _currentRoute;

  Timer? _onlineRestoredTimer;
  bool _showOnlineRestored = false;
  bool _bannerDismissed = false;

  /// Bumped when the banner is swiped away, so the dismissed [Dismissible] is
  /// removed immediately instead of lingering in an exit animation.
  int _bannerGeneration = 0;

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

    // Subscribing starts polling automatically.
    _subscription = _checker.onStatusChange.listen(_applyStatus);

    // Run an immediate check (shared with any check already in flight).
    _checker.checkNow().then(_applyStatus);
  }

  /// Applies a connection state. Idempotent, so the stream event and the
  /// result of an awaited check can both be applied safely in any order.
  void _applyStatus(bool connected) {
    if (!mounted || connected == _isConnected) return;
    setState(() {
      _isConnected = connected;
      _bannerDismissed = false;
      if (connected) {
        if (widget.showOnlineRestoredBanner) {
          _showOnlineRestored = true;
          _startOnlineRestoredTimer();
        }
      } else {
        _showOnlineRestored = false;
        _onlineRestoredTimer?.cancel();
      }
    });
    widget.onOfflineModeChanged?.call(!connected);
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

  void _onRouteChanged() {
    // Routes can be pushed while the Navigator builds; defer to avoid calling
    // setState() during build.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _syncRoute());
    } else {
      _syncRoute();
    }
  }

  void _syncRoute() {
    if (!mounted) return;
    setState(() {
      _currentRoute = InternetCheckerObserver.instance.currentRoute.value;
      _currentRouteName = _currentRoute?.settings.name;
    });
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
        _isChecking = false;
      });
      _applyStatus(connected);
    }
  }

  void _dismissBanner({required bool swiped}) {
    setState(() {
      _bannerDismissed = true;
      if (swiped) _bannerGeneration++;
    });
    widget.onBannerDismissed?.call();
  }

  Widget _buildDefaultBlockingOfflineView(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.wifi_off_rounded,
            size: 72,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          widget.internetConnectionText,
          style: widget.textStyle ??
              TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? const Color(0xFFEDEDED) : const Color(0xFF2C2C2C),
              ),
          textAlign: TextAlign.center,
        ),
        if (widget.internetConnectionDescription != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.internetConnectionDescription!,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (widget.showRetryButton) ...[
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isChecking ? null : _handleRetry,
            style: widget.retryButtonStyle ??
                ElevatedButton.styleFrom(
                  backgroundColor:
                      isDark ? Colors.white : const Color(0xFF1E1E24),
                  foregroundColor:
                      isDark ? const Color(0xFF1E1E24) : Colors.white,
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
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? const Color(0xFF1E1E24) : Colors.white,
                      ),
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

  Widget _buildBlockingView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: widget.backgroundColor ??
          (isDark ? const Color(0xFF121212) : Colors.white),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child:
                widget.placeHolder ?? _buildDefaultBlockingOfflineView(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerShell({
    required Color color,
    required IconData icon,
    required String text,
    required TextStyle? textStyle,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color,
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
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: textStyle ??
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildOfflineBanner(BuildContext context) {
    final banner = widget.bannerBuilder?.call(context, _isConnected) ??
        _buildBannerShell(
          color: widget.bannerBackgroundColor ?? const Color(0xFFD32F2F),
          icon: Icons.wifi_off_rounded,
          text: widget.bannerText,
          textStyle: widget.bannerTextStyle,
          trailing: widget.dismissibleBanner
              ? Semantics(
                  button: true,
                  label: 'Dismiss',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _dismissBanner(swiped: false),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                )
              : null,
        );

    if (!widget.dismissibleBanner) return banner;
    return Dismissible(
      key: const Key('flml_internet_checker_offline_banner'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => _dismissBanner(swiped: true),
      child: banner,
    );
  }

  Widget _buildRestoredBanner() {
    return _buildBannerShell(
      color: widget.onlineRestoredBackgroundColor ?? const Color(0xFF2E7D32),
      icon: Icons.wifi_rounded,
      text: widget.onlineRestoredText,
      textStyle: widget.onlineRestoredTextStyle,
    );
  }

  Widget _buildBannerArea(BuildContext context, _BannerKind? kind) {
    final isTop = widget.bannerLocation == InternetCheckerBannerLocation.top;
    final Widget banner = switch (kind) {
      _BannerKind.offline => KeyedSubtree(
          key: const ValueKey(_BannerKind.offline),
          child: _buildOfflineBanner(context),
        ),
      _BannerKind.restored => KeyedSubtree(
          key: const ValueKey(_BannerKind.restored),
          child: _buildRestoredBanner(),
        ),
      null => const SizedBox.shrink(),
    };

    return Positioned(
      key: const ValueKey('flml_banner_area'),
      left: 0,
      right: 0,
      top: isTop ? 0 : null,
      bottom: isTop ? null : 0,
      child: SafeArea(
        top: isTop,
        bottom: !isTop,
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedSwitcher(
            key: ValueKey(_bannerGeneration),
            duration: widget.bannerAnimationDuration,
            switchInCurve: widget.bannerAnimationCurve,
            switchOutCurve: widget.bannerAnimationCurve,
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, isTop ? -1 : 1),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: banner,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checksRoute = _shouldCheckCurrentRoute();
    final isOffline = checksRoute && !_isConnected;
    final isBlocked = isOffline && !widget.useBanner;

    final _BannerKind? bannerKind;
    if (!checksRoute) {
      bannerKind = null;
    } else if (isOffline) {
      bannerKind =
          widget.useBanner && !_bannerDismissed ? _BannerKind.offline : null;
    } else {
      bannerKind = _showOnlineRestored ? _BannerKind.restored : null;
    }

    // The tree shape stays the same in every state so the child (often the
    // whole Navigator) keeps its state across connection changes.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        KeyedSubtree(
          key: const ValueKey('flml_content'),
          child: ExcludeFocus(
            excluding: isBlocked,
            child: ExcludeSemantics(
              excluding: isBlocked,
              child: IgnorePointer(
                ignoring: isBlocked,
                child: TickerMode(
                  enabled: !isBlocked,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
        if (isBlocked)
          Positioned.fill(
            key: const ValueKey('flml_offline_view'),
            child: _buildBlockingView(context),
          ),
        _buildBannerArea(context, bannerKind),
      ],
    );
  }
}

import 'package:flutter/widgets.dart';

/// A navigator observer that tracks the current route.
///
/// Register this observer in your MaterialApp or router settings:
/// ```dart
/// MaterialApp(
///   navigatorObservers: [InternetCheckerObserver()],
///   // or GoRouter(observers: [InternetCheckerObserver()])
/// )
/// ```
class InternetCheckerObserver extends NavigatorObserver {
  // Private constructor
  InternetCheckerObserver._internal();

  /// The singleton instance of [InternetCheckerObserver].
  static final InternetCheckerObserver instance = InternetCheckerObserver._internal();

  /// Factory constructor to return the singleton instance.
  factory InternetCheckerObserver() => instance;

  /// Holds the current route name.
  final ValueNotifier<String?> currentRouteName = ValueNotifier<String?>(null);

  /// Holds the current route settings.
  final ValueNotifier<RouteSettings?> currentRouteSettings = ValueNotifier<RouteSettings?>(null);

  /// Holds the current Route object itself.
  final ValueNotifier<Route<dynamic>?> currentRoute = ValueNotifier<Route<dynamic>?>(null);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _updateRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _updateRoute(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _updateRoute(newRoute);
    }
  }

  void _updateRoute(Route<dynamic> route) {
    currentRouteName.value = route.settings.name;
    currentRouteSettings.value = route.settings;
    currentRoute.value = route;
  }
}

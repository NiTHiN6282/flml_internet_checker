import 'package:flutter/widgets.dart';

/// A navigator observer that tracks the current page route.
///
/// Register this observer in your MaterialApp or router settings:
/// ```dart
/// MaterialApp(
///   navigatorObservers: [InternetCheckerObserver()],
///   // or GoRouter(observers: [InternetCheckerObserver()])
/// )
/// ```
///
/// Popup routes (dialogs, bottom sheets, menus) are ignored, so opening a
/// dialog on an excluded route keeps that route's rules in effect.
///
/// This is a singleton and a [NavigatorObserver] can only be attached to one
/// [Navigator] at a time, so register it on your root navigator only.
class InternetCheckerObserver extends NavigatorObserver {
  // Private constructor
  InternetCheckerObserver._internal();

  /// The singleton instance of [InternetCheckerObserver].
  static final InternetCheckerObserver instance =
      InternetCheckerObserver._internal();

  /// Factory constructor to return the singleton instance.
  factory InternetCheckerObserver() => instance;

  /// Holds the current route name.
  final ValueNotifier<String?> currentRouteName = ValueNotifier<String?>(null);

  /// Holds the current route settings.
  final ValueNotifier<RouteSettings?> currentRouteSettings =
      ValueNotifier<RouteSettings?>(null);

  /// Holds the current Route object itself.
  final ValueNotifier<Route<dynamic>?> currentRoute =
      ValueNotifier<Route<dynamic>?>(null);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _updateRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null && route is! PopupRoute) {
      _updateRoute(previousRoute);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (previousRoute != null && identical(route, currentRoute.value)) {
      _updateRoute(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    // Only track replacements of the current route, not of routes below it.
    if (newRoute != null &&
        (currentRoute.value == null ||
            identical(oldRoute, currentRoute.value))) {
      _updateRoute(newRoute);
    }
  }

  void _updateRoute(Route<dynamic> route) {
    // Overlays such as dialogs and bottom sheets don't change the page.
    if (route is PopupRoute) return;
    currentRouteName.value = route.settings.name;
    currentRouteSettings.value = route.settings;
    currentRoute.value = route;
  }
}

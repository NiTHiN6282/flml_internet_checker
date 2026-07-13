## 3.0.0

- **Parallel Concurrency**: Probes DNS and TCP connections concurrently, reducing offline verification times up to 7x (from 20s+ to under 3s).
- **Zero-Dependency Web Support**: Restored full Web platform compatibility using conditional compilation and HTML window/HTTP checks without adding any external dependencies.
- **Connection Restored Success Banner**: Added a brief, custom green "Back Online" banner that automatically notifies the user when connection is recovered.
- **Dismissible Banners**: Enabled swipe-to-dismiss and close-button control on non-blocking offline banners so users can bypass them and view cached data.
- **Custom Animations**: Added controls to customize banner transition curves, entrance/exit animation durations, and show durations.
- **Extended Test Suite**: Added widget testing coverage for new dismissible, swipe, and properties default behaviors.

## 2.0.1

- Fixed `setState() or markNeedsBuild() called during build` exception when pushing/popping routes using `InternetCheckerObserver`.
- Added widget test coverage for route change behavior.

## 2.0.0

- **Breaking Change**: Completely removed the third-party dependency `internet_connection_checker_plus`.
- Added pure Dart connectivity checker (`FLMLInternetChecker`) using Socket connections (port 53) and DNS host lookups.
- Added global checking support via `MaterialApp.builder` and `InternetCheckerObserver`.
- Added route-based filtering (blacklist/whitelist) supporting GoRouter, AutoRoute, and custom Navigator setups.
- Added custom filtering predicate `shouldCheckRoute(Route)` to support anonymous/normal route matching.
- Added non-blocking banner/toast mode (`useBanner`) showing floating alerts at the top or bottom of the screen.
- Added lifecycle-aware checking to optimize device battery by pausing checking in the background.
- Added built-in Retry button with loading spinner on the offline error screen.

## 1.0.0

- sdk version lowered to 2.15.0
- internet_connection_checker_plus package upgraded to 2.7.0
- removed google fonts
- TextStyle property added

## 0.0.9

- sdk version lowered to 2.17.0

## 0.0.7

- Showing no internet in first time issue fixed!

## 0.0.6

- Web support enabled, retry button removed

## 0.0.4

- README.md updated

## 0.0.3

- placeholder added, example updated

## 0.0.2

- environment sdk changed to 3.0.0

## 0.0.1

- Initial Release
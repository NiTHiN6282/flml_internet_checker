## 4.0.0

### Bug fixes
- **Navigation state is preserved while offline**: the child (e.g. the whole `Navigator` in `MaterialApp.builder`) is no longer removed from the tree when the offline screen or banner appears. Previously, every connection drop reset the app to its initial route and discarded scroll positions and form input.
- **Dialogs no longer break route exclusions**: `InternetCheckerObserver` ignores popup routes (dialogs, bottom sheets, menus), so opening a dialog on an excluded route no longer triggers the offline screen. Added `didRemove` handling and fixed `didReplace` for routes below the top.
- **Banner animations now work**: `bannerAnimationDuration` and `bannerAnimationCurve` previously had no effect. Banners now slide and fade in and out.
- **Web on WASM**: the web implementation used `dart:html`, so WASM builds fell back to a stub that threw `UnimplementedError`. It now uses `dart:js_interop` and works with both dart2js and dart2wasm.
- **No more DNS-cache false positives**: hosts are now verified with a real TCP handshake on port 443 instead of `InternetAddress.lookup`, which could succeed from the OS DNS cache while offline.
- **Listening without the widget works**: `FLMLInternetChecker.instance.onStatusChange.listen(...)` now starts polling automatically. Previously, nothing was emitted unless an `InternetChecker` widget was mounted.
- Fixed a race where the "Connection Restored" banner could be skipped after tapping Retry.
- `onOfflineModeChanged` now fires only on actual changes.
- Errors thrown during a check no longer escape as unhandled exceptions; they count as offline.
- Overlapping checks (polling, retry, app resume) now share one in-flight probe, so results can't be applied out of order.

### Improvements
- **Faster offline detection**: all probes (hosts + IPs) now race in parallel with a single deadline. A fully offline check takes at most `timeout` (3s), down from up to 2x `timeout`.
- **IPv6 support**: added Google and Cloudflare IPv6 DNS servers to the default probes for IPv6-only networks.
- **Instant web updates**: browser `online`/`offline` events trigger an immediate check.
- **New `InternetConnectionBuilder` widget**: rebuilds any part of your UI when connectivity changes.
- **New `customCheck` option**: replace the built-in probes with your own check (e.g. a health check against your backend).
- **Dark mode**: the default offline screen adapts to dark themes.
- New `internetConnectionDescription` parameter to customize or hide the subtitle on the offline screen.
- New `FLMLInternetChecker.status`, `isPolling`, `defaultLookupHosts` and `defaultIpAddresses`.
- The offline screen blocks focus, semantics and tickers of the content behind it, and the Android back button now navigates the app underneath instead of exiting.
- Added pub.dev topics, a homepage and an issue tracker.

### Breaking changes
- Requires Dart 3.5 / Flutter 3.24 or newer.
- `InternetChecker.backgroundColor` is now nullable (`Color?`) and defaults to a theme-aware color.
- `lookupHosts` are now probed with TCP connections on port 443 instead of DNS lookups.

## 3.0.1

- Fixed static analysis linter warnings regarding missing braces in configure statements.
- Fixed deprecated and web-only library warning reports in web platform checkers.

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
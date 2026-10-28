# FLML Internet Checker

A lightweight, zero-dependency, and highly customizable Flutter package to monitor **real internet access** (not just "connected to Wi-Fi"). Wrap your entire app (global mode) or individual screens (local mode) to automatically handle offline states with blocking error pages or sleek non-blocking banner alerts.

---

## Key Features

* **Zero Dependencies**: Pure Dart implementation. No platform plugins, no native code.
* **Real Reachability**: Verifies actual internet access with parallel TCP handshakes to well-known hosts and public DNS servers (IPv4 + IPv6). Avoids false positives from cached DNS lookups or Wi-Fi networks without internet access.
* **Fast**: All probes race in parallel. Online is usually confirmed in milliseconds, and offline is detected within the timeout (3s by default).
* **All Platforms**: Android, iOS, macOS, Windows, Linux and Web, including **WASM**.
* **Keeps Your App State**: The offline screen is drawn *over* your app, so the navigation stack, scroll positions and form input survive connection drops.
* **Global App Wrapper**: Run a single checker at the root of your application (using `MaterialApp.builder`).
* **Route Filtering**: Exclusions (blacklist), inclusions (whitelist) or a custom predicate. Works with `GoRouter`, `AutoRoute` and anonymous routes. Dialogs and bottom sheets don't affect route rules.
* **Non-Blocking Banners**: Animated floating alerts at the top or bottom of the screen, optionally dismissible, plus a "Connection Restored" banner.
* **Reactive Builder**: `InternetConnectionBuilder` rebuilds any widget when connectivity changes.
* **Lifecycle-Aware**: Pauses checking in the background to save battery and re-checks immediately on resume.
* **Pluggable**: Use your own backend health check via `customCheck`.
* **Dark Mode**: The default offline screen adapts to your theme.

---

## Getting Started

### 1. Install

```yaml
dependencies:
  flml_internet_checker: ^4.0.0
```

### 2. Setup Permissions

#### Android
Add the following permission to your `AndroidManifest.xml` file:
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

#### macOS
Add the following permission to your macOS `.entitlements` files:
```xml
<key>com.apple.security.network.client</key>
<true/>
```

### 3. Wrap Your App

```dart
MaterialApp(
  navigatorObservers: [InternetCheckerObserver()], // Enables route rules
  builder: (context, child) => InternetChecker(child: child!),
  home: const HomeScreen(),
);
```

That's it. When the device loses internet access, a full-screen offline page with a retry button is shown. When access comes back, a "Connection Restored" banner appears and the user is exactly where they left off.

---

## Usage Examples

### Example 1: Global App Checker (MaterialApp.builder)
Wrap your entire app using the builder property. You can blacklist specific routes (like onboarding, splash, or local pages) that should remain accessible offline.

```dart
import 'package:flml_internet_checker/flml_internet_checker.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [InternetCheckerObserver()], // 1. Register observer
      builder: (context, child) {
        return InternetChecker(
          // 2. Exclude offline-friendly screens
          excludeRoutes: const ['/splash', '/local_settings'],
          internetConnectionText: "Whoops! No Internet",
          showRetryButton: true,
          retryButtonText: "Reload",
          child: child!,
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/splash': (context) => const SplashScreen(),
        '/local_settings': (context) => const SettingsScreen(),
      },
    );
  }
}
```

### Example 2: Screen-Specific Non-Blocking Banner
Display a sleek floating banner at the bottom or top of a specific screen while still allowing the user to view and interact with the page:

```dart
class CachedFeedScreen extends StatelessWidget {
  const CachedFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return InternetChecker(
      useBanner: true, // Enable floating alert
      bannerLocation: InternetCheckerBannerLocation.bottom, // Place at bottom
      bannerText: "Offline Mode. Interacting with local cached data.",
      bannerBackgroundColor: Colors.deepOrange,
      dismissibleBanner: true, // Swipe or tap X to hide
      child: Scaffold(
        appBar: AppBar(title: const Text("News Feed")),
        body: ListView.builder(
          itemCount: 20,
          itemBuilder: (context, index) => ListTile(
            title: Text("Offline cached news item #$index"),
          ),
        ),
      ),
    );
  }
}
```

### Example 3: React to Connectivity Anywhere in the UI
Use `InternetConnectionBuilder` to adapt individual widgets without blocking the screen:

```dart
InternetConnectionBuilder(
  builder: (context, isConnected) {
    return ElevatedButton(
      onPressed: isConnected ? _submitOrder : null,
      child: Text(isConnected ? 'Place Order' : 'Waiting for connection...'),
    );
  },
)
```

### Example 4: Routing with Anonymous / Custom Routes
If you navigate using anonymous routes, pass the custom filter callback `shouldCheckRoute` to evaluate the actual `Route` object:

```dart
InternetChecker(
  shouldCheckRoute: (route) {
    // Exclude certain route class types
    if (route is LocalPageRoute) {
      return false;
    }
    // Or inspect settings names dynamically
    if (route.settings.name == '/offline_page') {
      return false;
    }
    return true;
  },
  child: child!,
)
```

### Example 5: Listen to State Globally (No UI)
Use the singleton engine to inspect or listen to connection status programmatically. Listening starts the checker automatically, with no widget required:

```dart
// 1. Get current status directly
bool isDeviceConnected = FLMLInternetChecker.instance.isConnected;

// 2. Listen to real-time changes
final subscription =
    FLMLInternetChecker.instance.onStatusChange.listen((bool isConnected) {
  if (isConnected) {
    print("Internet reconnected! Syncing database...");
  } else {
    print("Device went offline.");
  }
});

// 3. Trigger manual re-check
bool online = await FLMLInternetChecker.instance.checkNow();
```

### Example 6: Check Your Own Backend
Replace the built-in probes with your own check, for example a health endpoint using `package:http`:

```dart
FLMLInternetChecker.instance.configure(
  customCheck: () async {
    final response = await http.head(Uri.parse('https://api.example.com/health'));
    return response.statusCode < 500;
  },
);
```

`customCheck` is also handy in tests: `FLMLInternetChecker.instance.customCheck = () async => false;` simulates being offline.

---

## API Properties Reference

### `InternetChecker` Widget

| Property | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **Required** | The widget displayed when online or when checks are bypassed. |
| `placeHolder` | `Widget?` | `null` | Custom widget to display when offline in blocking mode (ignores all standard styles if provided). |
| `internetConnectionText` | `String` | `"No Internet Connection"` | Title shown on the default blocking offline screen. |
| `internetConnectionDescription` | `String?` | `"Please check your internet settings and try again."` | Subtitle on the default blocking offline screen. `null` hides it. |
| `textStyle` | `TextStyle?` | `null` | Custom style for the default blocking screen title. |
| `backgroundColor` | `Color?` | White / dark surface | Background color for the default blocking screen. Adapts to dark themes when `null`. |
| `useBanner` | `bool` | `false` | If `true`, shows a floating banner instead of blocking the page. |
| `bannerText` | `String` | `"No Internet Connection"` | Text displayed inside the default banner. |
| `bannerTextStyle` | `TextStyle?` | `null` | TextStyle for the banner message. |
| `bannerBackgroundColor` | `Color?` | `Color(0xFFD32F2F)` | Background color for the default banner. |
| `bannerLocation` | `InternetCheckerBannerLocation` | `bottom` | The position of the banner (`top` or `bottom`). |
| `bannerBuilder` | `Widget Function(BuildContext, bool)?` | `null` | Builder to draw a completely customized offline banner (animated automatically). |
| `excludeRoutes` | `List<String>?` | `null` | Blacklist of routes that should never trigger the offline UI. |
| `includeRoutes` | `List<String>?` | `null` | Whitelist of routes; if set, only these routes trigger checking. |
| `shouldCheckRoute` | `bool Function(Route)?` | `null` | Advanced custom callback to filter routes dynamically. |
| `showRetryButton` | `bool` | `true` | Show/hide the manual retry button on the offline page. |
| `retryButtonText` | `String` | `"Retry"` | Text shown on the retry button. |
| `retryButtonStyle` | `ButtonStyle?` | `null` | Style for the retry button. |
| `onOfflineModeChanged` | `ValueChanged<bool>?` | `null` | Fired when the device goes offline (`true`) or online (`false`). |
| `showOnlineRestoredBanner` | `bool` | `true` | Show a brief green banner when internet connection is restored. |
| `onlineRestoredText` | `String` | `"Internet Connection Restored"` | Text displayed inside the restored banner. |
| `onlineRestoredTextStyle` | `TextStyle?` | `null` | TextStyle for the connection restored banner. |
| `onlineRestoredBackgroundColor`| `Color?` | `Color(0xFF2E7D32)` | Background color for the restored banner. |
| `onlineRestoredDuration` | `Duration` | `Duration(seconds: 3)` | Duration to show the restored banner before auto-dismissing. |
| `dismissibleBanner` | `bool` | `false` | If `true`, the offline banner can be dismissed by swiping or clicking close. |
| `onBannerDismissed` | `VoidCallback?` | `null` | Callback triggered when the offline banner is manually dismissed. |
| `bannerAnimationDuration` | `Duration` | `Duration(milliseconds: 300)` | Duration for banner entrance and exit animations. |
| `bannerAnimationCurve` | `Curve` | `Curves.fastOutSlowIn` | Curve for the banner slide animation. |

### `InternetConnectionBuilder` Widget

| Property | Type | Description |
|---|---|---|
| `builder` | `Widget Function(BuildContext, bool isConnected)` | Called whenever the connection status changes. |

---

### `FLMLInternetChecker` Engine (Singleton)

| Property/Method | Return Type | Description |
|---|---|---|
| `FLMLInternetChecker.instance` | `FLMLInternetChecker` | Accesses the shared singleton instance. |
| `isConnected` | `bool` | The last known connectivity state (`true` until the first check completes). |
| `status` | `InternetConnectionStatus` | The same state as an enum (`connected` / `disconnected`). |
| `onStatusChange` | `Stream<bool>` | Broadcast stream of connection changes. Listening starts polling automatically. |
| `configure(...)` | `void` | Modifies hosts, ping addresses, timeouts, poll intervals and the custom check. |
| `checkNow()` | `Future<bool>` | Triggers an immediate connection check and updates state. |
| `startPolling()` | `void` | Starts the periodic connection checking daemon. |
| `stopPolling()` | `void` | Stops the periodic checking daemon. |
| `isPolling` | `bool` | Whether periodic checking is active. |
| `defaultLookupHosts` / `defaultIpAddresses` | `List<String>` | The built-in probe targets, handy for extending them. |

#### Configuration Parameters
You can customize the engine's checking rules using `configure()`:
```dart
FLMLInternetChecker.instance.configure(
  lookupHosts: ['dns.google', 'github.com'], // Hosts probed via TCP on port 443 (HTTPS on Web)
  ipAddresses: ['8.8.8.8', '1.1.1.1'],      // IPs probed via TCP on `port`
  port: 53,                                 // Port for ipAddresses
  timeout: const Duration(seconds: 3),      // Max duration of one check
  checkIntervalOnline: const Duration(seconds: 30), // Poll frequency when online
  checkIntervalOffline: const Duration(seconds: 5), // Poll frequency when offline
  customCheck: null,                        // Optional: your own check
);
```

To add your own host while keeping the defaults:
```dart
FLMLInternetChecker.instance.configure(
  lookupHosts: [...FLMLInternetChecker.defaultLookupHosts, 'api.example.com'],
);
```

---

## How It Works

* **Mobile & Desktop**: Opens TCP connections in parallel to every `lookupHosts` entry (port 443) and every `ipAddresses` entry (port `port`). The first successful handshake means online. If none succeeds within `timeout`, the device is offline. Sockets are closed immediately.
* **Web**: Browsers don't allow raw sockets. The checker returns offline immediately if `navigator.onLine` is `false`. Otherwise it races lightweight `no-cors` HEAD requests to the `lookupHosts` (over HTTPS) and to your app's own origin. Browser `online`/`offline` events trigger an immediate re-check. If your app uses a strict Content-Security-Policy, allow the probe hosts in `connect-src` or use `customCheck`.
* **Polling**: Every 15s while online and every 5s while offline (configurable). Polling pauses while the app is in the background when an `InternetChecker` widget is mounted.

---

## Migrating from 3.x to 4.0

* Requires Dart 3.5 / Flutter 3.24 or newer.
* `backgroundColor` is now `Color?`. Passing a color works exactly as before; omitting it now adapts to dark themes.
* `lookupHosts` are probed with TCP connections on port 443 instead of DNS lookups. If you configured custom hosts, make sure they accept HTTPS connections.
* No other code changes are required.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

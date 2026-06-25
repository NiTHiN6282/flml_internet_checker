# FLML Internet Checker

A lightweight, zero-dependency, and highly customizable Flutter package to monitor internet connectivity. You can easily wrap your entire app (global mode) or individual screens (local mode) to automatically handle offline states with blocking error pages or sleek non-blocking banner alerts.

---

## Key Features

* **Zero Dependencies**: Pure Dart implementation using Socket connections and DNS lookups. No reliance on platform-specific packages.
* **Global App Wrapper**: Run a single checker at the root of your application (using `MaterialApp.builder`).
* **Route Filtering**: Supports exclusions (blacklist) and inclusions (whitelist) for route-specific checking. Fully compatible with `GoRouter`, `AutoRoute`, and anonymous/custom routes.
* **Non-Blocking Banner Alerts**: Option to show floating alerts at the top or bottom of the screen instead of blocking the entire page.
* **Lifecycle-Aware Checking**: Pauses checking when the app is in the background to save battery, and runs immediate checks when the app is resumed.
* **Interactive Retry Action**: Built-in, modern retry button with a loading state to re-verify connectivity instantly.
* **Access Anywhere**: Listen to the stream or query the connection status globally from your code without UI widgets.

---

## Getting Started

### 1. Setup Permissions

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

### 2. Register Router Observer (Required for Global Mode)
For route-based exclusion/inclusion to work, register `InternetCheckerObserver` in your `MaterialApp` or router configuration:

```dart
MaterialApp(
  navigatorObservers: [InternetCheckerObserver()],
  // ...
)
```

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
import 'package:flml_internet_checker/flml_internet_checker.dart';
import 'package:flutter/material.dart';

class CachedFeedScreen extends StatelessWidget {
  const CachedFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return InternetChecker(
      useBanner: true, // Enable floating alert
      bannerLocation: InternetCheckerBannerLocation.bottom, // Place at bottom
      bannerText: "Offline Mode. Interacting with local cached data.",
      bannerBackgroundColor: Colors.deepOrange,
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

### Example 3: Routing with Anonymous / Custom Routes
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

### Example 4: Listen to State Globally (No UI)
Use the singleton engine to inspect or listen to connection status programmatically:

```dart
// 1. Get current status directly
bool isDeviceConnected = FLMLInternetChecker.instance.isConnected;

// 2. Listen to real-time changes
FLMLInternetChecker.instance.onStatusChange.listen((bool isConnected) {
  if (isConnected) {
    print("Internet reconnected! Syncing database...");
  } else {
    print("Device went offline.");
  }
});

// 3. Trigger manual re-check
await FLMLInternetChecker.instance.checkNow();
```

---

## API Properties Reference

### `InternetChecker` Widget

| Property | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **Required** | The widget displayed when online or when checks are bypassed. |
| `placeHolder` | `Widget?` | `null` | Custom widget to display when offline in blocking mode (ignores all standard styles if provided). |
| `internetConnectionText` | `String` | `"No Internet Connection"` | Text shown on the default blocking offline screen. |
| `textStyle` | `TextStyle?` | `null` | Custom style for the default blocking screen text. |
| `backgroundColor` | `Color` | `Colors.white` | Background color for the default blocking screen. |
| `useBanner` | `bool` | `false` | If `true`, shows a floating banner instead of blocking the page. |
| `bannerText` | `String` | `"No Internet Connection"` | Text displayed inside the default banner. |
| `bannerTextStyle` | `TextStyle?` | `null` | TextStyle for the banner message. |
| `bannerBackgroundColor` | `Color?` | `Color(0xFFD32F2F)` | Background color for the default banner. |
| `bannerLocation` | `InternetCheckerBannerLocation` | `bottom` | The position of the banner (`top` or `bottom`). |
| `bannerBuilder` | `Widget Function(BuildContext, bool)?` | `null` | Builder to draw a completely customized banner. |
| `excludeRoutes` | `List<String>?` | `null` | Blacklist of routes that should never trigger the offline UI. |
| `includeRoutes` | `List<String>?` | `null` | Whitelist of routes; if set, only these routes trigger checking. |
| `shouldCheckRoute` | `bool Function(Route)?` | `null` | Advanced custom callback to filter routes dynamically. |
| `showRetryButton` | `bool` | `true` | Show/hide the manual retry button on the offline page. |
| `retryButtonText` | `String` | `"Retry"` | Text shown on the retry button. |
| `retryButtonStyle` | `ButtonStyle?` | `null` | Style for the retry button. |
| `onOfflineModeChanged` | `ValueChanged<bool>?` | `null` | Fired when the device goes offline (`true`) or online (`false`). |

---

### `FLMLInternetChecker` Engine (Singleton)

| Property/Method | Return Type | Description |
|---|---|---|
| `FLMLInternetChecker.instance` | `FLMLInternetChecker` | Accesses the shared singleton instance. |
| `isConnected` | `bool` | Queries the current connectivity state. |
| `onStatusChange` | `Stream<bool>` | Stream broadcasting real-time connection status updates. |
| `configure(...)` | `void` | Modifies hosts, ping addresses, timeouts, and poll intervals. |
| `checkNow()` | `Future<bool>` | Triggers an immediate connection check and updates state. |
| `startPolling()` | `void` | Starts the periodic connection checking daemon. |
| `stopPolling()` | `void` | Stops the periodic checking daemon. |

#### Configuration Parameters
You can customize the engine's checking rules using `configure()`:
```dart
FLMLInternetChecker.instance.configure(
  lookupHosts: ['dns.google', 'github.com'], // Domains to resolve DNS
  ipAddresses: ['8.8.8.8', '1.1.1.1'],      // IPs to connect via Socket TCP
  port: 53,                                 // Target port
  timeout: const Duration(seconds: 3),      // Timeout per address
  checkIntervalOnline: const Duration(seconds: 30), // Poll frequency when online
  checkIntervalOffline: const Duration(seconds: 5), // Poll frequency when offline
);
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

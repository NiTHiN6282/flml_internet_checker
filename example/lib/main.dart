import 'package:flml_internet_checker/flml_internet_checker.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FLML Internet Checker Example',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      // 1. Register the InternetCheckerObserver to track current routes.
      // This works with standard routes, GoRouter, AutoRoute, etc.
      navigatorObservers: [InternetCheckerObserver()],
      
      // 2. Wrap the entire app using the builder to make it a global checker.
      builder: (context, child) {
        return InternetChecker(
          // Define routes that should NOT block the user when offline (blacklist)
          excludeRoutes: const ['/local_page', '/banner_page'],
          
          // Custom placeholder details for blocking mode
          internetConnectionText: "No Internet Connection",
          textStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
          
          // Enable the built-in Retry button
          showRetryButton: true,
          retryButtonText: "Try Again",
          
          child: child!,
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/online_page': (context) => const CheckedScreen(),
        '/local_page': (context) => const ExcludedScreen(),
        '/banner_page': (context) => const BannerScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FLML Internet Checker'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card showing real-time connectivity status
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: StreamBuilder<bool>(
                  stream: FLMLInternetChecker.instance.onStatusChange,
                  initialData: FLMLInternetChecker.instance.isConnected,
                  builder: (context, snapshot) {
                    final isOnline = snapshot.data ?? true;
                    return Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isOnline ? Colors.green[100] : Colors.red[100],
                          radius: 28,
                          child: Icon(
                            isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                            color: isOnline ? Colors.green : Colors.red,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Connection Status",
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            Text(
                              isOnline ? "Online" : "Offline",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isOnline ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "DEMO SCREENS",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.lock_outline),
              label: const Text("Go to Checked Screen (Full Block)"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => Navigator.pushNamed(context, '/online_page'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.offline_pin_outlined),
              label: const Text("Go to Offline-Friendly Screen (Bypassed)"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => Navigator.pushNamed(context, '/local_page'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.notification_important_outlined),
              label: const Text("Go to Banner Screen (Non-blocking alert)"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => Navigator.pushNamed(context, '/banner_page'),
            ),
            const Spacer(),
            Center(
              child: Text(
                "Try turning off your WiFi or mobile data to see the transitions!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class CheckedScreen extends StatelessWidget {
  const CheckedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Only Page'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          "If you are seeing this, you are online!\nIf you go offline, a blocking screen will appear.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

class ExcludedScreen extends StatelessWidget {
  const ExcludedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline-Friendly Page'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            "This route is whitelisted/bypassed in the global InternetChecker configurations!\n\nEven if you turn off your connection, you will not be blocked from this screen.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class BannerScreen extends StatelessWidget {
  const BannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // We wrap this screen locally using useBanner = true.
    // We excluded '/banner_page' from the global builder so that the global full-screen block
    // doesn't intercept this screen.
    return InternetChecker(
      useBanner: true,
      bannerText: "Offline Mode. Showing cached data.",
      bannerLocation: InternetCheckerBannerLocation.bottom,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Banner Alerts Page'),
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              "This screen uses a non-blocking banner at the bottom when offline.\n\nYou can still type, scroll, and interact with the UI normally while offline.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}

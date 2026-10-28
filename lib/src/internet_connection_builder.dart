import 'package:flutter/widgets.dart';

import 'connection_checker.dart';

/// Rebuilds whenever the internet connection status changes.
///
/// Use it to adapt any part of your UI to connectivity without blocking the
/// screen, e.g. disabling a "Send" button or showing an offline badge:
/// ```dart
/// InternetConnectionBuilder(
///   builder: (context, isConnected) => ElevatedButton(
///     onPressed: isConnected ? _send : null,
///     child: Text(isConnected ? 'Send' : 'Offline'),
///   ),
/// )
/// ```
///
/// Connection checking starts automatically while this widget is mounted.
class InternetConnectionBuilder extends StatelessWidget {
  /// Builds the widget for the current connection state.
  final Widget Function(BuildContext context, bool isConnected) builder;

  const InternetConnectionBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final checker = FLMLInternetChecker.instance;
    return StreamBuilder<bool>(
      stream: checker.onStatusChange,
      initialData: checker.isConnected,
      builder: (context, snapshot) =>
          builder(context, snapshot.data ?? checker.isConnected),
    );
  }
}

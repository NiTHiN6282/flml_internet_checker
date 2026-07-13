// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

/// Verifies connectivity on Web platforms using browser APIs and lightweight HTTP pings.
Future<bool> platformCheckConnection({
  required List<String> lookupHosts,
  required List<String> ipAddresses,
  required int port,
  required Duration timeout,
}) async {
  // 1. Check navigator.onLine first
  if (html.window.navigator.onLine == false) {
    return false;
  }

  // 2. Perform a lightweight HTTP check to verify actual internet access.
  // Since we cannot run raw DNS/TCP checks in the browser due to CORS/sandboxing,
  // we ping the same-origin hosting origin or CORS-friendly public APIs.
  try {
    final origin = html.window.location.origin;
    final uri = Uri.parse(origin).replace(
      queryParameters: {
        '_cb': DateTime.now().millisecondsSinceEpoch.toString()
      },
    );

    final request = await html.HttpRequest.request(
      uri.toString(),
      method: 'HEAD',
    ).timeout(timeout);

    if (request.status != null && request.status! > 0) {
      return true;
    }
  } catch (_) {
    // If same-origin ping fails, try a fallback to a public CORS-friendly API like GitHub
    try {
      final request = await html.HttpRequest.request(
        'https://api.github.com',
        method: 'HEAD',
      ).timeout(timeout);

      if (request.status != null && request.status! > 0) {
        return true;
      }
    } catch (_) {}
  }

  return false;
}

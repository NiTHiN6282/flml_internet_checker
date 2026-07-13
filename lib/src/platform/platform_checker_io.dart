import 'dart:async';
import 'dart:io';

/// Verifies connectivity by checking lookup hosts and IP addresses concurrently.
Future<bool> platformCheckConnection({
  required List<String> lookupHosts,
  required List<String> ipAddresses,
  required int port,
  required Duration timeout,
}) async {
  // 1. Try DNS lookups for configured hosts in parallel
  if (lookupHosts.isNotEmpty) {
    final completer = Completer<bool>();
    int remaining = lookupHosts.length;

    for (final host in lookupHosts) {
      InternetAddress.lookup(host).timeout(timeout).then((result) {
        if (completer.isCompleted) return;
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          completer.complete(true);
        } else {
          remaining--;
          if (remaining == 0) {
            completer.complete(false);
          }
        }
      }).catchError((_) {
        if (completer.isCompleted) return;
        remaining--;
        if (remaining == 0) {
          completer.complete(false);
        }
      });
    }

    final dnsSuccess = await completer.future;
    if (dnsSuccess) return true;
  }

  // 2. Try socket connection to configured IPs on port 53 in parallel (fallback)
  if (ipAddresses.isNotEmpty) {
    final completer = Completer<bool>();
    int remaining = ipAddresses.length;

    for (final ip in ipAddresses) {
      Socket.connect(ip, port, timeout: timeout).then((socket) {
        socket.destroy();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }).catchError((_) {
        if (!completer.isCompleted) {
          remaining--;
          if (remaining == 0) {
            completer.complete(false);
          }
        }
      });
    }

    return await completer.future;
  }

  return false;
}

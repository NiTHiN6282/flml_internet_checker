import 'dart:async';
import 'dart:io';

/// Verifies connectivity by racing TCP connections to every configured target.
///
/// Hostnames in [lookupHosts] are connected to on port 443 (this resolves DNS
/// *and* completes a TCP handshake, so a stale OS DNS cache cannot produce a
/// false positive). IPs in [ipAddresses] are connected to on [port].
///
/// All probes run in parallel and the first successful handshake wins, so the
/// worst case (fully offline) takes at most [timeout].
Future<bool> platformCheckConnection({
  required List<String> lookupHosts,
  required List<String> ipAddresses,
  required int port,
  required Duration timeout,
}) async {
  final targets = <(String, int)>[
    for (final host in lookupHosts) (host, 443),
    for (final ip in ipAddresses) (ip, port),
  ];
  if (targets.isEmpty) return false;

  final completer = Completer<bool>();
  final tasks = <ConnectionTask<Socket>>[];
  var pending = targets.length;

  void onFailure(Object _) {
    pending--;
    if (pending == 0 && !completer.isCompleted) {
      completer.complete(false);
    }
  }

  // A single deadline for the whole race. It also covers the DNS resolution
  // performed by `Socket.startConnect` before the connection task exists.
  final deadline = Timer(timeout, () {
    if (!completer.isCompleted) completer.complete(false);
  });

  for (final (host, targetPort) in targets) {
    Socket.startConnect(host, targetPort).then((task) {
      if (completer.isCompleted) {
        task.cancel();
      } else {
        tasks.add(task);
      }
      task.socket.then((socket) {
        socket.destroy();
        if (!completer.isCompleted) completer.complete(true);
      }, onError: onFailure);
    }, onError: onFailure);
  }

  final result = await completer.future;
  deadline.cancel();
  // Abort the probes that are still connecting; their sockets are not needed.
  for (final task in tasks) {
    task.cancel();
  }
  return result;
}

/// Native platforms have no zero-dependency connectivity change events, so
/// changes are detected by polling only.
void platformListenForChanges(void Function() onChanged) {}

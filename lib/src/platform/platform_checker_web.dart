import 'dart:async';
import 'dart:js_interop';

/// Verifies connectivity on the Web using browser APIs.
///
/// Raw DNS/TCP sockets are not available in the browser, so this:
/// 1. Returns `false` immediately when `navigator.onLine` is `false`.
/// 2. Races `no-cors` HEAD requests to every host in [lookupHosts] (over
///    HTTPS) and to the page's own origin. The first request that reaches a
///    server wins. `no-cors` requests resolve for any HTTP status and only
///    fail on network errors, so CORS headers are not required.
///
/// [ipAddresses] and [port] are ignored on the Web. Built with
/// `dart:js_interop`, so it works with both dart2js and dart2wasm.
Future<bool> platformCheckConnection({
  required List<String> lookupHosts,
  required List<String> ipAddresses,
  required int port,
  required Duration timeout,
}) async {
  if (!_navigator.onLine) return false;

  final cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
  final urls = <String>[
    for (final host in lookupHosts) 'https://$host/?_flml=$cacheBuster',
    if (_originProbeUrl(cacheBuster) case final origin?) origin,
  ];
  if (urls.isEmpty) return false;

  final completer = Completer<bool>();
  final controller = _AbortController();
  var pending = urls.length;

  void onFailure(Object _) {
    pending--;
    if (pending == 0 && !completer.isCompleted) {
      completer.complete(false);
    }
  }

  final deadline = Timer(timeout, () {
    if (!completer.isCompleted) completer.complete(false);
  });

  final init = _RequestInit(
    method: 'HEAD'.toJS,
    mode: 'no-cors'.toJS,
    cache: 'no-store'.toJS,
    signal: controller.signal,
  );
  for (final url in urls) {
    _fetch(url.toJS, init).toDart.then((_) {
      if (!completer.isCompleted) completer.complete(true);
    }, onError: onFailure);
  }

  final result = await completer.future;
  deadline.cancel();
  controller.abort();
  return result;
}

/// Triggers [onChanged] when the browser fires `online` / `offline` events,
/// so changes are picked up immediately instead of on the next poll.
void platformListenForChanges(void Function() onChanged) {
  final listener = ((JSAny? _) => onChanged()).toJS;
  _window.addEventListener('online'.toJS, listener);
  _window.addEventListener('offline'.toJS, listener);
}

/// The page's own origin, unless it is served locally (a local dev server is
/// always reachable and would mask a missing internet connection).
String? _originProbeUrl(String cacheBuster) {
  final origin = Uri.tryParse(_window.location.origin);
  if (origin == null || !origin.isScheme('http') && !origin.isScheme('https')) {
    return null;
  }
  const loopbackHosts = {'localhost', '127.0.0.1', '[::1]', '::1'};
  if (loopbackHosts.contains(origin.host)) return null;
  return origin.replace(path: '/', query: '_flml=$cacheBuster').toString();
}

@JS('window')
external _Window get _window;

@JS('navigator')
external _Navigator get _navigator;

@JS('fetch')
external JSPromise<JSAny?> _fetch(JSString resource, _RequestInit options);

extension type _Window._(JSObject _) implements JSObject {
  external _Location get location;
  external void addEventListener(JSString type, JSFunction listener);
}

extension type _Location._(JSObject _) implements JSObject {
  external String get origin;
}

extension type _Navigator._(JSObject _) implements JSObject {
  external bool get onLine;
}

extension type _RequestInit._(JSObject _) implements JSObject {
  external factory _RequestInit({
    JSString method,
    JSString mode,
    JSString cache,
    JSObject signal,
  });
}

@JS('AbortController')
extension type _AbortController._(JSObject _) implements JSObject {
  external factory _AbortController();
  external JSObject get signal;
  external void abort();
}

Future<bool> platformCheckConnection({
  required List<String> lookupHosts,
  required List<String> ipAddresses,
  required int port,
  required Duration timeout,
}) {
  throw UnsupportedError(
    'flml_internet_checker is not supported on this platform.',
  );
}

void platformListenForChanges(void Function() onChanged) {}

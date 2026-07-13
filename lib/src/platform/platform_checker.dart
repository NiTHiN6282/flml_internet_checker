export 'platform_checker_stub.dart'
    if (dart.library.io) 'platform_checker_io.dart'
    if (dart.library.html) 'platform_checker_web.dart';

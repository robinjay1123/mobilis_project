/// Conditional HTML import handler.
/// Imports either the real dart:html (web) or stub implementation (mobile/desktop).
/// This uses Dart's conditional import feature: 'if (dart.library.html)'

export 'web_html_stub.dart' if (dart.library.html) 'web_html_real.dart';

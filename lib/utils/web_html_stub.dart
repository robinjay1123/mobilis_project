/// Stub implementation of dart:html for mobile/desktop platforms.
/// This file provides placeholder classes to prevent compilation errors
/// when dart:html is conditionally imported on non-web platforms.

class Blob {
  final List<dynamic> data;
  final String type;

  Blob(this.data, this.type);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

class AnchorElement {
  String? href;
  String? target;
  String? download;

  AnchorElement({this.href, this.target, this.download});

  void click() {}
  void remove() {}
}

class _DocumentStub {
  _BodyStub? get body => null;
}

class _BodyStub {
  void append(dynamic element) {}
}

final document = _DocumentStub();

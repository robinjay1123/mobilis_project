// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> exportCsvFile({
  required String fileName,
  required Uint8List bytes,
}) async {
  final blob = html.Blob(<Object>[bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    html.AnchorElement(href: url)
      ..download = fileName
      ..click();
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}

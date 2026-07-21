import 'dart:typed_data';

import 'csv_export_stub.dart'
    if (dart.library.html) 'csv_export_web.dart'
    as implementation;

Future<void> exportCsvFile({
  required String fileName,
  required Uint8List bytes,
}) => implementation.exportCsvFile(fileName: fileName, bytes: bytes);

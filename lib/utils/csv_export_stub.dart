import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<void> exportCsvFile({
  required String fileName,
  required Uint8List bytes,
}) async {
  await FilePicker.platform.saveFile(
    dialogTitle: 'Export report',
    fileName: fileName,
    bytes: bytes,
  );
}

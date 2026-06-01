import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadFile(List<int> bytes, String filename) async {
  if (bytes.isEmpty) return;
  final dir = await getTemporaryDirectory();
  final safeName = filename.replaceAll(RegExp(r'[^\w\-\.]'), '_');
  final file = File('${dir.path}/$safeName');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles(
    [
      XFile(
        file.path,
        mimeType: _mimeForFilename(filename),
        name: filename,
      ),
    ],
    subject: filename,
  );
}

String? _mimeForFilename(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  return null;
}

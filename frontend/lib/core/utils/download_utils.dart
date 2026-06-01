import 'download_stub.dart'
    if (dart.library.html) 'download_web.dart'
    if (dart.library.io) 'download_io.dart' as impl;

Future<void> downloadFile(List<int> bytes, String filename) async {
  await impl.downloadFile(bytes, filename);
}

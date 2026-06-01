// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> downloadFile(List<int> bytes, String filename) async {
  if (bytes.isEmpty) return;
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

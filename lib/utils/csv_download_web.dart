import 'dart:html' as html;

Future<bool> downloadCsvImpl(String filename, String content) async {
  try {
    final bytes = html.Blob([content], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(bytes);
    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (_) {
    return false;
  }
}

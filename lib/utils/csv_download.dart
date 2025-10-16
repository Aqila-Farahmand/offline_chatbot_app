// Platform-conditional CSV download helper
import 'csv_download_web.dart'
    if (dart.library.io) 'csv_download_stub.dart'
    as impl;

Future<bool> downloadCsv(String filename, String content) {
  return impl.downloadCsvImpl(filename, content);
}

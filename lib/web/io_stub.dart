// lib/web/io_stub.dart
// Stub usado en plataformas NO web.
import 'dart:typed_data';

class PickResult {
  final Uint8List bytes;
  final String filename;
  final String mime;
  
  PickResult(this.bytes, this.filename, this.mime);
  
}


Future<PickResult?> pickAnyFileWeb() async => null;
Future<PickResult?> capturePhotoWeb() async => null;
Future<PickResult?> captureVideoWeb() async => null;
bool get isSafari => false;
// --- Stubs para no-web (Android/iOS) ---
Future<PickResult?> pickImagesFromLibrary() async => null;
Future<PickResult?> pickVideosFromLibrary() async => null;
Future<void> saveToDeviceWeb({
  required Uint8List bytes,
  required String filename,
  required String mime,
}) async {}
Future<double?> probeVideoDurationSeconds(Uint8List bytes, {String? mime}) async => null;
Future<Uint8List?> generateVideoThumbnailWeb(Uint8List bytes, {String? mime}) async => null;
void promptDownloadFromUrlWeb(String url, {required String filename}) {
  // no-op fuera de web
}

Future<Uint8List?> transcodeImageToJpegWeb(Uint8List bytes, {double quality = 0.9}) async => null;

String forceInlineImageUrl(String url, {String? contentType, String? filename}) => url;

Future<Uint8List?> makeImageThumbnailJpegWeb(
  Uint8List bytes, {
  int maxWidth = 480,
  double quality = 0.8,
}) async => null;



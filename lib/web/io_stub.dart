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

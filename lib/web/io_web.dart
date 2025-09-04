// lib/web/io_web.dart
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

class PickResult {
  final Uint8List bytes;
  final String filename;
  final String mime; // ⬅️ nuevo
  PickResult(this.bytes, this.filename, this.mime);
}

bool get isSafari {
  final ua = html.window.navigator.userAgent.toLowerCase();
  return ua.contains('safari') &&
      !ua.contains('chrome') &&
      !ua.contains('crios') &&
      !ua.contains('fxios');
}

Future<PickResult?> _readFile(html.File file) async {
  final r = html.FileReader();
  final done = Completer<void>();
  r.onLoadEnd.listen((_) => done.complete());
  r.readAsArrayBuffer(file);
  await done.future;

  final result = r.result;
  late Uint8List bytes;
  if (result is ByteBuffer) {
    bytes = Uint8List.view(result);
  } else if (result is Uint8List) {
    bytes = result;
  } else {
    throw StateError('Tipo no soportado: ${result.runtimeType}');
  }
  final mime = (file.type ?? '').trim();     // ⬅️ MIME directo del navegador
  return PickResult(bytes, file.name, mime);
}

Future<PickResult?> pickAnyFileWeb() async {
  final input = html.FileUploadInputElement()..accept = 'image/*,video/*';
  final c = Completer<void>();
  input.onChange.listen((_) => c.complete());
  input.click();
  await c.future;
  if (input.files == null || input.files!.isEmpty) return null;
  return _readFile(input.files!.first);
}

Future<PickResult?> capturePhotoWeb() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..setAttribute('capture', 'environment');
  final c = Completer<void>();
  input.onChange.listen((_) => c.complete());
  input.click();
  await c.future;
  if (input.files == null || input.files!.isEmpty) return null;
  return _readFile(input.files!.first);
}

Future<PickResult?> captureVideoWeb() async {
  final input = html.FileUploadInputElement()
    ..accept = 'video/*'
    ..setAttribute('capture', 'environment');
  final c = Completer<void>();
  input.onChange.listen((_) => c.complete());
  input.click();
  await c.future;
  if (input.files == null || input.files!.isEmpty) return null;
  return _readFile(input.files!.first);
}
